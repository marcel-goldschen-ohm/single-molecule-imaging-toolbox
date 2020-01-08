classdef ChannelSpotTimeSeriesViewer < handle
    %CHANNELSPOTTIMESERIESVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Channel handle.
        channel = Channel;
        
        % Bounding box in which to arrange items within Parent.
        % [] => fill Parent container.
        Position = [];
        
        dataAxes = gobjects(0);
        dataLine = gobjects(0);
        idealLine = gobjects(0);
        
        histAxes = gobjects(0);
        histBar = gobjects(0);
        histIdealLines = gobjects(0);
        
        infoText = gobjects(0);
        menuButton = gobjects(0);
        autoscaleButton = gobjects(0);
        showIdealizationBtn = gobjects(0);
        filterBtn = gobjects(0);
        
        numBinsText = gobjects(0);
        numBinsEdit = gobjects(0);
        sqrtCountsBtn = gobjects(0);
    end
    
    properties (Access = private)
        resizeListener = event.listener.empty;
        channelLabelChangedListener = event.listener.empty;
        selectedSpotChangedListener = event.listener.empty;
        selectedProjectionImageStackChangedListener = event.listener.empty;
        selectedProjectionImageStackLabelChangedListener = event.listener.empty;
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
        
        % Visibility of all graphics objects besides toolbarPanel
        Visible
    end
    
    methods
        function obj = ChannelSpotTimeSeriesViewer(parent)
            %CHANNELSPOTTIMESERIESVIEWER Construct an instance of this class
            %   Detailed explanation goes here
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
            obj.dataAxes = axes(parent, 'Units', 'pixels', ...
                'TickLength', [0.004 0.002]);
            ax = obj.dataAxes;
            ax.Toolbar.Visible = 'off';
            box(ax, 'on');
            hold(ax, 'on');
            obj.dataLine = plot(ax, nan, nan, '.-', ...
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
            obj.histIdealLines = plot(ax, nan, nan, '-', ...
                'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            linkaxes([obj.dataAxes obj.histAxes], 'y');
            
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
                'Callback', @(varargin) obj.updateTimeSeries());
            obj.filterBtn = uicontrol(parent, 'style', 'togglebutton', ...
                'String', char(hex2dec('2a0d')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Apply Filter', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateTimeSeries());
            
            obj.numBinsText = uicontrol(parent, 'style', 'text', ...
                'String', 'bins', ...
                'HorizontalAlignment', 'right');
            obj.numBinsEdit = uicontrol(parent, 'style', 'edit', ...
                'String', '80', ...
                'Tooltip', '# Bins', ...
                'Callback', @(varargin) obj.updateTimeSeries());
            obj.sqrtCountsBtn = uicontrol(parent, 'style', 'togglebutton', ...
                'String', char(hex2dec('221a')), ...
                'Tooltip', 'sqrt(counts)', ...
                'Callback', @(varargin) obj.updateTimeSeries());
            
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
                obj.dataAxes ...
                obj.histAxes ...
                obj.infoText ...
                obj.menuButton ...
                obj.autoscaleButton ...
                obj.showIdealizationBtn ...
                obj.filterBtn ...
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
            if isvalid(obj.selectedProjectionImageStackLabelChangedListener)
                delete(obj.selectedProjectionImageStackLabelChangedListener);
                obj.selectedProjectionImageStackLabelChangedListener = event.listener.empty;
            end
        end
        
        function updateListeners(obj)
            obj.deleteListeners();
            if isempty(obj.channel)
                return
            end
            obj.channelLabelChangedListener = ...
                addlistener(obj.channel, 'LabelChanged', ...
                @(varargin) obj.onChannelLabelChanged());
            obj.selectedSpotChangedListener = ...
                addlistener(obj.channel, 'SelectedSpotChanged', ...
                @(varargin) obj.updateTimeSeries());
            obj.selectedProjectionImageStackChangedListener = ...
                addlistener(obj.channel, 'SelectedProjectionImageStackChanged', ...
                @(varargin) obj.onSelectedProjectionImageStackChanged());
            if ~isempty(obj.channel.selectedProjectionImageStack)
                obj.selectedProjectionImageStackLabelChangedListener = ...
                    addlistener(obj.channel.selectedProjectionImageStack, 'LabelChanged', ...
                    @(varargin) obj.updateInfoText());
            end
        end
        
        function set.channel(obj, channel)
            % set handle to channel and update displayed plot
            obj.channel = channel;
            obj.dataAxes.YLabel.String = channel.label;
            obj.filterBtn.Value = obj.channel.spotTsApplyFilter;
            obj.filterBtn.Callback = @(varargin) obj.channel.toggleSpotTsApplyFilter();
            
            % default projeciton image stack
            if isempty(channel.selectedProjectionImageStack)
                channel.selectFirstValidProjectionImageStack();
            end
            obj.updateInfoText();
            
            % draw selected time series
            obj.updateTimeSeries();
            
            % update listeners
            obj.updateListeners();
        end
        
        function parent = get.Parent(obj)
            parent = obj.dataAxes.Parent;
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
            obj.dataAxes.Visible = visible;
            if ~isempty(obj.dataAxes.Children)
                [obj.dataAxes.Children.Visible] = deal(visible);
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
            obj.dataAxes.Position = [x+tw y+20 w-tw-100-margin max(1,h-35-margin)];
            obj.histAxes.Position = [x+w-100 y+20 100 max(1,h-35-margin)];
            pos = ChannelSpotTimeSeriesViewer.plotboxpos(obj.dataAxes);
            
            obj.infoText.Position = [pos(1)+45+margin pos(2)+pos(4)+margin pos(3)-2*margin-90 15];
            obj.menuButton.Position = [pos(1)+30 pos(2)+pos(4)+margin 15 15];
            obj.filterBtn.Position = [x+w-100-margin-45 y+h-15 15 15];
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
        
        function onChannelLabelChanged(obj)
            obj.dataAxes.YLabel.String = obj.channel.label;
            obj.resize();
        end
        
        function onSelectedProjectionImageStackChanged(obj)
            obj.updateInfoText();
            obj.updateTimeSeries();
            obj.updateListeners();
        end
        
        function updateInfoText(obj)
            imstack = obj.channel.selectedProjectionImageStack;
            if isempty(imstack)
                str = 'tsData';
            else
                str = imstack.getLabelWithInfo();
            end
%             spot = obj.channel.selectedSpot;
%             spot.tsData.rawTime
%             if ~isempty(spot) && numel(spot.tsData.rawTime) == 1 && spot.tsData.timeUnits == "seconds"
%                 k = strfind(str, '@');
%                 if ~isempty(k)
%                     str = str(1:k-1);
%                 end
%                 str = sprintf('%s@%.1fHz', str, 1.0 / spot.tsData.rawTime);
%             end
            obj.infoText.String = str;
        end
        
        function updateTimeSeries(obj)
            obj.updateInfoText();
            spot = obj.channel.selectedSpot;
            if ~isempty(spot)
                spot.updateZProjectionFromImageStack();
                [x, y, isMasked] = spot.getTimeSeriesData();
                if ~isempty(y)
                    obj.dataLine.XData = x;
                    obj.dataLine.YData = y;
                    obj.autoscaleY();
                    obj.histAxes.XLabel.String = [char(hex2dec('2190')) ' ' char(spot.tsData.timeUnits)];
                    % ideal
                    if obj.showIdealizationBtn.Value
                        try
                            ideal = spot.tsModel.idealData;
                        catch
                            ideal = [];
                        end
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
                    nbins = str2num(obj.numBinsEdit.String);
                    limits = obj.dataAxes.YLim;
                    edges = linspace(limits(1), limits(2), nbins + 1);
                    centers = (edges(1:end-1) + edges(2:end)) / 2;
                    counts = histcounts(y, edges);
                    area = trapz(centers, counts);
                    sqrtCounts = obj.sqrtCountsBtn.Value;
                    if sqrtCounts
                        counts = sqrt(counts);
                    end
                    obj.histBar.XData = centers;
                    obj.histBar.YData = counts;
                    if any(isnan(obj.idealLine.YData)) || isempty(obj.idealLine.YData)
                        [obj.histIdealLines.XData] = deal(nan);
                        [obj.histIdealLines.YData] = deal(nan);
                    else
                        if numel(centers) < 100
                            bins = reshape(linspace(edges(1), edges(end), 101), [] ,1);
                        else
                            bins = reshape(centers, [], 1);
                        end
                        ustates = unique(obj.idealLine.YData);
                        nustates = numel(ustates);
                        fits = zeros(numel(bins), nustates);
                        npts = numel(obj.idealLine.YData);
                        for k = 1:nustates
                            idx = find(obj.idealLine.YData == ustates(k));
                            [mu, sigma] = normfit(obj.dataLine.YData(idx));
                            weight = double(numel(idx)) / npts * area;
                            fits(:,k) = weight .* normpdf(bins, mu, sigma);
                        end
                        if sqrtCounts
                            fits = sqrt(fits);
                        end
                        bins = repmat(bins, 1, nustates);
                        if isgraphics(obj.histIdealLines)
                            delete(obj.histIdealLines);
                        end
                        obj.histIdealLines = plot(obj.histAxes, fits, bins, '-', ...
                            'LineWidth', 1.5, ...
                            'HitTest', 'off', 'PickableParts', 'none');
                    end
                    return
                end
            end
            obj.dataLine.XData = nan;
            obj.dataLine.YData = nan;
            obj.idealLine.XData = nan;
            obj.idealLine.YData = nan;
            obj.histBar.XData = nan;
            obj.histBar.YData = nan;
            [obj.histIdealLines.XData] = deal(nan);
            [obj.histIdealLines.YData] = deal(nan);
        end
        
        function menuButtonPressed(obj)
            menu = obj.getMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.menuButton.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getMenu(obj)
            menu = uicontextmenu;
            
            if isempty(obj.channel)
                return
            end
            
            uimenu(menu, 'Label', 'Rename Channel', ...
                'Callback', @(varargin) obj.channel.editLabel());
            
            submenu = uimenu(menu, 'Label', 'Select Projection Image Stack', ...
                'Separator', 'on');
            for image = obj.channel.images
                if image.numFrames > 1
                    uimenu(submenu, 'Label', image.getLabelWithInfo(), ...
                        'Checked', isequal(image, obj.channel.selectedProjectionImageStack), ...
                        'Callback', @(varargin) obj.channel.setSelectedProjectionImageStack(image));
                end
            end
            
            if ~isempty(obj.channel.selectedProjectionImageStack)
                if ~isempty(obj.channel.selectedProjectionImageStack.fileInfo)
                    uimenu(menu, 'Label', 'Reload Selected Image Stack From File', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.channel.selectedProjectionImageStack.reload());
                end

                uimenu(menu, 'Label', 'Rename Selected Image Stack', ...
                    'Separator', isempty(obj.channel.selectedProjectionImageStack.fileInfo), ...
                    'Callback', @(varargin) obj.channel.selectedProjectionImageStack.editLabel());
            end
                
            uimenu(menu, 'Label', 'Set Sample Interval', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.channel.setSpotTsSampleInterval());
            
%             uimenu(menu, 'Label', 'Clear Projections', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.channel.askToClearAllSpotProjections());
%             
%             uimenu(menu, 'Label', 'Project All', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.channel.updateSpotProjections());
            
            label = 'Sum Frame Blocks';
            if obj.channel.spotTsSumEveryN > 1
                label = [label ' (' num2str(obj.channel.spotTsSumEveryN) ')'];
            end
            uimenu(menu, 'Label', label, ...
                'Separator', 'on', ...
                'Checked', obj.channel.spotTsSumEveryN > 1, ...
                'Callback', @(varargin) obj.channel.editSpotTsSumEveryN());
            
            label = 'Set Filter';
            isDigitalFilter = ~isempty(obj.channel.spotTsFilter) && class(obj.channel.spotTsFilter) == "digitalFilter";
            fname = '';
            if isDigitalFilter
                fname = [char(obj.channel.spotTsFilter.FrequencyResponse) char(obj.channel.spotTsFilter.ImpulseResponse)];
            end
            if ~isempty(fname)
                label = [label ' (' fname ')'];
            end
            submenu = uimenu(menu, 'Label', label, 'Separator', 'on');
            label = 'Digital Filter';
            if isDigitalFilter && ~isempty(fname)
                label = [label ' (' fname ')'];
            end
            uimenu(submenu, 'Label', label, ...
                'Checked', isDigitalFilter, ...
                'Callback', @(varargin) obj.channel.editSpotTsDigitalFilter());
            
%             idealizationMethodMenu = uimenu(menu, 'Label', 'Idealization Method', ...
%                 'Separator', 'on');
%             uimenu(idealizationMethodMenu, 'Label', 'None', ...
%                 'Checked', obj.channel.spotProjectionIdealizationMethod == "", ...
%                 'Callback', @(varargin) obj.channel.setSpotProjectionIdealizationMethod(""));
%             for method = ["DISC"]
%                 uimenu(idealizationMethodMenu, 'Label', method, ...
%                     'Checked', obj.channel.spotProjectionIdealizationMethod == method, ...
%                     'Callback', @(varargin) obj.channel.setSpotProjectionIdealizationMethod(method));
%             end
%             uimenu(menu, 'Label', 'Idealization Parameters', ...
%                 'Callback', @(varargin) obj.channel.editSpotProjectionIdealizationParams());
%             uimenu(menu, 'Label', 'Auto Idealize', ...
%                 'Checked', obj.channel.spotProjectionAutoIdealize, ...
%                 'Callback', @(varargin) obj.channel.toggleSpotProjectionAutoIdealize());
%             
%             uimenu(menu, 'Label', 'Clear Idealizations', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.channel.clearAllSpotProjectionIdealizations(true));
%             uimenu(menu, 'Label', 'Idealize Visible', ...
%                 'Callback', @(varargin) obj.channel.idealizeSelectedSpotProjection());
%             uimenu(menu, 'Label', 'Idealize All', ...
%                 'Callback', @(varargin) obj.channel.idealizeAllSpotProjections([], true));
            
%             uimenu(menu, 'Label', 'Simulate Time Series', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.channel.simulateSpotProjections());
        end
        
        function infoTextPressed(obj)
            menu = uicontextmenu;
            for image = obj.channel.images
                if image.numFrames > 1
                    uimenu(menu, 'Label', image.getLabelWithInfo(), ...
                        'Checked', isequal(image, obj.channel.selectedProjectionImageStack), ...
                        'Callback', @(varargin) obj.channel.setSelectedProjectionImageStack(image));
                end
            end
            
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.infoText.Position(1:2);
            menu.Visible = 1;
        end
        
        function autoscale(obj)
            x = obj.dataLine.XData;
            y = obj.dataLine.YData;
            if isempty(y) || all(isnan(y))
                return
            end
            xmin = x(1);
            xmax = x(end);
            ymin = min(y);
            ymax = max(y);
            dy = 0.1 * (ymax - ymin);
            % scale to max time across all viewers in containing figure
            fig = ancestor(obj.Parent, 'Figure');
            if ~isempty(fig.UserData) && class(fig.UserData) == "ExperimentViewer"
                vis = fig.UserData.getVisibleChannelIndices();
                for viewer = fig.UserData.timeSeriesViewers(vis)
                    x = viewer.dataLine.XData;
                    if ~isempty(x)
                        xmin = min(xmin, x(1));
                        xmax = max(xmax, x(end));
                    end
                end
            end
            try
                axis(obj.dataAxes, [xmin xmax ymin-dy ymax+dy]);
            catch
            end
        end
        
        function autoscaleY(obj)
            if isequal(obj.dataAxes.XLim, [0 1])
                obj.autoscale();
                return
            end
            y = obj.dataLine.YData;
            if isempty(y) || all(isnan(y))
                return
            end
            ymin = min(y);
            ymax = max(y);
            dy = 0.1 * (ymax - ymin);
            try
                obj.dataAxes.YLim = [ymin-dy ymax+dy];
            catch
            end
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

