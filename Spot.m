classdef (ConstructOnLoad) Spot < handle
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
        
        % labels can be used ot group spots
        label = "";
        
        % spot image intensity z-projection
        zproj = [];
        
        % idealization of z-projection
        ideal = [];
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
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Spot(), s);
        end
    end
end

