classdef ChannelSpotViewer < handle
    %CHANNELSPOTVIEWER
    
    properties
        % channel data
        hChannel = Channel.empty;
        
        % selected spot in image
        hSelectedSpot = Spot.empty;
        
        % UI elements
        hPanel
        hTopBtn
        hTopBtnsLeft = gobjects(0);
        hTopBtnsRight = gobjects(0);
        hMenuBtn
        hAutoscaleBtn
        hShowIdealBtn
        hFilterBtn
        
        hTraceAxes
        hTraceLine
        hTraceIdealLine
        
        hHistAxes
        hHistBar
        hHistIdealLines
        hHistUpperRightText
        hHistNumBinsText
        hHistNumBinsEdit
        hHistSqrtCountsBtn
    end
    
    properties (Access = private)
        % listeners
        channelLabelChangedListener = event.listener.empty;
        selectedSpotChangedListener = event.listener.empty;
        projectionImageStackChangedListener = event.listener.empty;
        projectionImageStackLabelChangedListener = event.listener.empty;

        % related UIs
        hSiblingViewers = ChannelSpotViewer.empty(1,0); % !!! YOU NEED TO UPDATE THIS MANUALLY, e.g. obj.updateSiblingViewers()
    end
    
    properties (Dependent)
        Parent % hPanel.Parent
        Position % hPanel.Position
        Visible % hPanel.Visible
    end
    
    methods
        function obj = ChannelSpotViewer(parent)
            %CHANNELSPOTVIEWER Constructor.
            
            % main panel will hold all other UI elements
            obj.hPanel = uipanel( ...
                'BorderType', 'none', ...
                'AutoResizeChildren', 'off', ... % will be handeld by resize()
                'UserData', obj ... % ref this object
                );
            if exist('parent', 'var') && ~isempty(parent) && isvalid(parent) && isgraphics(parent)
                obj.hPanel.Parent = parent;
            end
            
            % trace axes -------------
            obj.hTraceAxes = axes(obj.hPanel, 'Units', 'pixels', ...
                'TickLength', [0.004 0.002]);
            ax = obj.hTraceAxes;
            ax.Toolbar.Visible = 'off';
            ax.Interactions = []; %[regionZoomInteraction('Dimensions', 'xy')];
            box(ax, 'on');
            hold(ax, 'on');
            cmap = lines();
            obj.hTraceLine = line(ax, nan, nan, ...
                'LineStyle', '-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hTraceIdealLine = line(ax, nan, nan, ...
                'LineStyle', '-', 'Color', cmap(2,:), ...
                'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            % hist axes -------------
            obj.hHistAxes = axes(obj.hPanel, 'Units', 'pixels', ...
                'XTick', [], 'YTick', []);
            ax = obj.hHistAxes;
            ax.Toolbar.Visible = 'off';
            ax.Interactions = []; %[regionZoomInteraction('Dimensions', 'xy')];
            box(ax, 'on');
            hold(ax, 'on');
            obj.hHistBar = barh(ax, nan, nan, ...
                'BarWidth', 1, ...
                'LineStyle', 'none', ...
                'FaceAlpha', 0.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hHistIdealLines = line(ax, nan, nan, ...
                'LineStyle', '-', 'Color', cmap(2,:), ...
                'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hHistUpperRightText = text(ax, 0.99, 0.99, '', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hHistNumBinsText = uicontrol(obj.hPanel, 'style', 'text', ...
                'String', 'bins', ...
                'HorizontalAlignment', 'right');
            obj.hHistNumBinsEdit = uicontrol(obj.hPanel, 'style', 'edit', ...
                'String', '80', ...
                'Tooltip', '# Bins', ...
                'Callback', @(varargin) obj.updateTrace());
            obj.hHistSqrtCountsBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('221a')), ...
                'Tooltip', 'sqrt(counts)', ...
                'Callback', @(varargin) obj.updateTrace());
                
            linkaxes([obj.hTraceAxes obj.hHistAxes], 'y');
            
            % other -------------
            obj.hTopBtn = uicontrol(obj.hPanel, 'Style', 'pushbutton', ...
                'Callback', @(varargin) obj.topBtnDown());
            obj.hMenuBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), ...
                'Tooltip', 'Projection Menu', ...
                'Callback', @(varargin) obj.menuBtnDown());
            obj.hAutoscaleBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Autoscale', ...
                'Callback', @(varargin) obj.autoscale());
            obj.hShowIdealBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('220f')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Idealization', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateTrace());
            obj.hFilterBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('2a0d')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Apply Filter', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateTrace());
            obj.hTopBtnsLeft = [obj.hMenuBtn];
            obj.hTopBtnsRight = [obj.hFilterBtn obj.hShowIdealBtn obj.hAutoscaleBtn];
            
            % make sure we have a valid channel
            obj.hChannel = Channel();

            % layout
            obj.hPanel.SizeChangedFcn = @(varargin) obj.resize();
            %obj.resize(); % called when setting image stack
        end
        function delete(obj)
            %DELETE Delete all graphics objects and listeners.
            obj.deleteListeners();
            delete(obj.hPanel); % will delete all other child graphics objects
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
            if isvalid(obj.projectionImageStackChangedListener)
                delete(obj.projectionImageStackChangedListener);
                obj.projectionImageStackChangedListener = event.listener.empty;
            end
            if isvalid(obj.projectionImageStackLabelChangedListener)
                delete(obj.projectionImageStackLabelChangedListener);
                obj.projectionImageStackLabelChangedListener = event.listener.empty;
            end
        end
        function updateListeners(obj)
            obj.deleteListeners();
            obj.channelLabelChangedListener = ...
                addlistener(obj.hChannel, 'LabelChanged', ...
                @(varargin) obj.onChannelLabelChanged());
            obj.selectedSpotChangedListener = ...
                addlistener(obj.hChannel, 'SelectedSpotChanged', ...
                @(varargin) obj.updateTrace());
            obj.projectionImageStackChangedListener = ...
                addlistener(obj.hChannel, 'ProjectionImageStackChanged', ...
                @(varargin) obj.onProjectionImageStackChanged());
            if ~isempty(obj.hChannel.hProjectionImageStack)
                obj.projectionImageStackLabelChangedListener = ...
                    addlistener(obj.hChannel.hProjectionImageStack, 'LabelChanged', ...
                    @(varargin) obj.updateTopText());
            end
        end
        
        function set.hChannel(obj, h)
            % update everything for new channel
            obj.hChannel = h;
            
            obj.hTraceAxes.YLabel.String = obj.hChannel.label;
