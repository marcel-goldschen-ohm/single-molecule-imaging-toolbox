classdef Utilities < handle
    %UTILITIES Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static)
        function obj = loadobj(obj, s)
            if isstruct(s)
                props = fieldnames(obj);
                for k = 1:numel(props)
                    prop = char(props{k});
                    metaprop = findprop(obj, prop);
                    if isfield(s, prop) && ~metaprop.Dependent
                        try
                            if isstruct(obj.(prop))
                                obj.(prop) = Utilities.makeStructArraysCompatible(s.(prop), obj.(prop));
                            else
                                obj.(prop) = s.(prop);
                            end
                        catch
                            disp(['!!! ERROR: ' class(obj) ': Failed to load property ' prop]);
                        end
                    end
                end
                unloadedProps = setdiff(fieldnames(s), fieldnames(obj));
                if ~isempty(unloadedProps)
                    disp(['!!! WARNING: ' class(obj) ': Did NOT load invalid properties: ' strjoin(unloadedProps, ',')]);
                end
            else
                obj = s;
            end
        end
        
        function pos = getPixelPositionInAncestor(hObj, hAncestor)
            pos = getpixelposition(hObj);
            h = hObj.Parent;
            while ~isempty(h) && ~isequal(h, hAncestor)
                hpos = getpixelposition(h);
                pos(1:2) = pos(1:2) + hpos(1:2);
                h = h.Parent;
            end
        end
        
        function [A, B] = makeStructArraysCompatible(A, B)
            % Adds default empty fields to struct arrays A and B as needed so that they
            % have identical fieldnames.
            fa = fieldnames(A);
            fb = fieldnames(B);
            fab = union(fa, fb);
            for k = 1:numel(fab)
                if ~isfield(A, fab{k})
                    bk = B(1).(fab{k});
                    if isobject(bk)
                        [A.(fab{k})] = deal(eval(class(bk)));
                    else
                        [A.(fab{k})] = deal([]);
                    end
                elseif ~isfield(B, fab{k})
                    ak = A(1).(fab{k});
                    if isobject(ak)
                        [B.(fab{k})] = deal(eval(class(ak)));
                    else
                        [B.(fab{k})] = deal([]);
                    end
                end
            end
        end
        
        % https://github.com/kakearney/plotboxpos-pkg
        % copied here for convenience, otherwise install via Add-On Explorer
        function pos = plotboxpos(h)
            %PLOTBOXPOS Returns the position of the plotted axis region
            %
            % pos = plotboxpos(h)
            %
            % This function returns the position of the plotted region of an axis,
            % which may differ from the actual axis position, depending on the axis
            % limits, data aspect ratio, and plot box aspect ratio.  The position is
            % returned in the same units as the those used to define the axis itself.
            % This function can only be used for a 2D plot.  
            %
            % Input variables:
            %
            %   h:      axis handle of a 2D axis (if ommitted, current axis is used).
            %
            % Output variables:
            %
            %   pos:    four-element position vector, in same units as h

            % Copyright 2010 Kelly Kearney

            % Check input

            if nargin < 1
                h = gca;
            end

            if ~ishandle(h) || ~strcmp(get(h,'type'), 'axes')
                error('Input must be an axis handle');
            end

            % Get position of axis in pixels

            currunit = get(h, 'units');
            set(h, 'units', 'pixels');
            axisPos = get(h, 'Position');
            set(h, 'Units', currunit);

            % Calculate box position based axis limits and aspect ratios

            darismanual  = strcmpi(get(h, 'DataAspectRatioMode'),    'manual');
            pbarismanual = strcmpi(get(h, 'PlotBoxAspectRatioMode'), 'manual');

            if ~darismanual && ~pbarismanual

                pos = axisPos;

            else

                xlim = get(h, 'XLim');
                ylim = get(h, 'YLim');

                % Deal with axis limits auto-set via Inf/-Inf use

                if any(isinf([xlim ylim]))
                    hc = get(h, 'Children');
                    hc(~arrayfun( @(h) isprop(h, 'XData' ) & isprop(h, 'YData' ), hc)) = [];
                    xdata = get(hc, 'XData');
                    if iscell(xdata)
                        xdata = cellfun(@(x) x(:), xdata, 'uni', 0);
                        xdata = cat(1, xdata{:});
                    end
                    ydata = get(hc, 'YData');
                    if iscell(ydata)
                        ydata = cellfun(@(x) x(:), ydata, 'uni', 0);
                        ydata = cat(1, ydata{:});
                    end
                    isplotted = ~isinf(xdata) & ~isnan(xdata) & ...
                                ~isinf(ydata) & ~isnan(ydata);
                    xdata = xdata(isplotted);
                    ydata = ydata(isplotted);
                    if isempty(xdata)
                        xdata = [0 1];
                    end
                    if isempty(ydata)
                        ydata = [0 1];
                    end
                    if isinf(xlim(1))
                        xlim(1) = min(xdata);
                    end
                    if isinf(xlim(2))
                        xlim(2) = max(xdata);
                    end
                    if isinf(ylim(1))
                        ylim(1) = min(ydata);
                    end
                    if isinf(ylim(2))
                        ylim(2) = max(ydata);
                    end
                end

                dx = diff(xlim);
                dy = diff(ylim);
                dar = get(h, 'DataAspectRatio');
                pbar = get(h, 'PlotBoxAspectRatio');

                limDarRatio = (dx/dar(1))/(dy/dar(2));
                pbarRatio = pbar(1)/pbar(2);
                axisRatio = axisPos(3)/axisPos(4);

                if darismanual
                    if limDarRatio > axisRatio
                        pos(1) = axisPos(1);
                        pos(3) = axisPos(3);
                        pos(4) = axisPos(3)/limDarRatio;
                        pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
                    else
                        pos(2) = axisPos(2);
                        pos(4) = axisPos(4);
                        pos(3) = axisPos(4) * limDarRatio;
                        pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
                    end
                elseif pbarismanual
                    if pbarRatio > axisRatio
                        pos(1) = axisPos(1);
                        pos(3) = axisPos(3);
                        pos(4) = axisPos(3)/pbarRatio;
                        pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
                    else
                        pos(2) = axisPos(2);
                        pos(4) = axisPos(4);
                        pos(3) = axisPos(4) * pbarRatio;
                        pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
                    end
                end
            end

            % Convert plot box position to the units used by the axis

            hparent = get(h, 'parent');
            hfig = ancestor(hparent, 'figure'); % in case in panel or similar
            currax = get(hfig, 'currentaxes');

            temp = axes('Units', 'Pixels', 'Position', pos, 'Visible', 'off', 'parent', hparent);
            set(temp, 'Units', currunit);
            pos = get(temp, 'position');
            delete(temp);

            set(hfig, 'currentaxes', currax);
        end
        
        function tf = isAxesZoomed(ax)
            unzoomed = getappdata(ax, 'matlab_graphics_resetplotview');
            if isempty(unzoomed) ...
                    || (isequal(ax.XLim, unzoomed.XLim) && isequal(ax.YLim, unzoomed.YLim))
               tf = false;
            else
               tf = true;
            end
        end
        
        function registration = registrationEstimatorAppWrapper(movingImage, fixedImage)
            % This is a wrapper for programatically launching MATLAB's
            % registrationEstimator app and returning the last image registration
            % struct exported from the app to the base workspace upon closing the app
            % window.
            %
            % Hint: Inputting imadjust(movingImage), imadjust(fixedImage) may be helpful.
            
            registration = [];

            % launch MATLAB's registrationEstimator app
            registrationEstimator(movingImage, fixedImage);

            % get list of base workspace variables
            vars = evalin('base', 'who()');

            % inform user that they need to export the alignment
            h = msgbox({ ...
                '1. Align images', ...
                '2. Export to workspace (name whatever)', ...
                '3. Close registration estimator window', ...
                '4. Last exported alignment will be returned' ...
                '5. !!! Close this message box ONLY after all of the above'
                });
            
            % block until registrationEstimator uifigure is closed
            waitfor(h);
            
            % get list of base workspace variables
            newvars = evalin('base', 'who()');
            
            % find new base workspace variables (i.e. those exported from
            % registrationEstimator app)
            newvars = newvars(~ismember(newvars, vars));
            if ~isempty(newvars)
                % return registrationEstimator app export
                registration = evalin('base', newvars{end});
            end
        end
        
        function answer = questdlgInFig(fig, question, title)
            dlg = uipanel(fig, ...
                'Title', title, ...
                'Position', [.25 .25 .5 .5], ...
                'BackgroundColor', [.8 .9 1], ...
                'FontSize', 12);
            quest = uicontrol(dlg, 'style', 'text', ...
                'String', question, ...
                'BackgroundColor', [.8 .9 1], ...
                'FontSize', 12, ...
                'Units', 'normalized', 'Position', [0 .25 1 .75]);
            yesBtn = uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Yes', ...
                'BackgroundColor', [.6 .9 .6], ...
                'FontSize', 12, ...
                'Units', 'normalized', 'Position', [.2 .05 .25 .2], ...
                'Callback', @(varargin) yes_());
            noBtn = uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'No', ...
                'BackgroundColor', [1 .6 .6], ...
                'FontSize', 12, ...
                'Units', 'normalized', 'Position', [.55 .05 .25 .2], ...
                'Callback', @(varargin) no_());
            uiwait();
            delete(dlg);
            function yes_()
                uiresume();
                answer = "Yes";
            end
            function no_()
                uiresume();
                answer = "No";
            end
        end
    end
end

