classdef ExperimentViewer < handle
    %EXPERIMENTVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Experiment handle.
        experiment = Experiment;
        
        % Channel viewers.
        channelImageViewers = ChannelImageViewer.empty;
        channelSpotProjectionViewers = ChannelSpotProjectionViewer.empty;
        
        menuBtn = gobjects(0);
        refreshUiBtn = gobjects(0);
        
        channelsListHeaderText = gobjects(0);
        addChannelBtn = gobjects(0);
        removeChannelsBtn = gobjects(0);
        channelsListBox = gobjects(0);
        
        layoutHeaderText = gobjects(0);
        showImagesAndOrProjectionsBtnGroup = gobjects(0);
        showImagesBtn = gobjects(0);
        showProjectionsBtn = gobjects(0);
        showImagesAndProjectionsBtn = gobjects(0);
        
        spotsHeaderText = gobjects(0);
        prevSpotBtn = gobjects(0);
        nextSpotBtn = gobjects(0);
        spotIndexEdit = gobjects(0);
        spotTagsEdit = gobjects(0);
        tagsMaskText = gobjects(0);
        tagsMaskEdit = gobjects(0);
        showSpotMarkersCBox = gobjects(0);
        zoomOnSelectedSpotCBox = gobjects(0);
        
        projectionHeaderText = gobjects(0);
        clearProjectionsBtn = gobjects(0);
        projectSpotBtn = gobjects(0);
        projectAllSpotsBtn = gobjects(0);
        
        idealizationHeaderText = gobjects(0);
        clearIdealizationsBtn = gobjects(0);
        idealizeSpotBtn = gobjects(0);
        idealizeAllSpotsBtn = gobjects(0);
        
%         simulationHeaderText = gobjects(0);
%         simulateBtn = gobjects(0);
    end
    
    properties (Access = private)
        resizeListener = event.listener.empty;
        selectedSpotIndexChangedListener = event.listener.empty;
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
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
                'Callback', @(varargin) obj.addChannel());
            obj.removeChannelsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '-', 'BackgroundColor', [1 .6 .6], ...
                'Callback', @(varargin) obj.removeChannels());
            obj.channelsListBox = uicontrol(parent, 'Style', 'listbox', ...
                'Callback', @(varargin) obj.showChannels());
            
            obj.layoutHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Layout', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.showImagesAndOrProjectionsBtnGroup = uibuttongroup(parent, ...
                'BorderType', 'none', 'Units', 'pixels');
            obj.showImagesBtn = uicontrol(obj.showImagesAndOrProjectionsBtnGroup, ...
                'Style', 'togglebutton', 'String', 'Img', 'Value', 0, ...
                'Callback', @(varargin) obj.resize());
            obj.showProjectionsBtn = uicontrol(obj.showImagesAndOrProjectionsBtnGroup, ...
                'Style', 'togglebutton', 'String', 'Proj', 'Value', 0, ...
                'Callback', @(varargin) obj.resize());
            obj.showImagesAndProjectionsBtn = uicontrol(obj.showImagesAndOrProjectionsBtnGroup, ...
                'Style', 'togglebutton', 'String', 'Img & Proj', 'Value', 1, ...
                'Callback', @(varargin) obj.resize());
            
            obj.spotsHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Spots', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.prevSpotBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '<', 'Callback', @(varargin) obj.prevSpot());
            obj.nextSpotBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', '>', 'Callback', @(varargin) obj.nextSpot());
            obj.spotIndexEdit = uicontrol(parent, 'Style', 'edit', ...
                'Callback', @(varargin) obj.goToSpot());
            obj.spotTagsEdit = uicontrol(parent, 'Style', 'edit', ...
                'Tooltip', 'spot tags', ...
                'Callback', @(varargin) obj.onSpotTagsEdited());
            obj.tagsMaskText = uicontrol(parent, 'Style', 'text', ...
                'String', 'tag mask', 'HorizontalAlignment', 'right');
            obj.tagsMaskEdit = uicontrol(parent, 'Style', 'edit', ...
                'Tooltip', 'navigate only spots with any of these tags', ...
                'Callback', @(varargin) obj.onTagsMaskEdited());
            obj.showSpotMarkersCBox = uicontrol(parent, 'Style', 'checkbox', ...
                'String', 'show spot markers', 'Value', 1, ...
                'Tooltip', 'show all spots on image', ...
                'Callback', @(varargin) obj.updateShowSpotMarkers());
            obj.zoomOnSelectedSpotCBox = uicontrol(parent, 'Style', 'checkbox', ...
                'String', 'zoom on selected spot', 'Value', 0, ...
                'Tooltip', 'zoom images on selected spot', ...
                'Callback', @(varargin) obj.updateZoomOnSelectedSpot());
            
            obj.projectionHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Projections', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.clearProjectionsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'clear', ...
                'Tooltip', 'clear all spot projections in selected channels', ...
                'Callback', @(varargin) obj.clearProjections());
            obj.projectSpotBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'visible', ...
                'Tooltip', 'update selected spot projection in selected channels', ...
                'Callback', @(varargin) obj.projectSelectedSpot());
            obj.projectAllSpotsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'all', ...
                'Tooltip', 'update all spot projections in selected channels', ...
                'Callback', @(varargin) obj.projectAllSpots());
            
            obj.idealizationHeaderText = uicontrol(parent, 'Style', 'text', ...
                'String', 'Idealization', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.clearIdealizationsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'clear', ...
                'Tooltip', 'clear all spot projection idealizations in selected channels', ...
                'Callback', @(varargin) obj.clearIdealizations());
            obj.idealizeSpotBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'visible', ...
                'Tooltip', 'idealize selected spot projection in selected channels', ...
                'Callback', @(varargin) obj.idealizeSelectedSpot());
            obj.idealizeAllSpotsBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'all', ...
                'Tooltip', 'idealize all spot projections in selected channels', ...
                'Callback', @(varargin) obj.idealizeAllSpots());
