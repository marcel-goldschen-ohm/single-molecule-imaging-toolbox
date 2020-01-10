classdef ExperimentViewer < handle
    %EXPERIMENTVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Experiment handle.
        experiment = Experiment;
        
        % Channel viewers.
        imageViewers = ChannelImageViewer.empty;
        timeSeriesViewers = ChannelSpotTimeSeriesViewer.empty;
        
        menuBtn = gobjects(0);
        refreshUiBtn = gobjects(0);
        
        channelsListHeaderText = gobjects(0);
        addChannelBtn = gobjects(0);
        removeChannelsBtn = gobjects(0);
        channelsListBox = gobjects(0);
        
        layoutHeaderText = gobjects(0);
        layoutBtnGroup = gobjects(0);
        showImagesBtn = gobjects(0);
        showProjectionsBtn = gobjects(0);
        showImagesAndProjectionsBtn = gobjects(0);
        
        spotsHeaderText = gobjects(0);
        prevSpotBtn = gobjects(0);
        nextSpotBtn = gobjects(0);
        spotIndexEdit = gobjects(0);
        spotTagsEdit = gobjects(0);
        showSpotMarkersCBox = gobjects(0);
        zoomOnSelectedSpotCBox = gobjects(0);
        
        selectionHeaderText = gobjects(0);
        selectionBtnGroup = gobjects(0);
        selectAllChannelsBtn = gobjects(0);
        selectVisibleChannelsBtn = gobjects(0);
        selectVisibleSpotsBtn = gobjects(0);
        selectionTagsMaskCBox = gobjects(0);
        selectionTagsMaskEdit = gobjects(0);
        
        actionsHeaderText = gobjects(0);
        zprojectSpotsBtn = gobjects(0);
        applyTsModelBtn = gobjects(0);
        tsModelSelectionPopup = gobjects(0);
        tsModelParamsBtn = gobjects(0);
        
%         clearProjectionsBtn = gobjects(0);
%         projectSpotBtn = gobjects(0);
%         projectAllSpotsBtn = gobjects(0);
%         
%         idealizationHeaderText = gobjects(0);
%         clearIdealizationsBtn = gobjects(0);
%         idealizeSpotBtn = gobjects(0);
%         idealizeAllSpotsBtn = gobjects(0);
        
