classdef ChannelSpotProjectionViewer < handle
    %CHANNELSPOTPROJECTIONVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Channel handle.
        channel = Channel();
        
        % Handle to the selected spot.
        % If it's NOT in the channel's list of spots, it will reflect the
        % user's last click position within the image axes.
        selectedSpot = Spot.empty;
        
        % handle to image stack used for spot projections
        selectedImageStack = ImageStack.empty;
        
        % Bounding box in which to arrange items within Parent.
        % [] => fill Parent container.
        Position = [];
        
        projAxes = gobjects(0);
        projLine = gobjects(0);
        idealLine = gobjects(0);
        
        histAxes = gobjects(0);
        histLine = gobjects(0);
        histPatch = gobjects(0);
        
        infoText = gobjects(0);
        menuButton = gobjects(0);
        autoscaleButton = gobjects(0);
        
        % Handle to viewer for channel's parent experiment.
        experimentViewer = ExperimentViewer.empty;
        
        selectedSpotChangedListener = [];
        resizeListener = [];
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
        
        % Visibility of all graphics objects besides toolbarPanel
        Visible
    end
    
    methods
        function obj = ChannelSpotProjectionViewer(parent)
            %CHANNELSPOTPROJECTIONVIEWER Construct an instance of this class
            %   Detailed explanation goes here
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
            obj.projAxes = axes(parent, 'Units', 'pixels', ...
                'TickLength', [0.004 0.002]);
            ax = obj.projAxes;
            ax.Toolbar.Visible = 'off';
            box(ax, 'on');
            hold(ax, 'on');
            obj.projLine = plot(ax, nan, nan, '-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.idealLine = plot(ax, nan, nan, '-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            obj.histAxes = axes(parent, 'Units', 'pixels', ...
                'XTick', [], 'YTick', []);
            ax = obj.histAxes;
            ax.Toolbar.Visible = 'off';
            box(ax, 'on');
            hold(ax, 'on');
            obj.histLine = plot(ax, nan, nan, '-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            obj.infoText = uicontrol(parent, 'Style', 'pushbutton', ...
                'Callback', @(varargin) obj.infoTextPressed());
            
            obj.menuButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.menuButtonPressed());
            
            obj.autoscaleButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.autoscale());
            
            obj.resize();
            obj.updateResizeListener();
        end
        
        function delete(obj)
            h = [ ...
                obj.projAxes ...
                obj.histAxes ...
                obj.infoText ...
                obj.menuButton ...
                obj.autoscaleButton ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function set.channel(obj, channel)
            obj.channel = channel;
            obj.projAxes.YLabel.String = channel.label;
            obj.selectedSpot = Spot.empty;
            obj.selectedImageStack = ImageStack.empty;
            for imstack = channel.images
                if imstack.numFrames() > 1
                    obj.selectedImageStack = imstack;
                    break
                end
            end
        end
        
        function set.selectedSpot(obj, spot)
            obj.selectedSpot = spot;
            if ~isprop(obj, 'projLine') || ~isgraphics(obj.projLine)
                return
            end
            if ~isempty(spot)
                % update projection
                if ~isempty(obj.selectedImageStack) && ~isempty(obj.selectedImageStack.data)
                    spot.updateProjection(obj.selectedImageStack);
                end
                % show projection
                y = spot.tproj.adjustedData;
                if ~isempty(y)
                    x = spot.tproj.timeSamples;
                    obj.projLine.XData = x;
                    obj.projLine.YData = y;
                    obj.autoscale();
                    return
                end
            end
            obj.projLine.XData = nan;
            obj.projLine.YData = nan;
        end
        
        function onSelectedSpotChanged(obj, src, varargin)
            if isa(src, 'ChannelImageViewer')
                obj.selectedSpot = src.selectedSpot;
            end
        end
        
        function set.selectedImageStack(obj, imstack)
            obj.selectedImageStack = imstack;
            if isempty(imstack)
                obj.infoText.String = '';
            else
                obj.infoText.String = imstack.getLabelWithSizeInfo();
            end
            ... % TODO: update projection
        end
        
        function setSelectedImageStack(obj, imstack)
            % for use in callbacks
            obj.selectedImageStack = imstack;
        end
        
        function parent = get.Parent(obj)
            parent = obj.projAxes.Parent;
        end
        
        function set.Parent(obj, parent)
            % reparent and reposition all graphics objects
            obj.projAxes.Parent = parent;
            obj.histAxes.Parent = parent;
            obj.infoText.Parent = parent;
            obj.menuButton.Parent = parent;
            obj.autoscaleButton.Parent = parent;
            obj.resize();
            obj.updateResizeListener();
        end
        
        function visible = get.Visible(obj)
            visible = obj.projAxes.Visible;
        end
        
        function set.Visible(obj, visible)
            % reparent and reposition all graphics objects
            obj.projAxes.Visible = visible;
            if ~isempty(obj.projAxes.Children)
                [obj.projAxes.Children.Visible] = deal(visible);
            end
            obj.histAxes.Visible = visible;
            if ~isempty(obj.histAxes.Children)
                [obj.histAxes.Children.Visible] = deal(visible);
            end
            obj.infoText.Visible = visible;
            obj.menuButton.Visible = visible;
            obj.autoscaleButton.Visible = visible;
        end
        
        function set.Position(obj, position)
            % set position within Parent container and call resize() to
            % reposition items within updated Position
            obj.Position = position;
            obj.resize();
        end
        
        function resize(obj, varargin)
            %RESIZE Reposition objects within Parent.
            
            margin = 2;
            parentUnits = obj.Parent.Units;
            obj.Parent.Units = 'pixels';
            try
                % use Position as bounding box within Parent container
                x = obj.Position(1);
                y = obj.Position(2);
                w = obj.Position(3);
                h = obj.Position(4);
                if w <= 1 && x <= 1
                    % normalized in horizontal
                    pw = obj.Parent.Position(3);
                    x = max(margin, min(x * pw, pw - 2 * margin));
                    w = max(margin, min(w * pw, pw - x - margin));
                end
                if h <= 1 && y <= 1
                    % normalized in vertical
                    ph = obj.Parent.Position(4);
                    y = max(margin, min(y * ph, ph - 2 * margin));
                    h = max(margin, min(h * ph, ph - y - margin));
                end
            catch
                % fill Parent container
                x = margin;
                y = margin;
                w = obj.Parent.Position(3) - 2 * margin;
                h = obj.Parent.Position(4) - 2 * margin;
            end
            obj.Parent.Units = parentUnits;
            
            tw = 50;
%             if ~isempty(obj.projAxes.YLabel.String)
%                 tw = tw + 20;
%             end
            obj.projAxes.Position = [x+tw y+20 w-tw-100-margin max(1,h-35-margin)];
            obj.histAxes.Position = [x+w-100 y+20 100 max(1,h-35-margin)];
            pos = ChannelSpotProjectionViewer.plotboxpos(obj.projAxes);
            
            obj.infoText.Position = [pos(1)+45+margin pos(2)+pos(4)+margin pos(3)-60-2*margin 15];
            obj.menuButton.Position = [pos(1)+30 pos(2)+pos(4)+margin 15 15];
            obj.autoscaleButton.Position = [x+w-100-margin-15 y+h-15 15 15];
        end
        
        function updateResizeListener(obj)
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = addlistener(ancestor(obj.Parent, 'Figure'), 'SizeChanged', @obj.resize);
        end
        
        function removeResizeListener(obj)
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = [];
        end
        
        function menuButtonPressed(obj)
            menu = obj.getActionsMenu();
            menu.Position(1:2) = obj.menuButton.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getActionsMenu(obj)
            fig = ancestor(obj.Parent, 'Figure');
            menu = uicontextmenu(fig);
            menu.Position(1:2) = get(fig, 'CurrentPoint');
            
            projectionImageStackMenu = uimenu(menu, 'Label', 'Projection Image Stack');
            for i = 1:numel(obj.channel.images)
                imstack = obj.channel.images(i);
                if imstack.numFrames() > 1
                    uimenu(projectionImageStackMenu, 'Label', imstack.getLabelWithSizeInfo(), ...
                        'Checked', ~isempty(obj.selectedImageStack) && obj.selectedImageStack == imstack, ...
                        'Callback', @(varargin) obj.setSelectedImageStack(imstack));
                end
            end
        end
        
        function infoTextPressed(obj)
            menu = obj.getSelectedImageStackMenu();
            menu.Position(1:2) = obj.infoText.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getSelectedImageStackMenu(obj)
            fig = ancestor(obj.Parent, 'Figure');
            menu = uicontextmenu(fig);
            
            for i = 1:numel(obj.channel.images)
                imstack = obj.channel.images(i);
                if imstack.numFrames() > 1
                    uimenu(menu, 'Label', imstack.getLabelWithSizeInfo(), ...
                        'Checked', ~isempty(obj.selectedImageStack) && obj.selectedImageStack == imstack, ...
                        'Callback', @(varargin) obj.setSelectedImageStack(imstack));
                end
            end
        end
        
        function autoscale(obj)
            x = obj.projLine.XData;
            y = obj.projLine.YData;
            if all(isnan(y))
                return
            end
            ymin = min(y);
            ymax = max(y);
            dy = 0.1 * (ymax - ymin);
            axis(obj.projAxes, [x(1) x(end) ymin-dy ymax+dy]);
        end
    end
    
    methods (Static)
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
    end
end

