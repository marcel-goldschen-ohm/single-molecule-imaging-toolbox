function [pixelsXY, pixelIndices] = getPixelsInSpot(centerXY, radius, imageSize)

% Return all pixels within radius of centerXY.

% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    xc = centerXY(1);
    yc = centerXY(2);
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