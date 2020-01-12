classdef Spot < handle
    %SPOT Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        hChannel = Channel.empty; % parent channel
        
        % spot image location [x,y]
        % (1x2) x,y --> fixed location for all image frames
        % (Tx2) x,y --> per frame locations (i.e. for drift correction)
        xy = [];
        
        % e.g. from regionprops() --> Area, Eccentricity, etc.
        props = struct.empty;
        
        % string array of tags
        tags = string.empty;
        
        % used for z-projections, e.g. the spot PSF
        mask = logical([ ...
            0 1 1 1 0; ...
            1 1 1 1 1; ...
            1 1 1 1 1; ...
            1 1 1 1 1; ...
            0 1 1 1 0  ...
            ]);
        
        % Time series data. e.g. image stack spot z-projection.
        tsData = TimeSeries;
        
        % Model idealization of time series data.
        tsModel = struct(); % generic container for model params and arrays
        
        % Known model for comparison when evaluating different models.
        % e.g. from simulation
        tsKnownModel = struct(); % generic container for model params and arrays
    end
    
    properties (Dependent)
        x
        y
        row
        col
    end
    
    methods
        function obj = Spot()
            %SPOT Constructor.
        end
        
        function set.tags(obj, tags)
            if isempty(tags)
                obj.tags = string.empty;
            elseif ischar(tags) || (isstring(tags) && numel(tags) == 1)
                obj.tags = Spot.str2arr(tags, ',');
            elseif isstring(tags)
                obj.tags = tags;
            else
                return
            end
        end
        function str = getTagsString(obj)
            str = Spot.arr2str(obj.tags, ",");
        end
        
        function x = get.x(obj)
            if isempty(obj.xy)
                x = [];
                return
            end
            try
                x = obj.xy(:,1);
            catch
                x = [];
            end
        end
        function y = get.y(obj)
            if isempty(obj.xy)
                y = [];
                return
            end
            try
                y = obj.xy(:,2);
            catch
                y = [];
            end
        end
        function row = get.row(obj)
            if isempty(obj.xy)
                row = [];
                return
            end
            try
                row = uint16(round(obj.y));
            catch
                row = [];
            end
        end
        function col = get.col(obj)
            if isempty(obj.xy)
                col = [];
                return
            end
            try
                col = uint16(round(obj.x));
            catch
                col = [];
            end
        end
        function set.x(obj, x)
            obj.xy(:,1) = x;
        end
        function set.y(obj, y)
            obj.xy(:,2) = y;
        end
        function set.row(obj, row)
            obj.xy(:,2) = row;
        end
        function set.col(obj, col)
            obj.xy(:,1) = col;
        end
        
        function [mask3d, rows, cols] = getMaskZProjection(obj, hImageStack)
            mrows = size(obj.mask, 1);
            mcols = size(obj.mask, 2);
            rowmins = obj.row - ceil(mrows / 2) + 1;
            colmins = obj.col - ceil(mcols / 2) + 1;
            rowmaxs = rowmins + mrows - 1;
            colmaxs = colmins + mcols - 1;
            rowmin = min(rowmins);
            rowmax = max(rowmaxs);
            colmin = min(colmins);
            colmax = max(colmaxs);
            rows = rowmin:rowmax;
            cols = colmin:colmax;
            nrows = numel(rows);
            ncols = numel(cols);
            nframes = hImageStack.numFrames;
            if nrows == mrows && ncols == mcols
                mask3d = repmat(obj.mask, 1, 1, nframes);
            else
                mask3d = zeros(nrows, ncols, nframes, class(obj.mask));
                for t = 1:nframes
                    row0 = rowmins(t) - rowmin;
                    col0 = colmins(t) - colmin;
                    trows = row0:row0 + mrows - 1;
                    tcols = col0:col0 + mcols - 1;
                    mask3d(trows, tcols, t) = obj.mask;
                end
            end
            % remove out of image bits
            out = union(find(rows < 1), find(rows > hImageStack.height));
            if ~isempty(out)
                rows(out) = [];
                mask3d(out,:,:) = [];
            end
            out = union(find(cols < 1), find(cols > hImageStack.width));
            if ~isempty(out)
                cols(out) = [];
                mask3d(:,out,:) = [];
            end
        end
        
        function zproj = getZProjectionFromImageStack(obj, hImageStack)
            if isempty(obj.xy)
                return
            end
            if ~exist('hImageStack', 'var')
                try
                    hImageStack = obj.hChannel.hProjectionImageStack;
                catch
                    return
                end
            end
            if isempty(hImageStack) || isempty(hImageStack.data)
                return
            end
            [mask3d, rows, cols] = obj.getMaskZProjection(hImageStack);
            zproj = reshape( ...
                sum(sum( ...
                    double(hImageStack.data(rows,cols,:)) .* mask3d ...
                    , 1), 2) ./ sum(sum(mask3d, 1), 2) ...
                , [], 1);
        end
        function updateZProjectionFromImageStack(obj, hImageStack)
            if isempty(obj.xy)
                return
            end
            if ~exist('hImageStack', 'var')
                try
                    hImageStack = obj.hChannel.hProjectionImageStack;
                catch
                    return
                end
            end
            if isempty(hImageStack) || isempty(hImageStack.data)
                return
            end
            obj.tsData.rawTime = hImageStack.frameIntervalSec;
            obj.tsData.rawData = obj.getZProjectionFromImageStack(hImageStack);
            if isempty(obj.tsData.rawTime)
                obj.tsData.timeUnits = 'frames';
            else
                obj.tsData.timeUnits = 'seconds';
            end
            if isempty(obj.tsData.dataUnits)
                obj.tsData.dataUnits = 'au';
            end
        end
        
        function [x, y, isMasked] = getTimeSeriesData(obj)
            x = obj.tsData.time;
            y = obj.tsData.data;
            isMasked = obj.tsData.mask;
            % channel level options for resampling and filtering
            if isempty(obj.hChannel)
                return
            end
            if obj.hChannel.spotTsSumEveryN > 1
                N = obj.hChannel.spotTsSumEveryN;
                [x, y, isMasked] = TimeSeries.sumEveryN(N, x, y, isMasked);
            end
            if obj.hChannel.spotTsApplyFilter && ~isempty(obj.hChannel.spotTsFilter)
                y = filter(obj.hChannel.spotTsFilter, y);
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Spot(), s);
        end
        
        function [pixelsXY, pixelIndices] = getPixelsInSpot(xy, radius, imageSize)
            %GETPIXELSINSPOT Return all pixels within radius of xy.
            xc = xy(1);
            yc = xy(2);
            cols = max(1,floor(xc-radius)):min(ceil(xc+radius),imageSize(2));
            rows = max(1,floor(yc-radius)):min(ceil(yc+radius),imageSize(1));
            [xx,yy] = meshgrid(cols,rows);
            d = sqrt(sum(([xx(:) yy(:)] - repmat([xc yc], [numel(xx) 1])).^2, 2));
            in = (d <= radius);
            x = int32(round(xx(in)));
            y = int32(round(yy(in)));
            pixelsXY = [x y];
            pixelIndices = sub2ind(imageSize, y, x);
        end
        
        function arr = str2arr(str, delim)
            arr = string.empty;
            if isempty(str)
                return
            end
            if exist('delim', 'var') && ~isempty(delim)
            	fields = strsplit(str, delim);
            else
            	fields = strsplit(str);
            end
            for field = fields
                elem = strtrim(field);
                if ~isempty(elem)
                    arr = [arr string(elem)];
                end
            end
        end
        
        function str = arr2str(arr, delim)
            if isempty(arr)
                str = "";
            else
                str = strjoin(arr, delim);
            end
        end
        
        function spots = getTaggedSpots(spots, tagsMask)
            if ~exist('tagsMask', 'var') || isempty(tagsMask)
                return
            end
            clip = [];
            for k = 1:numel(spots)
                if isempty(intersect(tagsMask, spots(k).tags))
                    clip = [clip k];
                end
            end
            spots(clip) = [];
        end
    end
end