%             obj.filterBtn.Value = obj.channel.spotTsApplyFilter;
%             obj.filterBtn.Callback = @(varargin) obj.channel.toggleSpotTsApplyFilter();
            
            % default projeciton image stack
            if isempty(obj.hChannel.hProjectionImageStack)
                obj.hChannel.selectFirstValidProjectionImageStack();
            end
%             % default spot
%             if isempty(obj.hChannel.hSelectedSpot) && ~isempty(obj.hChannel.hSpots)
%                 obj.hChannel.hSelectedSpot = obj.hChannel.hSpots(1);
%             end
            
            % update stuff
            obj.updateTopText();
            obj.updateTrace();
            obj.autoscale();
            obj.updateListeners();
        end
        
        function h = get.Parent(obj)
            h = obj.hPanel.Parent;
        end
        function set.Parent(obj, h)
            obj.hPanel.Parent = h;
        end
        function bbox = get.Position(obj)
            bbox = obj.hPanel.Position;
        end
        function set.Position(obj, bbox)
            obj.hPanel.Position = bbox;
            obj.resize();
        end
        function vis = get.Visible(obj)
            vis = obj.hPanel.Visible;
        end
        function set.Visible(obj, vis)
            obj.hPanel.Visible = vis;
        end
        
        function resize(obj)
            %RESIZE Reposition all graphics objects within hPanel.
            
            % reposition image axes within panel
            bbox = getpixelposition(obj.hPanel);
            margin = 2;
            lineh = 20;
            x = margin + 50;
            y = margin + lineh + margin;
            w = bbox(3) - margin - x;
            h = bbox(4) - margin - lineh - margin - y;
            if ~isempty(obj.hTraceAxes.YLabel.String)
                x = x + lineh;
                w = w - lineh;
            end
            obj.hTraceAxes.Position = [x y w-100-margin h];
            obj.hHistAxes.Position = [x+w-100 y 100 h];
            % get actual displayed image axes position.
            pos = Utilities.plotboxpos(obj.hTraceAxes);
            x = pos(1); y = pos(2); w = pos(3); h = pos(4);
            
            % top bar text & buttons
            by = y + h + margin;
            lx = x + 30;
            for i = 1:numel(obj.hTopBtnsLeft)
                obj.hTopBtnsLeft(i).Position = [lx by lineh lineh];
                lx = lx + lineh;
            end
            rx = x + w;
            for i = numel(obj.hTopBtnsRight):-1:1
                rx = rx - lineh;
                obj.hTopBtnsRight(i).Position = [rx by lineh lineh];
            end
            obj.hTopBtn.Position = [lx by rx-lx lineh];
            x = x + w + margin;
            obj.hHistNumBinsText.Position = [x by 30 lineh];
            obj.hHistNumBinsEdit.Position = [x+30 by 70-lineh lineh];
            obj.hHistSqrtCountsBtn.Position = [x+100-lineh by lineh lineh];
        end
        function refresh(obj)
            %REFRESH Update everything by resetting the channel handle.
            obj.hChannel = obj.hChannel;
        end
        
        function onChannelLabelChanged(obj)
            obj.hTraceAxes.YLabel.String = obj.hChannel.label;
            obj.resize();
        end
        function onProjectionImageStackChanged(obj)
            obj.updateTopText();
            obj.updateTrace();
            obj.updateListeners();
        end
        
        function updateTopText(obj)
            hImageStack = obj.hChannel.hProjectionImageStack;
            if isempty(hImageStack)
                str = 'tsData';
            else
                str = hImageStack.getLabelWithInfo();
            end
            obj.hTopBtn.String = str;
        end
        function topBtnDown(obj)
            %TOPTEXTBTNDOWN Handle button press in top text area.
            if isempty(obj.hChannel.hImages)
                return
            end
            
            menu = uicontextmenu;
            for hImage = obj.hChannel.hImages
                if hImage.numFrames > 1
                    uimenu(menu, 'Label', hImage.getLabelWithInfo(), ...
                        'Checked', isequal(hImage, obj.hChannel.hProjectionImageStack), ...
                        'Callback', @(varargin) obj.hChannel.setProjectionImageStack(hImage));
                end
            end
            
            hFig = ancestor(obj.hPanel, 'Figure');
            menu.Parent = hFig;
            pos = Utilities.getPixelPositionInAncestor(obj.hTopBtn, hFig);
            menu.Position(1:2) = pos(1:2);
            menu.Visible = 1;
        end
        
        function menuBtnDown(obj)
            %MENUBUTTONPRESSED Handle menu button press.
            menu = obj.getMenu();
            hFig = ancestor(obj.hPanel, 'Figure');
            menu.Parent = hFig;
            pos = Utilities.getPixelPositionInAncestor(obj.hMenuBtn, hFig);
            menu.Position(1:2) = pos(1:2);
            menu.Visible = 1;
        end
        function menu = getMenu(obj)
            %GETACTIONSMENU Return menu with channel image actions.
            menu = uicontextmenu;
            
            % channel -------------------
            uimenu(menu, 'Label', 'Rename Channel', ...
                'Callback', @(varargin) obj.hChannel.editLabel());
            
            % images -------------------
            numImages = numel(obj.hChannel.hImages);
            if numImages > 1
                submenu = uimenu(menu, 'Label', 'Select Projection Image Stack', ...
                    'Separator', 'on');
                for hImage = obj.hChannel.hImages
                    if hImage.numFrames > 1
                        uimenu(submenu, 'Label', hImage.getLabelWithInfo(), ...
                            'Checked', isequal(hImage, obj.hChannel.hProjectionImageStack), ...
                            'Callback', @(varargin) obj.hChannel.setProjectionImageStack(hImage));
                    end
                end
            end
            
            uimenu(menu, 'Label', 'Set Sample Interval', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.setSampleInterval());
            
            uimenu(menu, 'Label', 'Z-Project All Spots', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.zprojectAllSpots());
            
            uimenu(menu, 'Label', 'Clear Traces', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearAllTraces());
            uimenu(menu, 'Label', 'Clear Idealizations', ...
                'Callback', @(varargin) obj.clearAllIdealizations());
            
            label = 'Sum Frame Blocks';
            if obj.hChannel.spotTsSumEveryN > 1
                label = [label ' (' num2str(obj.hChannel.spotTsSumEveryN) ')'];
            end
            uimenu(menu, 'Label', label, ...
                'Separator', 'on', ...
                'Checked', obj.hChannel.spotTsSumEveryN > 1, ...
                'Callback', @(varargin) obj.hChannel.editSpotTsSumEveryN());
            