%         simulationHeaderText = gobjects(0);
%         simulateBtn = gobjects(0);

        msgText = gobjects(0);
    end
    
    properties (Access = private)
        resizeListener = event.listener.empty;
        selectedSpotIndexChangedListener = event.listener.empty;
        channelLabelChangedListeners = event.listener.empty;
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
        
        selectionMode
    end
    
    methods
        function obj = ExperimentViewer(parent)
            %EXPERIMENTVIEWER Constructor.
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure('units', 'normalized', 'position', [0 0 1 1]);
                parent.Units = 'pixels';
                addToolbarExplorationButtons(parent); % old style
            end
            
            obj.menuBtn = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Main Menu', ...
                'Callback', @(varargin) obj.menuBtnPressed());
            obj.refreshUiBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', char(hex2dec('27f3')), ...
                'Tooltip', 'Refresh UI', ...
                'Callback', @(varargin) obj.refreshUi());
            
            obj.channelsListHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Channels', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.addChannelBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '+', 'BackgroundColor', [.6 .9 .6], ...
                'Tooltip', 'Add Channel', ...
                'Callback', @(varargin) obj.addChannel());
            obj.removeChannelsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '-', 'BackgroundColor', [1 .6 .6], ...
                'Tooltip', 'Remove Selected Channels', ...
                'Callback', @(varargin) obj.removeChannels());
            obj.channelsListBox = uicontrol(parent, 'Style', 'listbox', ...
                'Callback', @(varargin) obj.showChannels());
            
            obj.layoutHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Layout', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.layoutBtnGroup = uibuttongroup(parent, ...
                'BorderType', 'none', 'Units', 'pixels');
            obj.showImagesBtn = uicontrol(obj.layoutBtnGroup, ...
                'Style', 'togglebutton', 'String', 'Img', 'Value', 0, ...
                'Tooltip', 'Show Images Only', ...
                'Callback', @(varargin) obj.resize());
            obj.showProjectionsBtn = uicontrol(obj.layoutBtnGroup, ...
                'Style', 'togglebutton', 'String', 'Trace', 'Value', 0, ...
                'Tooltip', 'Show Spot Time Series Traces Only', ...
                'Callback', @(varargin) obj.resize());
            obj.showImagesAndProjectionsBtn = uicontrol(obj.layoutBtnGroup, ...
                'Style', 'togglebutton', 'String', 'Img & Trace', 'Value', 1, ...
                'Tooltip', 'Show Images and Spot Time Series Traces', ...
                'Callback', @(varargin) obj.resize());
            
            obj.spotsHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Spots', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.prevSpotBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '<', 'Callback', @(varargin) obj.prevSpot(), ...
                'Tooltip', 'Previous Spot');
            obj.nextSpotBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '>', 'Callback', @(varargin) obj.nextSpot(), ...
                'Tooltip', 'Next Spot');
            obj.spotIndexEdit = uicontrol(parent, 'Style', 'edit', ...
                'Tooltip', 'Selected Spot Index', ...
                'Callback', @(varargin) obj.goToSpot());
            obj.spotTagsEdit = uicontrol(parent, 'Style', 'edit', ...
                'Tooltip', 'Selected Spot Tags (comma-separated)', ...
                'Callback', @(varargin) obj.onSpotTagsEdited());
            obj.showSpotMarkersCBox = uicontrol(parent, 'Style', 'checkbox', ...
                'String', 'show spot markers', 'Value', 1, ...
                'Tooltip', 'Show all spots on image', ...
                'Callback', @(varargin) obj.updateShowSpotMarkers());
            obj.zoomOnSelectedSpotCBox = uicontrol(parent, 'Style', 'checkbox', ...
                'String', 'zoom on selected spot', 'Value', 0, ...
                'Tooltip', 'Zoom images on selected spot', ...
                'Callback', @(varargin) obj.updateZoomOnSelectedSpot());
            
            obj.selectionHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Selection', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.selectionBtnGroup = uibuttongroup(parent, ...
                'BorderType', 'none', 'Units', 'pixels');
            obj.selectAllChannelsBtn = uicontrol(obj.selectionBtnGroup, ...
                'Style', 'radiobutton', 'String', 'all channels', 'Value', 0);
            obj.selectVisibleChannelsBtn = uicontrol(obj.selectionBtnGroup, ...
                'Style', 'radiobutton', 'String', 'visible channels', 'Value', 0);
            obj.selectVisibleSpotsBtn = uicontrol(obj.selectionBtnGroup, ...
                'Style', 'radiobutton', 'String', 'visible spots', 'Value', 1);
            obj.selectionTagsMaskCBox = uicontrol(parent, 'Style', 'checkbox', ...
                'String', 'tags', 'Value', 1, ...
                'Tooltip', 'Only select spots with any of these tags');
            obj.selectionTagsMaskEdit = uicontrol(parent, 'Style', 'edit', ...
                'Tooltip', 'Only select spots with any of these tags');
            
            obj.actionsHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Actions', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.zprojectSpotsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'Z-Project Spot Traces', 'Callback', @(varargin) obj.zprojectSpots());
            obj.applyTsModelBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'Model Spot Traces', 'Callback', @(varargin) obj.modelSpotTraces());
            obj.tsModelSelectionPopup = uicontrol(parent, 'Style', 'popupmenu', ...
                'String', {'DISC'}, ...
                'Tooltip', 'Model Name', ...
                'Callback', @(s,e) obj.setTsModel(s.String{s.Value}));
            obj.tsModelParamsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', char(hex2dec('2699')), ...
                'Tooltip', 'Model Parameters', ...
                'Callback', @(varargin) obj.editTsModelParams());

            obj.msgText = uicontrol(parent, 'Style', 'text', ...
                'String', '', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 1]);
            
