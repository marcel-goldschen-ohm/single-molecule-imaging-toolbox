classdef Spot < handle
    %SPOT Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % spot image location [x,y]
        % scalar x,y --> fixed location for all image frames
        % vector x,y --> per frame locations (i.e. for drift correction)
        xy = [];
        
        % e.g. from regionprops() --> Area, Eccentricity, etc.
        props = struct.empty;
        
        % tags can be used to group spots
        % can be a comma-separated list of tags
        tag = "";
        
        % used for projections, e.g. the spot PSF
        mask = logical([ ...
            0 1 1 1 0; ...
            1 1 1 1 1; ...
            1 1 1 1 1; ...
            1 1 1 1 1; ...
            0 1 1 1 0  ...
            ]);
        
        % spot image intensity projection across time frames
        tproj = SpotProjection();
    end
    
    methods
        function obj = Spot()
            %SPOT Construct an instance of this class
        end
        
        function [pixelsXY, pixelIndices] = getPixelsInSpot(obj, radius, imageSize)
            %GETPIXELSINSPOT Return all pixels within radius of xy.
            xc = obj.xy(1);
            yc = obj.xy(2);
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
        
        function updateProjection(obj, imstack)
            if isempty(obj.xy) || isempty(imstack.data)
                return
            end
            row0 = round(obj.xy(2));
            col0 = round(obj.xy(1));
            maskNRows = size(obj.mask,1);
            maskNCols = size(obj.mask,2);
            maskRow0 = ceil(maskNRows / 2);
            maskCol0 = ceil(maskNCols / 2);
            rows = row0-maskRow0+1:row0+maskNRows-maskRow0;
            cols = col0-maskCol0+1:col0+maskNCols-maskCol0;
            mask = obj.mask
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
            mask
            if isempty(mask)
                obj.tproj.Time = [];
                obj.tproj.Data = [];
                return
            end
            size(imstack.data)
            nframes = imstack.numFrames();
            obj.tproj.Time = reshape(1:nframes, [], 1);
            obj.tproj.Data = reshape( ...
                sum(sum( ...
                    double(imstack.data(rows,cols,1,:)) .* repmat(mask, [1 1 1 nframes]) ...
                    , 1), 2) ./ numel(mask) ...
                , [], 1);
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Spot(), s);
        end
    end
end