%             label = 'Set Filter';
%             isDigitalFilter = ~isempty(obj.channel.spotTsFilter) && class(obj.channel.spotTsFilter) == "digitalFilter";
%             fname = '';
%             if isDigitalFilter
%                 fname = [char(obj.channel.spotTsFilter.FrequencyResponse) char(obj.channel.spotTsFilter.ImpulseResponse)];
%             end
%             if ~isempty(fname)
%                 label = [label ' (' fname ')'];
%             end
%             submenu = uimenu(menu, 'Label', label, 'Separator', 'on');
%             label = 'Digital Filter';
%             if isDigitalFilter && ~isempty(fname)
%                 label = [label ' (' fname ')'];
%             end
%             uimenu(submenu, 'Label', label, ...
%                 'Checked', isDigitalFilter, ...
%                 'Callback', @(varargin) obj.channel.editSpotTsDigitalFilter());
        end
        
        function updateTrace(obj)
            if obj.Visible == "off"
                return
            end
%             obj.updateTopText();
            hSpot = obj.hChannel.hSelectedSpot;
            if ~isempty(hSpot)
                hSpot.updateZProjectionFromImageStack();
                [x, y, isMasked] = hSpot.getTimeSeriesData();
                if ~isempty(y)
                    obj.hTraceLine.XData = x;
                    obj.hTraceLine.YData = y;
                    obj.autoscaleY();
                    obj.hTraceLine.Visible = 'on';
                    obj.hHistAxes.XLabel.String = [char(hex2dec('2190')) ' ' char(hSpot.tsData.timeUnits)];
                    % ideal
                    if obj.hShowIdealBtn.Value
                        try
                            ideal = hSpot.tsModel.idealData;
                        catch
                            ideal = [];
                        end
                        if isequal(size(y), size(ideal))
                            obj.hTraceIdealLine.XData = x;
                            obj.hTraceIdealLine.YData = ideal;
                            obj.hTraceIdealLine.Visible = 'on';
                        else
                            obj.hTraceIdealLine.Visible = 'off';
                            obj.hTraceIdealLine.XData = nan;
                            obj.hTraceIdealLine.YData = nan;
                        end
                    else
                        ideal = [];
                        obj.hTraceIdealLine.Visible = 'off';
                        obj.hTraceIdealLine.XData = nan;
                        obj.hTraceIdealLine.YData = nan;
                    end
                    % histogram
                    nbins = str2num(obj.hHistNumBinsEdit.String);
                    limits = obj.hTraceAxes.YLim;
                    edges = linspace(limits(1), limits(2), nbins + 1);
                    centers = (edges(1:end-1) + edges(2:end)) / 2;
                    counts = histcounts(y, edges);
                    area = trapz(centers, counts);
                    sqrtCounts = obj.hHistSqrtCountsBtn.Value;
                    if sqrtCounts
                        counts = sqrt(counts);
                    end
                    obj.hHistBar.XData = centers;
                    obj.hHistBar.YData = counts;
                    obj.hHistBar.Visible = 'on';
                    % norm dist about idealized states
                    if isempty(ideal)
                        obj.hHistIdealLines.Visible = 'off';
                        obj.hHistIdealLines.XData = nan;
                        obj.hHistIdealLines.YData = nan;
                        obj.hHistUpperRightText.Visible = 'off';
                    else
                        if numel(centers) < 100
                            bins = reshape(linspace(edges(1), edges(end), 101), [] ,1);
                        else
                            bins = reshape(centers, [], 1);
                        end
                        ustates = unique(ideal);
                        nustates = numel(ustates);
                        fits = zeros(numel(bins), nustates);
                        npts = numel(ideal);
                        for k = 1:nustates
                            idx = ideal == ustates(k);
                            [mu, sigma] = normfit(y(idx));
                            weight = double(sum(idx)) / npts * area;
                            fits(:,k) = weight .* normpdf(bins, mu, sigma);
                        end
                        if sqrtCounts
                            fits = sqrt(fits);
                        end
                        bins = repmat(bins, 1, nustates);
                        bins = [bins; nan(1,nustates)];
                        fits = [fits; nan(1,nustates)];
                        obj.hHistIdealLines.XData = reshape(fits, [], 1);
                        obj.hHistIdealLines.YData = reshape(bins, [], 1);
                        obj.hHistIdealLines.Visible = 'on';
                        obj.hHistUpperRightText.String = num2str(nustates);
                        obj.hHistUpperRightText.Visible = 'on';
                    end
                    return
                end
            end
            obj.hTraceLine.Visible = 'off';
            obj.hTraceLine.XData = nan;
            obj.hTraceLine.YData = nan;
            obj.hTraceIdealLine.Visible = 'off';
            obj.hTraceIdealLine.XData = nan;
            obj.hTraceIdealLine.YData = nan;
            obj.hHistBar.Visible = 'off';
            obj.hHistBar.XData = nan;
            obj.hHistBar.YData = nan;
            obj.hHistIdealLines.Visible = 'off';
            obj.hHistIdealLines.XData = nan;
            obj.hHistIdealLines.YData = nan;
        end
        
        function autoscale(obj)
            x = obj.hTraceLine.XData;
            y = obj.hTraceLine.YData;
            if isempty(y) || all(isnan(y))
                return
            end
            xmin = x(1);
            xmax = x(end);
            ymin = min(y);
            ymax = max(y);
            dy = 0.1 * (ymax - ymin);