%             
%             obj.simulationHeaderText = uicontrol(parent, 'Style', 'text', ...
%                 'String', 'Simulation', 'HorizontalAlignment', 'left', ...
%                 'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
%             obj.simulateBtn = uicontrol(parent, 'Style', 'pushbutton', ...
%                 'String', 'simulate projections', ...
%                 'Callback', @(varargin) obj.simulate());
            
%             obj.Parent = parent; % calls resize() and updateResizeListener()
            obj.resize();
            obj.updateResizeListener();
            
            if ~isempty(obj.experiment)
                obj.experiment = obj.experiment; % sets listeners and stuff
            end
        end
        
        function delete(obj)
            %DELETE Delete all graphics object properties and listeners.
            delete(obj.resizeListener);
            delete(obj.channelImageViewers);
            delete(obj.channelSpotProjectionViewers);
            h = [ ...
                obj.menuBtn ...
                obj.refreshUiBtn ...
                obj.channelsListHeaderText ...
                obj.addChannelBtn ...
                obj.removeChannelsBtn ...
                obj.channelsListBox ...
                obj.layoutHeaderText ...
                obj.showImagesAndOrProjectionsBtnGroup ...
                obj.spotsHeaderText ...
                obj.prevSpotBtn ...
                obj.nextSpotBtn ...
                obj.spotIndexEdit ...
                obj.spotTagsEdit ...
                obj.tagsMaskText ...
                obj.tagsMaskEdit ...
                obj.showSpotMarkersCBox ...
                obj.zoomOnSelectedSpotCBox ...
                obj.projectionHeaderText ...
                obj.clearProjectionsBtn ...
                obj.projectSpotBtn ...
                obj.projectAllSpotsBtn ...
                obj.idealizationHeaderText ...
                obj.clearIdealizationsBtn ...
                obj.idealizeSpotBtn ...
                obj.idealizeAllSpotsBtn ...
                ... %obj.simulationHeaderText ...
                ... %obj.simulateBtn ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function deleteListeners(obj)
            if isvalid(obj.selectedSpotIndexChangedListener)
                delete(obj.selectedSpotIndexChangedListener);
                obj.selectedSpotIndexChangedListener = event.listener.empty;
            end
        end
        
        function updateListeners(obj)
            obj.deleteListeners();
            if ~isempty(obj.experiment)
                obj.selectedSpotIndexChangedListener = ...
                    addlistener(obj.experiment, 'SelectedSpotIndexChanged', ...
                    @(varargin) obj.onSelectedSpotIndexChanged());
            end
        end
        
        function set.experiment(obj, experiment)
            obj.experiment = experiment;
            
            % delete old channel viewers
            delete(obj.channelImageViewers);
            delete(obj.channelSpotProjectionViewers);

            % create new channel viewers
            nchannels = numel(experiment.channels);
            obj.channelImageViewers = ChannelImageViewer.empty;
            obj.channelSpotProjectionViewers = ChannelSpotProjectionViewer.empty;
            for c = 1:nchannels
                obj.channelImageViewers(c) = ChannelImageViewer(obj.Parent);
                obj.channelImageViewers(c).channel = experiment.channels(c);
                obj.channelImageViewers(c).removeResizeListener(); % Handled by this class.
                obj.channelSpotProjectionViewers(c) = ChannelSpotProjectionViewer(obj.Parent);
                obj.channelSpotProjectionViewers(c).channel = experiment.channels(c);
                obj.channelSpotProjectionViewers(c).removeResizeListener(); % Handled by this class.
            end
            
            % update channels list box and refresh channels display
            obj.updateChannelsListBox();
            obj.showChannels();
            
            % link axes
            if ~isempty(obj.channelImageViewers)
                linkaxes(horzcat(obj.channelImageViewers.imageAxes), 'xy');
            end
            if ~isempty(obj.channelSpotProjectionViewers)
                linkaxes(horzcat(obj.channelSpotProjectionViewers.projAxes), 'x');
            end
            
            % update projections
            for viewer = obj.channelSpotProjectionViewers
                viewer.updateProjection();
            end
            
            % update listeners
            obj.updateListeners();
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
            for viewer = obj.channelImageViewers
                viewer.Parent = parent;
            end
            for viewer = obj.channelSpotProjectionViewers
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
            lh = 15;
            y = y0 + h - lh;
            obj.menuBtn.Position = [x0 y lh lh];
            obj.refreshUiBtn.Position = [x0+lh y lh lh];
            % channels
            y = y - margin - lh;
            obj.channelsListHeaderText.Position = [x0 y wc-2*lh lh];
            obj.addChannelBtn.Position = [x0+wc-2*lh y lh lh];
            obj.removeChannelsBtn.Position = [x0+wc-lh y lh lh];
            y = y - 100;
            obj.channelsListBox.Position = [x0 y wc 100];
            % layout
            y = y - margin - lh;
            obj.layoutHeaderText.Position = [x0 y wc lh];
            y = y - lh;
            obj.showImagesAndOrProjectionsBtnGroup.Position = [x0 y wc lh];
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
            y = y - lh;
            obj.tagsMaskText.Position = [x0 y 50 lh];
            obj.tagsMaskEdit.Position = [x0+50 y wc-50 lh];
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
            % projections
            y = y - margin - lh;
            obj.projectionHeaderText.Position = [x0 y wc lh];
            y = y - 20;
            obj.clearProjectionsBtn.Position = [x0 y wc/3 20];
            obj.projectSpotBtn.Position = [x0+wc/3 y wc/3 20];
            obj.projectAllSpotsBtn.Position = [x0+wc*2/3 y wc/3 20];
            % idealization
            y = y - margin - lh;
            obj.idealizationHeaderText.Position = [x0 y wc lh];
            y = y - 20;
            obj.clearIdealizationsBtn.Position = [x0 y wc/3 20];
            obj.idealizeSpotBtn.Position = [x0+wc/3 y wc/3 20];
            obj.idealizeAllSpotsBtn.Position = [x0+wc*2/3 y wc/3 20];
%             % simulation
%             y = y - margin - lh;
%             obj.simulationHeaderText.Position = [x0 y wc lh];
%             y = y - lh;
%             obj.simulateBtn.Position = [x0 y wc lh];
            
            % visible channels
            nchannels = numel(obj.experiment.channels);
            vischannels = obj.getVisibleChannelIndices();
            nvischannels = numel(vischannels);
            invischannels = setdiff(1:nchannels, vischannels);
            showImages = obj.showImagesBtn.Value || obj.showImagesAndProjectionsBtn.Value;
            showProjections = obj.showProjectionsBtn.Value || obj.showImagesAndProjectionsBtn.Value;
            if ~showImages
                [obj.channelImageViewers.Visible] = deal(0);
            end
            if ~showProjections
                [obj.channelSpotProjectionViewers.Visible] = deal(0);
            end
            if ~isempty(invischannels)
                [obj.channelImageViewers(invischannels).Visible] = deal(0);
                [obj.channelSpotProjectionViewers(invischannels).Visible] = deal(0);
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
                        imstack = obj.channelImageViewers(c).imageStack;
                        ratio = imstack.width() / imstack.height();
                        if ~isinf(ratio) && ratio > 0 && ratio > whratio
                            whratio = ratio;
                        end
                    end
                    wim = max(1, min(whratio * (hc - 30 - 2 * margin), wc / 2)) + 15;
                end
                for c = vischannels
                    if showImages && showProjections
                        obj.channelImageViewers(c).Position = [x y wim hc];
                        obj.channelSpotProjectionViewers(c).Position = [x+wim+10 y wc-wim-10 hc];
                    elseif showImages
                        obj.channelImageViewers(c).Position = [x y wc hc];
                    elseif showProjections
                        obj.channelSpotProjectionViewers(c).Position = [x y wc hc];
                    end
                    if showImages
                        obj.channelImageViewers(c).showFrame();
                    end
                    y = y - sep - hc;
                end
                if showImages
                    [obj.channelImageViewers(vischannels).Visible] = deal(1);
                end
                if showProjections
                    [obj.channelSpotProjectionViewers(vischannels).Visible] = deal(1);
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
                obj.channelsListBox.Value = [obj.channelsListBox.Value numel(obj.experiment.channels)];
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
            
            if questdlg('Remove selected channels?', 'Remove Channels') ~= "Yes"
                return
            end
            
            selected = false(1, numel(obj.experiment.channels));
            selected(obj.getVisibleChannelIndices()) = true;
            selected(idx) = [];
            
            delete(obj.experiment.channels(idx));
            obj.experiment.channels(idx) = [];
            
            obj.channelsListBox.Value = find(selected);
%             obj.channelsListBox.String = cellstr(horzcat(obj.experiment.channels.label));
            obj.experiment = obj.experiment; % updates everything
            
%             delete(obj.channelImageViewers(idx));
%             obj.channelImageViewers(idx) = [];
%             
%             delete(obj.channelSpotProjectionViewers(idx));
%             obj.channelSpotProjectionViewers(idx) = [];
%             
%             obj.channelsListBox.Value = find(selected);
%             obj.updateChannelsListBox();
%             
%             obj.showChannels();
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
                obj.channelsListBox.Value = unique(idx);
            end
        end
        
        function idx = getVisibleChannelIndices(obj)
            idx = obj.channelsListBox.Value;
            nchannels = numel(obj.experiment.channels);
            idx(idx < 1) = [];
            idx(idx > nchannels) = [];
        end
        
        function showChannels(obj, idx)
            if ~exist('idx', 'var')
                idx = obj.getVisibleChannelIndices();
            end
            nchannels = numel(obj.experiment.channels);
            idx(idx < 1) = [];
            idx(idx > nchannels) = [];
            obj.channelsListBox.Value = unique(idx);
            for c = 1:nchannels
                obj.channelImageViewers(c).refresh();
            end
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
            
            uimenu(menu, 'Label', 'Load All Data', ...
                'Callback', @(varargin) obj.loadData());
            uimenu(menu, 'Label', 'Save All Data', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.saveData());
            
            uimenu(menu, 'Label', 'Reload All Missing Images', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.reloadAllMissingImages());
            
            uimenu(menu, 'Label', 'Refresh UI', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.refreshUi());
        end
        
        function refreshUi(obj)
            obj.experiment = obj.experiment;
            obj.resize();
            obj.updateShowSpotMarkers();
        end
        
        function goToSpot(obj, k)
            if ~exist('k', 'var')
                k = str2num(obj.spotIndexEdit.String);
            end
            obj.experiment.selectedSpotIndex = k;
        end
        
        function prevSpot(obj)
            obj.experiment.prevSpot();
        end
        
        function nextSpot(obj)
            obj.experiment.nextSpot();
        end
        
        function onSelectedSpotIndexChanged(obj)
            k = obj.experiment.selectedSpotIndex;
            % update spot index edit
            obj.spotIndexEdit.String = num2str(k);
            % update spot tags edit
            ok = false;
            for channel = obj.experiment.channels
                if numel(channel.spots) >= k
                    obj.spotTagsEdit.String = channel.spots(k).getTagsString();
                    ok = true;
                    break
                end
            end
            if ~ok
                obj.spotTagsEdit.String = '';
            end
            % update spots header
            nspots = arrayfun(@(channel) numel(channel.spots), obj.experiment.channels);
            nspotsmax = max(nspots);
            obj.spotsHeaderText.String = ['Spots (' num2str(nspotsmax) ')'];
        end
        
        function onSpotTagsEdited(obj)
            k = obj.experiment.selectedSpotIndex;
            for channel = obj.experiment.channels
                if numel(channel.spots) >= k
                    channel.spots(k).tags = obj.spotTagsEdit.String;
                    return
                end
            end
        end
        
        function onTagsMaskEdited(obj)
            obj.experiment.spotTagsMask = obj.tagsMaskEdit.String;
        end
        
        function updateShowSpotMarkers(obj)
            for viewer = obj.channelImageViewers
                for marker = viewer.spotMarkers
                    marker.Visible = obj.showSpotMarkersCBox.Value == 1;
                end
            end
        end
        
        function updateZoomOnSelectedSpot(obj)
        end
        
%         function simulate(obj)
%             vischannels = obj.getVisibleChannelIndices();
%             if isempty(vischannels)
%                 return
%             end
%             channel = obj.experiment.channels(vischannels(1));
%             channel.simulateSpotProjections();
%         end

        function clearProjections(obj)
            if questdlg('Clear all projections in selected channels?', 'Clear Projections?') ~= "Yes"
                return
            end
            idx = obj.getVisibleChannelIndices();
            if isempty(idx)
                return
            end
            for channel = obj.experiment.channels(idx)
                channel.clearSpotProjections();
            end
        end
        
        function projectSelectedSpot(obj)
            idx = obj.getVisibleChannelIndices();
            if isempty(idx)
                return
            end
            for channel = obj.experiment.channels(idx)
                channel.updateSpotProjections(channel.selectedSpot);
            end
        end
        
        function projectAllSpots(obj)
            if questdlg('Idealize all spots in selected channels?', 'Idealize All Spots?') ~= "Yes"
                return
            end
            idx = obj.getVisibleChannelIndices();
            if isempty(idx)
                return
            end
            for channel = obj.experiment.channels(idx)
                spots = getTaggedSpots(channel.spots, obj.experiment.spotTagsMask);
                channel.updateSpotProjections(spots);
            end
        end

        function clearIdealizations(obj)
            if questdlg('Clear all idealizations in selected channels?', 'Clear Idealizations?') ~= "Yes"
                return
            end
            idx = obj.getVisibleChannelIndices();
            if isempty(idx)
                return
            end
            for channel = obj.experiment.channels(idx)
                %channel.clearAllSpotProjectionIdealizations();
            end
        end
        
        function idealizeSelectedSpot(obj)
            idx = obj.getVisibleChannelIndices();
            if isempty(idx)
                return
            end
            for channel = obj.experiment.channels(idx)
                %channel.idealizeSelectedSpotProjection();
            end
        end
        
        function idealizeAllSpots(obj)
            if questdlg('Idealize all spots in selected channels?', 'Idealize All Spots?') ~= "Yes"
                return
            end
            idx = obj.getVisibleChannelIndices();
            if isempty(idx)
                return
            end
            for channel = obj.experiment.channels(idx)
                %channel.idealizeAllSpotProjections(obj.experiment.spotTagsMask);
            end
        end
    end
end

