function tf = isAxesZoomed(ax)

% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    unzoomed = getappdata(ax, 'matlab_graphics_resetplotview');
    if isempty(unzoomed) ...
            || (isequal(ax.XLim, unzoomed.XLim) && isequal(ax.YLim, unzoomed.YLim))
       tf = false;
    else
       tf = true;
    end
    
end