%             obj.Parent = parent; % calls resize() and updateResizeListener()
            obj.resize();
            obj.updateResizeListener();
            
            if ~isempty(obj.experiment)
                obj.experiment = obj.experiment; % sets listeners and stuff
            end
            
            parent.UserData = obj;
        end
        
        function delete(obj)
            %DELETE Delete all graphics object properties and listeners.
            delete(obj.resizeListener);
            obj.deleteListeners();
            delete(obj.imageViewers);
            delete(obj.timeSeriesViewers);
            h = [ ...
                obj.menuBtn ...
                obj.refreshUiBtn ...
                obj.channelsListHeaderText ...
                obj.addChannelBtn ...
                obj.removeChannelsBtn ...
                obj.channelsListBox ...
                obj.layoutHeaderText ...
                obj.layoutBtnGroup ...
                obj.spotsHeaderText ...
                obj.prevSpotBtn ...
                obj.nextSpotBtn ...
                obj.spotIndexEdit ...
                obj.spotTagsEdit ...
                obj.showSpotMarkersCBox ...
                obj.zoomOnSelectedSpotCBox ...
                obj.selectionHeaderText ...
                obj.selectionBtnGroup ...
                obj.selectionTagsMaskCBox ...
                obj.selectionTagsMaskEdit ...
                obj.actionsHeaderText ...
                obj.zprojectSpotsBtn ...
                obj.applyTsModelBtn ...
                obj.tsModelSelectionPopup ...
                obj.tsModelParamsBtn ...
                ...%obj.projectionHeaderText ...
                ...%obj.clearProjectionsBtn ...
                ...%obj.projectSpotBtn ...
                ...%obj.projectAllSpotsBtn ...
                ...%obj.idealizationHeaderText ...
                ...%obj.clearIdealizationsBtn ...
                ...%obj.idealizeSpotBtn ...
                ...%obj.idealizeAllSpotsBtn ...
                ...%obj.simulationHeaderText ...
                ...%obj.simulateBtn ...
                obj.msgText ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function deleteListeners(obj)
            if isvalid(obj.selectedSpotIndexChangedListener)
                delete(obj.selectedSpotIndexChangedListener);
                obj.selectedSpotIndexChangedListener = event.listener.empty;
            end
            if any(isvalid(obj.channelLabelChangedListeners))
                delete(obj.channelLabelChangedListeners);
                obj.channelLabelChangedListeners = event.listener.empty;
            end
        end
        
        function updateListeners(obj)
            obj.deleteListeners();
            if isempty(obj.experiment)
                return
            end
            obj.selectedSpotIndexChangedListener = ...
                addlistener(obj.experiment, 'SelectedSpotIndexChanged', ...
                @(varargin) obj.onSelectedSpotIndexChanged());
            for c = 1:numel(obj.experiment.channels)
                obj.channelLabelChangedListeners(c) = ...
                    addlistener(obj.experiment.channels(c), 'LabelChanged', ...
                    @(varargin) obj.updateChannelsListBox());
            end
        end
        
        function set.experiment(obj, experiment)
            obj.experiment = experiment;

            % update channel viewers
            nchannels = numel(experiment.channels);
            for c = 1:min(nchannels, numel(obj.imageViewers))
                obj.imageViewers(c).channel = experiment.channels(c);
            end
            for c = 1:min(nchannels, numel(obj.timeSeriesViewers))
                obj.timeSeriesViewers(c).channel = experiment.channels(c);
            end
            for c = numel(obj.imageViewers)+1:nchannels
                obj.imageViewers(c) = ChannelImageViewer(obj.Parent);
                obj.imageViewers(c).channel = experiment.channels(c);
                obj.imageViewers(c).removeResizeListener(); % Handled by this class.
            end
            for c = numel(obj.timeSeriesViewers)+1:nchannels
                obj.timeSeriesViewers(c) = ChannelSpotTimeSeriesViewer(obj.Parent);
                obj.timeSeriesViewers(c).channel = experiment.channels(c);
                obj.timeSeriesViewers(c).removeResizeListener(); % Handled by this class.
            end
            if numel(obj.imageViewers) > nchannels
                delete(obj.imageViewers(nchannels+1:end));
                obj.imageViewers(nchannels+1:end) = [];
            end
            if numel(obj.timeSeriesViewers) > nchannels
                delete(obj.timeSeriesViewers(nchannels+1:end));
                obj.timeSeriesViewers(nchannels+1:end) = [];
            end
%             delete(obj.imageViewers);
%             delete(obj.timeSeriesViewers);
%             obj.imageViewers = ChannelImageViewer.empty;
%             obj.timeSeriesViewers = ChannelSpotTimeSeriesViewer.empty;
%             for c = 1:nchannels
%                 obj.imageViewers(c) = ChannelImageViewer(obj.Parent);
%                 obj.imageViewers(c).channel = experiment.channels(c);
%                 obj.imageViewers(c).removeResizeListener(); % Handled by this class.
%                 obj.timeSeriesViewers(c) = ChannelSpotTimeSeriesViewer(obj.Parent);
%                 obj.timeSeriesViewers(c).channel = experiment.channels(c);
%                 obj.timeSeriesViewers(c).removeResizeListener(); % Handled by this class.
%             end
            
            % link axes
            if ~isempty(obj.imageViewers)
                linkaxes(horzcat(obj.imageViewers.imageAxes), 'xy');
            end
            if ~isempty(obj.timeSeriesViewers)
                linkaxes(horzcat(obj.timeSeriesViewers.dataAxes), 'x');
            end
            
            % update controls
            obj.selectionTagsMaskEdit.String = obj.experiment.getSpotSelectionTagsMaskString();
            obj.selectionTagsMaskEdit.Callback = @(s,e) obj.experiment.setSpotSelectionTagsMask(s.String);
            obj.selectionTagsMaskCBox.Value = obj.experiment.applySpotSelectionTagsMask;
            obj.selectionTagsMaskCBox.Callback = @(s,e) obj.experiment.setApplySpotSelectionTagsMask(s.Value == 1);
            
            % update listeners
            obj.updateListeners();
            
            % initial spot
            if ~isempty(obj.experiment.selectedSpotIndex)
                obj.goToSpot(obj.experiment.selectedSpotIndex);
            else
                obj.goToSpot(1);
            end
            
            % update channels list box and refresh channels display
            obj.updateChannelsListBox();
            obj.showChannels();
        end
        
        function parent = get.Parent(obj)
            parent = obj.channelsListBox.Parent;
        end
        
        function set.Parent(obj, parent)
            % reparent and reposition all graphics objects
            obj.channelsListHeaderText.Parent = parent;
            obj.addChannelBtn.Parent = parent;
            obj.removeChannelsBtn.Parent = parent;
            obj.channelsListBox.Parent = parent;
            for viewer = obj.imageViewers
                viewer.Parent = parent;
            end
            for viewer = obj.timeSeriesViewers
                viewer.Parent = parent;
            end
            obj.resize();
            obj.updateResizeListener();
        end
        
        function resize(obj)
            %RESIZE Reposition objects within Parent.
            
            margin = 2;
            parentUnits = obj.Parent.Units;
            obj.Parent.Units = 'pixels';
            % fill Parent container
            x0 = margin;
            y0 = margin;
            w = obj.Parent.Position(3) - 2 * margin;
            h = obj.Parent.Position(4) - 2 * margin;
            obj.Parent.Units = parentUnits;
            
            % controls
            wc = 150;
            lh = 20;
            lh2 = 20;
            y = y0 + h - lh;
            obj.menuBtn.Position = [x0 y lh lh];
            obj.refreshUiBtn.Position = [x0+lh y lh lh];
            % channels
            y = y - margin - lh;
            obj.channelsListHeaderText.Position = [x0 y wc-2*lh lh];
            obj.addChannelBtn.Position = [x0+wc-2*lh y lh lh];
            obj.removeChannelsBtn.Position = [x0+wc-lh y lh lh];
            y = y - 150;
            obj.channelsListBox.Position = [x0 y wc 150];
            % layout
            y = y - margin - lh;
            obj.layoutHeaderText.Position = [x0 y wc lh];
            y = y - lh;
            obj.layoutBtnGroup.Position = [x0 y wc lh];
            obj.showImagesBtn.Position = [0 0 .3*wc lh];
            obj.showProjectionsBtn.Position = [.3*wc 0 .3*wc lh];
            obj.showImagesAndProjectionsBtn.Position = [.6*wc 0 .4*wc lh];
            % spots
            y = y - margin - lh;
            obj.spotsHeaderText.Position = [x0 y wc lh];
            y = y - 2 * lh;
            obj.prevSpotBtn.Position = [x0 y 2*lh 2*lh];
            obj.nextSpotBtn.Position = [x0+wc-2*lh y 2*lh 2*lh];
            obj.spotIndexEdit.Position = [x0+2*lh y+lh wc-4*lh lh];
            obj.spotTagsEdit.Position = [x0+2*lh y wc-4*lh lh];
            if obj.showImagesBtn.Value || obj.showImagesAndProjectionsBtn.Value
                y = y - lh;
                obj.showSpotMarkersCBox.Position = [x0 y wc lh];
                y = y - lh;
                obj.zoomOnSelectedSpotCBox.Position = [x0 y wc lh];
                obj.showSpotMarkersCBox.Visible = 'on';
                obj.zoomOnSelectedSpotCBox.Visible = 'on';
            else
                obj.showSpotMarkersCBox.Visible = 'off';
                obj.zoomOnSelectedSpotCBox.Visible = 'off';
            end
            % selection
            y = y - margin - lh;
            obj.selectionHeaderText.Position = [x0 y wc lh];
            y = y - 3*lh2;
            obj.selectionBtnGroup.Position = [x0 y wc 3*lh2];
            obj.selectAllChannelsBtn.Position = [0 2*lh2 wc lh2];
            obj.selectVisibleChannelsBtn.Position = [0 lh2 wc lh2];
            obj.selectVisibleSpotsBtn.Position = [0 0 wc lh2];
            y = y - lh;
            obj.selectionTagsMaskCBox.Position = [x0 y 50 lh];
            obj.selectionTagsMaskEdit.Position = [x0+50 y wc-50 lh];
            % actions
            y = y - margin - lh;
            obj.actionsHeaderText.Position = [x0 y wc lh];
            y = y - lh2;
            obj.zprojectSpotsBtn.Position = [x0 y wc lh2];
            y = y - lh2;
            obj.applyTsModelBtn.Position = [x0 y wc lh2];
            y = y - 20;
            obj.tsModelSelectionPopup.Position = [x0 y wc-20 20];
            obj.tsModelParamsBtn.Position = [x0+wc-20 y 20 20];
            % message
            obj.msgText.Position = [x0 margin wc lh];
            
            % visible channels
            nchannels = numel(obj.experiment.channels);
            vischannels = obj.getVisibleChannelIndices();
            nvischannels = numel(vischannels);
            invischannels = setdiff(1:nchannels, vischannels);
            showImages = obj.showImagesBtn.Value || obj.showImagesAndProjectionsBtn.Value;
            showProjections = obj.showProjectionsBtn.Value || obj.showImagesAndProjectionsBtn.Value;
            if ~showImages
                [obj.imageViewers.Visible] = deal(0);
                for viewer = obj.imageViewers
                    viewer.spotMarkers.Visible = 0;
                    viewer.selectedSpotMarker.Visible = 0;
                end
            end
            if ~showProjections
                [obj.timeSeriesViewers.Visible] = deal(0);
            end
            if ~isempty(invischannels)
                [obj.imageViewers(invischannels).Visible] = deal(0);
                [obj.timeSeriesViewers(invischannels).Visible] = deal(0);
                for viewer = obj.imageViewers(invischannels)
                    viewer.spotMarkers.Visible = 0;
                    viewer.selectedSpotMarker.Visible = 0;
                end
            end
            if nvischannels > 0
                x = x0 + wc + margin;
                wc = w - x;
                sep = margin;
                hc = floor((h - (nvischannels - 1) * sep) / nvischannels);
                y = y0 + h - hc;
                if showImages && showProjections
                    whratio = 1; % width / height image ratio
                    for c = vischannels
                        imstack = obj.imageViewers(c).imageStack;
                        ratio = imstack.width() / imstack.height();
                        if ~isinf(ratio) && ratio > 0 && ratio > whratio
                            whratio = ratio;
                        end
                    end
                    wim = max(1, min(whratio * (hc - 30 - 2 * margin), wc / 2)) + 15;
                end
                for c = vischannels
                    if showImages && showProjections
                        obj.imageViewers(c).Position = [x y wim hc];
                        obj.timeSeriesViewers(c).Position = [x+wim+10 y wc-wim-10 hc];
                    elseif showImages
                        obj.imageViewers(c).Position = [x y wc hc];
                    elseif showProjections
                        obj.timeSeriesViewers(c).Position = [x y wc hc];
                    end
                    if showImages
                        obj.imageViewers(c).showFrame();
                    end
                    y = y - sep - hc;
                end
                if showImages
                    [obj.imageViewers(vischannels).Visible] = deal(1);
                end
                if showProjections
                    [obj.timeSeriesViewers(vischannels).Visible] = deal(1);
                end
            end
        end
        
        function updateResizeListener(obj)
            if isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = ...
                addlistener(ancestor(obj.Parent, 'Figure'), ...
                'SizeChanged', @(varargin) obj.resize());
        end
        
        function addChannel(obj)
            obj.experiment.channels = [obj.experiment.channels Channel];
            obj.updateChannelsListBox();
            nchannels = numel(obj.experiment.channels);
            if nchannels > 1
                obj.channelsListBox.Value = unique([obj.channelsListBox.Value numel(obj.experiment.channels)]);
            end
            obj.experiment = obj.experiment; % updates everything
        end
        
        function removeChannels(obj, idx)
            if ~exist('idx', 'var')
                idx = obj.getVisibleChannelIndices();
            end
            if isempty(idx)
                return
            end
            
            try
                if Utilities.questdlgInFig(gcf, 'Remove selected channels?', 'Remove Channels') ~= "Yes"
                    return
                end
            catch
                if questdlg('Remove selected channels?', 'Remove Channels') ~= "Yes"
                    return
                end
            end
            
            selected = false(1, numel(obj.experiment.channels));
            selected(obj.getVisibleChannelIndices()) = true;
            selected(idx) = [];
            
            delete(obj.experiment.channels(idx));
            obj.experiment.channels(idx) = [];
            
            obj.channelsListBox.Value = find(selected);
            obj.experiment = obj.experiment; % updates everything
        end
        
        function updateChannelsListBox(obj)
            nchannels = numel(obj.experiment.channels);
            if nchannels
                obj.channelsListBox.String = cellstr(horzcat(obj.experiment.channels.label));
            else
                obj.channelsListBox.String = {};
            end
            obj.channelsListBox.Min = 0;
            obj.channelsListBox.Max = nchannels;
            if nchannels == 0
                obj.channelsListBox.Value = [];
            elseif nchannels == 1
                obj.channelsListBox.Value = 1;
            elseif nchannels > 1
                idx = obj.channelsListBox.Value;
                idx(idx < 1) = [];
                idx(idx > nchannels) = [];
                if isempty(idx)
                    idx = 1;
                end
                obj.channelsListBox.Value = unique(idx);
            end
        end
        
        function idx = getVisibleChannelIndices(obj)
            idx = obj.channelsListBox.Value;
            nchannels = numel(obj.experiment.channels);
            idx(idx < 1) = [];
            idx(idx > nchannels) = [];
        end
        function setVisibleChannelIndices(obj, idx)
            obj.updateChannelsListBox();
            obj.channelsListBox.Value = idx;
        end
        
        function channels = getVisibleChannels(obj)
            idx = obj.getVisibleChannelIndices();
            channels = obj.experiment.channels(idx);
        end
        function channels = getInvisibleChannels(obj)
            channels = setdiff(obj.experiment.channels, obj.getVisibleChannels());
        end
        
        function showChannels(obj, idx)
            if ~exist('idx', 'var')
                idx = obj.getVisibleChannelIndices();
            end
            nchannels = numel(obj.experiment.channels);
            idx(idx < 1) = [];
            idx(idx > nchannels) = [];
            obj.updateChannelsListBox();
            obj.channelsListBox.Value = unique(idx);
            for c = 1:nchannels
                obj.imageViewers(c).refresh();
            end
            obj.updateShowSpotMarkers();
            obj.resize();
        end
        
        function loadData(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uigetfile('*.mat', 'Open data file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            
            wb = waitbar(0, 'Loading experiment from file...');
            tmp = load(filepath);
            close(wb);
            obj.experiment = tmp.experiment;
            obj.resize();
            fig = ancestor(obj.Parent, 'Figure');
            [path, file, ext] = fileparts(filepath);
            fig.Name = strrep(file, '_', ' ');
            figure(fig);
            obj.refreshUi();
        end
        
        function saveData(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uiputfile('*.mat', 'Save data to file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            
%             % Do NOT save image stacks with frame count exceeding maxImageStackFrames.
%             if ~exist('maxImageStackFrames', 'var')
%                 answer = inputdlg({'Only save image stack data when frame count <='}, 'Save Large Image Stacks?', 1, {'inf'});
%                 if isempty(answer)
%                     return
%                 end
%                 maxImageStackFrames = str2num(answer{1});
%             end
%             for channel = obj.experiment.channels
%                 for imstack = channel.images
%                     if imstack.numFrames() > maxImageStackFrames
%                         imstack.ownData = false;
%                     else
%                         imstack.ownData = true;
%                     end
%                 end
%             end
            
            wb = waitbar(0, 'Saving experiment to file...');
            experiment = obj.experiment;
            save(filepath, 'experiment', '-v7.3');
            close(wb);
            fig = ancestor(obj.Parent, 'Figure');
            [path, file, ext] = fileparts(filepath);
            fig.Name = strrep(file, '_', ' ');
            figure(fig);
        end
        
        function reloadAllMissingImages(obj)
            for channel = obj.experiment.channels
                for imstack = channel.images
                    if isempty(imstack.data)
                        imstack.reload();
                    end
                end
            end
            obj.refreshUi();
        end
        
        function saveFigureAs(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath) || ~isfile(filepath)
                [file, path] = uiputfile({'*.fig'; '*.png'; '*.svg'});
                if isequal(file,0) || isequal(path,0)
                    return
                end
                filepath = fullfile(path, file);
            end
            fig = ancestor(obj.Parent, 'Figure');
            saveas(fig, filepath);
        end
        
        function menuBtnPressed(obj)
            %MENUBUTTONPRESSED Handle menu button press.
            menu = obj.getMainMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.menuBtn.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getMainMenu(obj)
            %GETMAINMENU Return main menu.
            menu = uicontextmenu;
            
            uimenu(menu, 'Label', 'Load Data', ...
                'Callback', @(varargin) obj.loadData());
            uimenu(menu, 'Label', 'Reload All Missing Images', ...
                'Callback', @(varargin) obj.reloadAllMissingImages());
            
            uimenu(menu, 'Label', 'Save Data', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.saveData());
            uimenu(menu, 'Label', 'Save Figure As', ...
                'Callback', @(varargin) obj.saveFigureAs());
            
            uimenu(menu, 'Label', 'Refresh UI', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.refreshUi());
            
            uimenu(menu, 'Label', 'Notes', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.experiment.editNotes());
            
            uimenu(menu, 'Label', 'Simulate Traces', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.simulateTraces());
        end
        
        function refreshUi(obj)
            obj.experiment = obj.experiment;
        end
        
        function goToSpot(obj, k)
            if ~exist('k', 'var')
                k = str2num(obj.spotIndexEdit.String);
            end
            obj.experiment.selectedSpotIndex = k;
        end
        
        function prevSpot(obj)
            if obj.selectionTagsMaskCBox.Value
                tagsMask = Spot.str2arr(obj.selectionTagsMaskEdit.String);
                obj.experiment.prevSpot(tagsMask);
            else
                obj.experiment.prevSpot();
            end
        end
        
        function nextSpot(obj)
            if obj.selectionTagsMaskCBox.Value
                tagsMask = Spot.str2arr(obj.selectionTagsMaskEdit.String);
                obj.experiment.nextSpot(tagsMask);
            else
                obj.experiment.nextSpot();
            end
        end
        
        function onSelectedSpotIndexChanged(obj)
            k = obj.experiment.selectedSpotIndex;
            % index edit
            obj.spotIndexEdit.String = num2str(k);
            % visible channels
            vischannels = obj.getVisibleChannels();
            % tags edit
            for channel = vischannels
                if numel(channel.spots) >= k
                    obj.spotTagsEdit.String = channel.spots(k).getTagsString();
                    break
                end
            end
            % header
            nspots = arrayfun(@(channel) numel(channel.spots), vischannels);
            obj.spotsHeaderText.String = ['Spots (' num2str(max(nspots)) ')'];
        end
        
        function onSpotTagsEdited(obj)
            k = obj.experiment.selectedSpotIndex;
            for channel = obj.experiment.channels
                if numel(channel.spots) >= k
                    channel.spots(k).tags = obj.spotTagsEdit.String;
                end
            end
        end
        
        function updateShowSpotMarkers(obj)
            for viewer = obj.imageViewers
                if viewer.Visible == "on"
                    viewer.spotMarkers.Visible = obj.showSpotMarkersCBox.Value == 1;
                end
            end
        end
        
        function updateZoomOnSelectedSpot(obj)
        end
        
        function spots = getAllSelectedSpots(obj)
            if obj.selectAllChannelsBtn.Value
                spots = vertcat(obj.experiment.channels.spots);
            elseif obj.selectVisibleChannelsBtn.Value
                channels = obj.getVisibleChannels();
                if ~isempty(channels)
                    spots = vertcat(channels.spots);
                end
            elseif obj.selectVisibleSpotsBtn.Value
                channels = obj.getVisibleChannels();
                if ~isempty(channels)
                    spots = vertcat(channels.selectedSpot);
                end
            end
            if obj.experiment.applySpotSelectionTagsMask
                spots = Spot.getTaggedSpots(spots, obj.experiment.spotSelectionTagsMask);
            end
        end
        
        function zprojectSpots(obj)
            tic;
            spots = obj.getAllSelectedSpots();
            obj.msgText.String = ['Z-Projecting ' num2str(numel(spots)) ' spots...'];
            drawnow;
            for k = 1:numel(spots)
                spots(k).updateZProjectionFromImageStack();
            end
            sec = toc;
            obj.msgText.String = sprintf('Done in %.1fs', sec);
            for viewer = obj.timeSeriesViewers
                viewer.updateTimeSeries();
            end
        end
        
        function modelSpotTraces(obj)
            tic;
            sec = toc;
            spots = obj.getAllSelectedSpots();
            obj.msgText.String = ['Modeling ' num2str(numel(spots)) ' traces...'];
            drawnow;
            model = obj.experiment.tsModel;
            if model.name == "DISC"
                try
                    disc_input = initDISC();
                    if isfield(model, 'alpha')
                        disc_input.input_type = 'alpha_value';
                        disc_input.input_value = model.alpha;
                    end
                    if isfield(model, 'informationCriterion')
                        disc_input.divisive = model.informationCriterion;
                        disc_input.agglomerative = model.informationCriterion;
                    end
                    if 0%model.informationCriterion == "DIC"
                        disc_input.divisive = 'DIC';
                        disc_input.agglomerative = 'BIC-GMM';
                        ystiched = [];
                        segStarts = [1];
                        for k = 1:numel(spots)
                            [x, y, isMasked] = spots(k).getTimeSeriesData();
                            if ~any(isnan(isMasked))
                                ystiched = [ystiched; y];
                                segStarts = [segStarts segStarts(end)+length(y)];
                            else
%                                 y(isMasked) = nan;
%                                 [ysegs, segi] = TimeSeries.getNonNanSegments(y);
%                                 for j = 1:numel(ysegs)
%                                     ystiched = [ystiched; ysegs{j}];
%                                     segStarts = [segStarts segStarts(end)+length(ysegs{j})];
%                                 end
                            end
                        end
                        disc_fit = runDISC(ystiched, disc_input, 1000, segStarts);
                        a = 1;
                        for k = 1:numel(spots)
                            [x, y, isMasked] = spots(k).getTimeSeriesData();
                            spots(k).tsModel = model;
                            if ~any(isnan(isMasked))
                                spots(k).tsModel.time = x;
                                spots(k).tsModel.data = y;
                                ny = length(y);
                                b = a + ny - 1;
                                spots(k).tsModel.idealData = disc_fit.ideal(a:b);
                                a = b + 1;
                            else
%                                 y(isMasked) = nan;
%                                 spots(k).tsModel.time = x;
%                                 spots(k).tsModel.data = y;
%                                 spots(k).tsModel.idealData = nan(size(y));
%                                 [ysegs, idx] = TimeSeries.getNonNanSegments(y);
%                                 for j = 1:numel(ysegs)
%                                     spots(k).tsModel.idealData(idx) = disc_fit.ideal(a:b);
%                                     segi = segi+1;
%                                     a = segStarts(segi);
%                                     b = segStarts(segi+1)-1;
%                                 end
                            end
                        end
                    else
                        for k = 1:numel(spots)
                            sec2 = toc;
                            if sec2 - sec > 30
                                obj.msgText.String = ['Modeling trace ' num2str(k) '/' num2str(numel(spots)) '...'];
                                drawnow;
                                sec = sec2;
                            end
                            [x, y, isMasked] = spots(k).getTimeSeriesData();
                            y(isMasked) = nan;
                            disc_fit = runDISC(y(~isMasked), disc_input);
                            spots(k).tsModel = model;
                            spots(k).tsModel.time = x;
                            spots(k).tsModel.data = y;
                            spots(k).tsModel.idealData = nan(size(y));
                            spots(k).tsModel.idealData(~isMasked) = disc_fit.ideal;
                        end
                    end
                catch err
                    errordlg([err.message ' Requires DISC (https://github.com/ChandaLab/DISC)'], 'DISC');
                    return
                end
            end
            sec = toc;
            obj.msgText.String = sprintf('Done in %.1fs', sec);
            for viewer = obj.timeSeriesViewers
                viewer.updateTimeSeries();
            end
        end
        
        function setTsModel(obj, name)
            obj.experiment.tsModel = name;
        end
        
        function editTsModelParams(obj)
            obj.experiment.editTsModelParams();
        end
        
        function simulateTraces(obj)
            disp('Simulating traces...');
            wb = waitbar(0, 'Simulating traces...');
            try
                [x, y, ideal] = Simulation.simulateTimeSeries();
                nchannels = size(y,3);
                nspots = size(y,2);
                obj.experiment.channels = Channel.empty(1,0);
                for c = 1:nchannels
                    channel = Channel;
                    obj.experiment.channels(c) = channel;
                    channel.spots = Spot.empty(0,1);
                    for k = 1:nspots
                        spot = Spot;
                        spot.tsData.timeUnits = 'seconds';
                        spot.tsData.time = diff(x(1:2));
                        spot.tsData.data = y(:,k,c);
                        spot.tsKnownModel.idealData = ideal(:,k,c);
                        channel.spots(k,1) = spot;
                    end
                end
                obj.setVisibleChannelIndices(1:nchannels);
                obj.refreshUi();
                obj.goToSpot(1);
                disp('... Done.');
            catch err
                disp(['... Aborted: ' err.message]);
            end
            close(wb);
        end
        
        function tsModelMetrics(obj)
            spots = obj.getAllSelectedSpots();
            nspots = numel(spots);
            Accuracy = zeros(nspots,1);
            Precision = zeros(nspots,1);
            Recall = zeros(nspots,1);
            state_threshold = 0.1;  % 10% difference in true state value
            event_threshold = 1;    % 1 frame difference in true event
            % methods:
            % - states: state detection only
            % - events: event detection only
            % - overall: state & event detection (recommended)
            % - classification
            method = 'overall';
            clip = [];
            for k = 1:nspots
                try
                    data = spots(k).tsModel.data;
                    ideal = spots(k).tsModel.idealData;
                    idealStates = zeros(size(ideal));
                    ustates = unique(ideal);
                    for j = 1:numel(ustates)
                        idx = ideal == ustates(j);
                        idealStates(idx) = j;
                    end
                    known = spots(k).tsKnownModel.idealData;
                    knownStates = zeros(size(known));
                    ustates = unique(known);
                    for j = 1:numel(ustates)
                        idx = known == ustates(j);
                        knownStates(idx) = j;
                    end
                    [Accuracy(k), Precision(k), Recall(k)] = idealizationMetrics( ...
                        data, ...
                        idealStates, ...
                        knownStates, ...
                        method, ...
                        state_threshold, ...
                        event_threshold);
                catch err
                    disp(err.message);
                    clip = [clip k];
                end
            end
            Accuracy(clip) = [];
            Precision(clip) = [];
            Recall(clip) = [];
            figure;
            nbins = 20;
            subplot(1,3,1);
            histogram(Accuracy, nbins, 'Normalization', 'pdf');
            title(['Accuracy: ' num2str(mean(Accuracy)),' ± ' num2str(std(Accuracy))]);
            subplot(1,3,2);
            histogram(Precision, nbins, 'Normalization', 'pdf');
            title(['Precision: ' num2str(mean(Precision)),' ± ' num2str(std(Precision))]);
            subplot(1,3,3);
            histogram(Recall, nbins, 'Normalization', 'pdf');
            title(['Recall: ' num2str(mean(Recall)),' ± ' num2str(std(Recall))]);
        end
    end
end

