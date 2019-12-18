classdef ChannelSpotProjectionViewer < handle
    %CHANNELSPOTPROJECTIONVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Channel handle.
        channel = Channel;
        
        % Bounding box in which to arrange items within Parent.
        % [] => fill Parent container.
        Position = [];
        
        projAxes = gobjects(0);
        projLine = gobjects(0);
        idealLine = gobjects(0);
        
        histAxes = gobjects(0);
        histBar = gobjects(0);
        
        infoText = gobjects(0);
        menuButton = gobjects(0);
        autoscaleButton = gobjects(0);
        showIdealizationBtn = gobjects(0);
        
        numBinsText = gobjects(0);
        numBinsEdit = gobjects(0);
        sqrtCountsBtn = gobjects(0);
    end
    
    properties (Access = private)
        resizeListener = event.listener.empty;
        channelLabelChangedListener = event.listener.empty;
        selectedSpotChangedListener = event.listener.empty;
        selectedProjectionImageStackChangedListener = event.listener.empty;
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
            obj.projLine = plot(ax, nan, nan, '.-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.idealLine = plot(ax, nan, nan, '-', ...
                'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            obj.histAxes = axes(parent, 'Units', 'pixels', ...
                'XTick', [], 'YTick', []);
            ax = obj.histAxes;
            ax.Toolbar.Visible = 'off';
            box(ax, 'on');
            hold(ax, 'on');
            obj.histBar = barh(ax, nan, nan, ...
                'BarWidth', 1, ...
                'LineStyle', 'none', ...
                'FaceAlpha', 0.5);
            
            linkaxes([obj.projAxes obj.histAxes], 'y');
            
            obj.infoText = uicontrol(parent, 'Style', 'pushbutton', ...
                'Callback', @(varargin) obj.infoTextPressed());
            
            obj.menuButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Projection Menu', ...
                'Callback', @(varargin) obj.menuButtonPressed());
            
            obj.autoscaleButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Autoscale', ...
                'Callback', @(varargin) obj.autoscale());
            obj.showIdealizationBtn = uicontrol(parent, 'style', 'togglebutton', ...
                'String', char(hex2dec('2a05')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Show Idealization', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateProjection());
            
            obj.numBinsText = uicontrol(parent, 'style', 'text', ...
                'String', 'bins', ...
                'HorizontalAlignment', 'right');
            obj.numBinsEdit = uicontrol(parent, 'style', 'edit', ...
                'String', '80', ...
                'Tooltip', '# Bins', ...
                'Callback', @(varargin) obj.numBinsEdited());
            obj.sqrtCountsBtn = uicontrol(parent, 'style', 'togglebutton', ...
                'String', char(hex2dec('221a')), ...
                'Tooltip', 'sqrt(counts)', ...
                'Callback', @(varargin) obj.sqrtCountsBtnPressed());
            
            obj.resize();
            obj.updateResizeListener();
            
            if ~isempty(obj.channel)
                obj.channel = obj.channel; % sets listeners and stuff
            end
        end
        
        function delete(obj)
            %DELETE Delete all graphics object properties and listeners.
            obj.deleteListeners();
            obj.removeResizeListener();
            h = [ ...
                obj.projAxes ...
                obj.histAxes ...
                obj.infoText ...
                obj.menuButton ...
                obj.autoscaleButton ...
                obj.showIdealizationBtn ...
                obj.numBinsText ...
                obj.numBinsEdit ...
                obj.sqrtCountsBtn ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function deleteListeners(obj)
            if isvalid(obj.channelLabelChangedListener)
                delete(obj.channelLabelChangedListener);
                obj.channelLabelChangedListener = event.listener.empty;
            end
            if isvalid(obj.selectedSpotChangedListener)
                delete(obj.selectedSpotChangedListener);
                obj.selectedSpotChangedListener = event.listener.empty;
            end
            if isvalid(obj.selectedProjectionImageStackChangedListener)
                delete(obj.selectedProjectionImageStackChangedListener);
                obj.selectedProjectionImageStackChangedListener = event.listener.empty;
            end
        end
        
        function updateListeners(obj)
            obj.deleteListeners();
            if ~isempty(obj.channel)
                obj.channelLabelChangedListener = ...
                    addlistener(obj.channel, 'LabelChanged', ...
                    @(varargin) obj.onChannelLabelChanged());
                obj.selectedSpotChangedListener = ...
                    addlistener(obj.channel, 'SelectedSpotChanged', ...
                    @(varargin) obj.updateProjection());
                obj.selectedProjectionImageStackChangedListener = ...
                    addlistener(obj.channel, 'SelectedProjectionImageStackChanged', ...
                    @(varargin) obj.onSelectedProjectionImageStackChanged());
            end
        end
        
        function set.channel(obj, channel)
            % set handle to channel and update displayed plot
            obj.channel = channel;
            obj.projAxes.YLabel.String = channel.label;
            obj.numBinsEdit.String = num2str(channel.spotProjectionHistogramNumBins);
            obj.sqrtCountsBtn.Value = channel.spotProjectionHistogramSqrtCounts;
            
            % update projection
            if isempty(channel.selectedProjectionImageStack)
                channel.selectFirstValidProjectionImageStack();
            end
            obj.updateProjection();
            obj.updateInfoText();
            
            % update listeners
            obj.updateListeners();
        end
        
        function onChannelLabelChanged(obj)
            obj.projAxes.YLabel.String = obj.channel.label;
            obj.resize();
        end
        
        function updateProjection(obj)
            spot = obj.channel.selectedSpot;
            if ~isempty(spot)
                % update projection
                obj.channel.updateSpotProjection(spot);
                x = spot.projection.time;
                y = spot.projection.data;
                if ~isempty(y)
                    obj.projLine.XData = x;
                    obj.projLine.YData = y;
                    obj.autoscale();
                    % ideal
                    if obj.showIdealizationBtn.Value
                        if obj.channel.spotProjectionAutoIdealize
                            obj.channel.updateSpotProjectionIdealization(spot);
                        end
                        ideal = spot.projection.ideal;
                        if isequal(size(y), size(ideal))
                            obj.idealLine.XData = x;
                            obj.idealLine.YData = ideal;
                        else
                            obj.idealLine.XData = nan;
                            obj.idealLine.YData = nan;
                        end
                    else
                        obj.idealLine.XData = nan;
                        obj.idealLine.YData = nan;
                    end
                    % histogram
                    nbins = obj.channel.spotProjectionHistogramNumBins;
                    limits = obj.projAxes.YLim;
                    edges = linspace(limits(1), limits(2), nbins + 1);
                    counts = histcounts(y, edges);
                    if obj.channel.spotProjectionHistogramSqrtCounts
                        counts = sqrt(counts);
                    end
                    centers = (edges(1:end-1) + edges(2:end)) / 2;
                    obj.histBar.XData = centers;
                    obj.histBar.YData = counts;
                    return
                end
            end
            obj.projLine.XData = nan;
            obj.projLine.YData = nan;
            obj.idealLine.XData = nan;
            obj.idealLine.YData = nan;
            obj.histBar.XData = nan;
            obj.histBar.YData = nan;
        end
        
        function onSelectedProjectionImageStackChanged(obj)
            obj.updateInfoText();
            obj.updateProjection();
        end
        
        function updateInfoText(obj)
            imstack = obj.channel.selectedProjectionImageStack;
            if isempty(imstack)
                obj.infoText.String = '';
            else
                obj.infoText.String = imstack.getLabelWithSizeInfo();
            end
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
        
        function resize(obj)
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
            
            obj.infoText.Position = [pos(1)+45+margin pos(2)+pos(4)+margin pos(3)-75-2*margin 15];
            obj.menuButton.Position = [pos(1)+30 pos(2)+pos(4)+margin 15 15];
            obj.showIdealizationBtn.Position = [x+w-100-margin-30 y+h-15 15 15];
            obj.autoscaleButton.Position = [x+w-100-margin-15 y+h-15 15 15];
            
            obj.numBinsText.Position = [x+w-100 y+h-15 30 15];
            obj.numBinsEdit.Position = [x+w-70 y+h-15 55 15];
            obj.sqrtCountsBtn.Position = [x+w-15 y+h-15 15 15];
        end
        
        function updateResizeListener(obj)
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = ...
                addlistener(ancestor(obj.Parent, 'Figure'), ...
                'SizeChanged', @(varargin) obj.resize());
        end
        
        function removeResizeListener(obj)
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = event.listener.empty;
        end
        
        function menuButtonPressed(obj)
            menu = obj.getActionsMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.menuButton.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getActionsMenu(obj)
            menu = uicontextmenu;
            
            if isempty(obj.channel)
                return
            end
            
            submenu = obj.channel.selectProjectionImageStackMenu(menu);
            
            if ~isempty(obj.channel.selectedProjectionImageStack)
                uimenu(menu, 'Label', 'Reload Selected Projection Image Stack', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.channel.selectedProjectionImageStack.reload());

                uimenu(menu, 'Label', 'Rename Selected Projection Image Stack', ...
                    'Callback', @(varargin) obj.channel.selectedProjectionImageStack.editLabel());
                
                uimenu(menu, 'Label', 'Set Selected Projection Image Stack Frame Interval', ...
                    'Callback', @(varargin) obj.channel.selectedProjectionImageStack.editFrameInterval());
            end
            
            uimenu(menu, 'Label', ['Sum Frame Blocks (' num2str(obj.channel.spotProjectionSumEveryNFrames) ')'], ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.channel.editSumEveryNFrames());
            
            idealizationMethodMenu = uimenu(menu, 'Label', 'Idealization Method', ...
                'Separator', 'on');
            uimenu(idealizationMethodMenu, 'Label', 'None', ...
                'Checked', obj.channel.spotProjectionIdealizationMethod == "", ...
                'Callback', @(varargin) obj.channel.setSpotProjectionIdealizationMethod(""));
            for method = ["DISC"]
                uimenu(idealizationMethodMenu, 'Label', method, ...
                    'Checked', obj.channel.spotProjectionIdealizationMethod == method, ...
                    'Callback', @(varargin) obj.channel.setSpotProjectionIdealizationMethod(method));
            end
            uimenu(menu, 'Label', 'Idealization Parameters', ...
                'Callback', @(varargin) obj.channel.editSpotProjectionIdealizationParams());
            uimenu(menu, 'Label', 'Auto Idealize', ...
                'Checked', obj.channel.spotProjectionAutoIdealize, ...
                'Callback', @(varargin) obj.channel.toggleSpotProjectionAutoIdealize());
        end
        
        function infoTextPressed(obj)
            if numel(obj.channel.images) <= 1
                return
            end
            
            menu = uicontextmenu;
            submenu = obj.channel.selectProjectionImageStackMenu(menu);
            % put submenu items directly into menu
            while ~isempty(submenu.Children)
                submenu.Children(end).Parent = menu;
            end
            delete(submenu);
            
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.infoText.Position(1:2);
            menu.Visible = 1;
        end
        
        function autoscale(obj)
            x = obj.projLine.XData;
            y = obj.projLine.YData;
            if isempty(y) || all(isnan(y))
                return
            end
            ymin = min(y);
            ymax = max(y);
            dy = 0.1 * (ymax - ymin);
            try
                axis(obj.projAxes, [x(1) x(end) ymin-dy ymax+dy]);
            catch
            end
        end
        
        function numBinsEdited(obj)
            obj.channel.projectionHistogramNumBins = str2num(obj.numBinsEdit.String);
            obj.updateProjection();
        end
        
        function sqrtCountsBtnPressed(obj)
            obj.channel.projectionHistogramSqrtCounts = obj.sqrtCountsBtn.Value > 0;
            obj.updateProjection();
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

