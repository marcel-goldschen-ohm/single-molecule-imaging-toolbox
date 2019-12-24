classdef Spot < handle
    %SPOT Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % spot image location [x,y]
        % (1x2) x,y --> fixed location for all image frames
        % (Tx2) x,y --> per frame locations (i.e. for drift correction)
        xy = [];
        
        % e.g. from regionprops() --> Area, Eccentricity, etc.
        props = struct.empty;
        
        % string array of tags
        tags = string.empty;
        
        % used for projections, e.g. the spot PSF
        projectionMask = logical([ ...
            0 1 1 1 0; ...
            1 1 1 1 1; ...
            1 1 1 1 1; ...
            1 1 1 1 1; ...
            0 1 1 1 0  ...
            ]);
        
        % Spot image intensity projection across time frames.
        time = []; % time array OR sample interval (sec)
        data = []; % spot intensity z-projection
        sumFramesBlockSize = 1; % sum blocks of frames, e.g. simulate longer exposures
        idealizedData = []; % idealization of data
        perfectData = []; % e.g. from simulations
    end
    
    events
        LocationChanged
        TagsChanged
        ProjectionChanged
    end
    
    methods
        function obj = Spot()
            %SPOT Constructor.
            obj.projection = SpotProjection;
        end
        
        function set.xy(obj, xy)
            obj.xy = xy;
            notify(obj, 'LocationChanged');
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
            notify(obj, 'TagsChanged');
        end
        
        function str = getTagsString(obj)
            if isempty(obj.tags)
                str = "";
            else
                str = strjoin(obj.tags, ",");
            end
        end
        
        function x = get.time(obj)
            ny = size(obj.data, 1);
            if ny == 0
                x = [];
                return
            end
            nx = size(obj.time, 1);
            if nx == 0
                % frames
                x = reshape([1:ny], [], 1);
            elseif nx == 1
                % sample interval
                dt = obj.time;
                x = dt .* reshape([0:ny-1], [], 1);
            else
                % time pts
                x = obj.time;
            end
            if ~isempty(x) && obj.sumFramesBlockSize > 1
                n = obj.sumFramesBlockSize;
                npts = floor(double(length(x)) / n) * n;
                x = x(1:n:npts);
            end
        end
        function set.time(obj, x)
            obj.time = reshape(x, [], 1);
        end
        
        function y = get.data(obj)
            y = obj.data;
            if isempty(y)
                return
            end
            % sum frame blocks?
            if obj.sumFramesBlockSize > 1
                n = obj.sumFramesBlockSize;
                npts = floor(double(length(y)) / n) * n;
                y0 = y;
                y = y0(1:n:npts);
                for k = 2:n
                    y = y + y0(k:n:npts);
                end
            end
        end
        function set.data(obj, y)
            obj.data = reshape(y, [], 1);
        end
        
        function set.idealizedData(obj, y)
            obj.idealizedData = reshape(y, [], 1);
        end
        
        function y = get.perfectData(obj)
            y = obj.perfectData;
            if isempty(y)
                return
            end
            ny = size(y, 1);
            ndata = size(obj.data, 1);
            if ny ~= ndata && obj.sumFramesBlockSize > 1
                n = obj.sumFramesBlockSize;
                npts = floor(double(ny) / n) * n;
                if npts == ndata
                    y0 = y;
                    y = y0(1:n:npts);
                    for k = 2:n
                        y = y + y0(k:n:npts);
                    end
                end
            end
        end
        function set.perfectData(obj, y)
            obj.perfectData = reshape(y, [], 1);
        end
        
        function updateProjectionFromImageStack(obj, imstack)
            if isempty(obj.xy) || isempty(imstack.data)
                return
            end
            row0 = round(obj.xy(2));
            col0 = round(obj.xy(1));
            mask = obj.projectionMask;
            maskNRows = size(mask,1);
            maskNCols = size(mask,2);
            maskRow0 = ceil(maskNRows / 2);
            maskCol0 = ceil(maskNCols / 2);
            rows = row0-maskRow0+1:row0+maskNRows-maskRow0;
            cols = col0-maskCol0+1:col0+maskNCols-maskCol0;
            out = union(find(rows < 1), find(rows > imstack.height()));
            if ~isempty(out)
                rows(out) = [];
                mask(out,:) = [];
            end
            out = union(find(cols < 1), find(cols > imstack.width()));
            if ~isempty(out)
                cols(out) = [];
                mask(:,out) = [];
            end
            masktot = sum(mask(:));
            if isempty(mask) || masktot == 0
                obj.projection.rawTime = [];
                obj.projection.rawData = [];
                return
            end
            nframes = imstack.numFrames;
            if isempty(imstack.frameIntervalSec)
                % frames
                obj.time = [];
            else
                % sample interval (sec)
                obj.time = imstack.frameIntervalSec;
            end
            obj.data = reshape( ...
                sum(sum( ...
                    double(imstack.data(rows,cols,:)) .* repmat(mask, [1 1 nframes]) ...
                    , 1), 2) ./ masktot ...
                , [], 1);
            notify(obj, 'ProjectionChanged');
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Spot(), s);
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
        
        function [segments, segmentStartIndices] = getNonNanSegments(dataWithNan)
            % return cell array of non-nan subarrays
            dataWithNan = reshape(dataWithNan, [], 1);
            idx = isnan(dataWithNan);
            segmentLengths = diff(find([1; diff(idx); 1]));
            segmentStartIndices = [1; cumsum(segmentLengths(1:end-1))];
            segments = mat2cell(dataWithNan, segmentLengths(:));
            % remove nan segments
            segments(2:2:end) = [];
            segmentStartIndices(2:2:end) = [];
        end
    end
end