%             % scale to max time across all viewers in containing figure
%             hFigure = ancestor(obj.Parent, 'Figure');
%             if ~isempty(hFigure.UserData) && class(hFigure.UserData) == "ExperimentViewer"
%                 vis = hFigure.UserData.getVisibleChannelIndices();
%                 for viewer = hFigure.UserData.hChannelSpotViewers(vis)
%                     x = viewer.hTraceLine.XData;
%                     if ~isempty(x)
%                         xmin = min(xmin, x(1));
%                         xmax = max(xmax, x(end));
%                     end
%                 end
%             end
            try
                axis(obj.hTraceAxes, [xmin xmax ymin-dy ymax+dy]);
            catch
            end
        end
        function autoscaleY(obj)
            if isequal(obj.hTraceAxes.XLim, [0 1])
                obj.autoscale();
                return
            end
            y = obj.hTraceLine.YData;
            if isempty(y) || all(isnan(y))
                return
            end
            ymin = min(y);
            ymax = max(y);
            dy = 0.1 * (ymax - ymin);
            try
                obj.hTraceAxes.YLim = [ymin-dy ymax+dy];
            catch
            end
        end
        
        function hSiblingViewers = getSiblingViewers(obj)
            % GETOTHERVIEWERS Get other viewers in UI.
            %   Get all other ChannelImageViewer objects that are siblings
            %   of this object in the UI tree.
            hSiblingViewers = ChannelSpotViewer.empty(1,0);
            if ~isempty(obj.hPanel.Parent)
                siblingPanels = setdiff(findobj(obj.hPanel.Parent.Children, 'flat', 'Type', 'uipanel'), obj.hPanel);
                for k = 1:numel(siblingPanels)
                    panel = siblingPanels(k);
                    if ~isempty(panel.UserData) && isobject(panel.UserData) && class(panel.UserData) == "ChannelSpotViewer"
                        hSiblingViewers(end+1) = panel.UserData;
                    end
                end
            end
        end
        function updateSiblingViewers(obj)
            obj.hSiblingViewers = obj.getSiblingViewers();
        end
        function setSiblingViewers(obj, h)
            obj.hSiblingViewers = h;
        end
        function clearAllRelatedViewers(obj)
            obj.hSiblingViewers = ChannelImageViewer.empty(1,0);
        end
        
        function setSampleInterval(obj, dt)
            if ~exist('dt', 'var')
                answer = inputdlg({'Sample Interval (sec):'}, 'Sample Interval', 1, {''});
                if isempty(answer)
                    return
                end
                dt = str2num(answer{1});
            end
            if ~isempty(obj.hChannel.hProjectionImageStack)
                obj.hChannel.hProjectionImageStack.frameIntervalSec = dt;
            end
            hSpots = union(obj.hChannel.hSpots, obj.hChannel.hSelectedSpot);
            for k = 1:numel(hSpots)
                hSpots(k).tsData.rawTime = dt;
                if isempty(dt)
                    hSpots(k).tsData.timeUnits = 'frames';
                else
                    hSpots(k).tsData.timeUnits = 'seconds';
                end
            end
            if ~isempty(obj.hChannel.hSelectedSpot)
                notify(obj.hChannel, 'SelectedSpotChanged');
            end
        end
        function zprojectAllSpots(obj)
            for k = 1:numel(obj.hChannel.hSpots)
                obj.hChannel.hSpots(k).updateZProjectionFromImageStack();
            end
        end
        function clearAllTraces(obj)
            for k = 1:numel(obj.hChannel.hSpots)
                obj.hChannel.hSpots(k).tsData.time = [];
                obj.hChannel.hSpots(k).tsData.data = [];
                obj.hChannel.hSpots(k).tsModel.idealData = [];
            end
        end
        function clearAllIdealizations(obj)
            for k = 1:numel(obj.hChannel.hSpots)
                obj.hChannel.hSpots(k).tsModel.idealData = [];
            end
        end
    end
end

