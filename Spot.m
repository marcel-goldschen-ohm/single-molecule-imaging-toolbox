classdef (ConstructOnLoad) Spot < handle
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
        
        % spot image intensity projection across time frames
        projection = SpotProjection.empty;
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
            elseif isstring(tags) || ischar(tags)
                obj.tags = Spot.str2arr(tags, ',');
            else
                obj.tags = tags;
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
        
        function set.projection(obj, proj)
            obj.projection = proj;
            notify(obj, 'ProjectionChanged');
        end
        
        function updateProjection(obj, imstack)
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
                obj.projection.time = [];
                obj.projection.data = [];
                return
            end
            nframes = imstack.numFrames;
            obj.projection.sampleInterval = imstack.frameIntervalSec;
            if isempty(imstack.frameIntervalSec)
                obj.projection.time = []; %reshape(1:nframes, [], 1);
                obj.projection.timeUnits = 'frames';
            else
                obj.projection.time = []; %reshape(0:nframes-1, [], 1) .* imstack.frameIntervalSec;
                obj.projection.timeUnits = 'seconds';
            end
            obj.projection.data = reshape( ...
                sum(sum( ...
                    double(imstack.data(rows,cols,:)) .* repmat(mask, [1 1 nframes]) ...
                    , 1), 2) ./ masktot ...
                , [], 1);
            obj.projection.dataUnits = 'au';
            notify(obj, 'ProjectionChanged');
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
    end
end

