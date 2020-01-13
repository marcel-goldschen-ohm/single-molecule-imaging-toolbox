classdef ExperimentViewer < handle
    %EXPERIMENTVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % experiment data
        hExperiment = Experiment.empty;
        
        % UI elements
        hFigure
        hChannelImageViewers = ChannelImageViewer.empty(1,0);
        hChannelSpotViewers = ChannelSpotViewer.empty(1,0);
        hMsgText
        
        hChannelsListHeaderText
        hAddChannelBtn
        hRemoveChannelsBtn
        hChannelsListBox
        
        hLayoutHeaderText
        hLayoutBtnGroup
        hShowImagesOnlyBtn
        hShowTracesOnlyBtn
        hShowImagesAndTracesBtn
        
        hSpotsHeaderText
        hPrevSpotBtn
        hNextSpotBtn
        hSpotIndexEdit
        hSpotTagsEdit
        hShowSpotMarkersCBox
        hZoomOnSelectedSpotCBox
        
        hSelectionHeaderText
        hSelectionBtnGroup
        hSelectAllChannelsBtn
        hSelectVisibleChannelsBtn
        hSelectVisibleSpotsBtn
        hSelectionTagsMaskCBox
        hSelectionTagsMaskEdit
        
        hActionsHeaderText
        hZProjectSpotsBtn
        hModelSpotTracesBtn
        hSelectTsModelPopup
        hEditTsModelParamsBtn
    end
    
    properties (Access = private)
        selectedSpotIndexChangedListener = event.listener.empty;
        channelLabelChangedListeners = event.listener.empty;
    end
    
    methods
        function obj = ExperimentViewer(parent)
            %EXPERIMENTVIEWER Constructor.
            
            obj.hFigure = figure('Name', 'Single-Molecule Experiment Viewer', ...
                'Units', 'normalized', 'Position', [0.1 0.2 0.8 0.6], ...
                'MenuBar', 'none', 'ToolBar', 'figure', 'numbertitle', 'off', ...
                'UserData', obj ... % ref this object
                );
            obj.hFigure.Units = 'pixels';
            addToolbarExplorationButtons(obj.hFigure); % old style
            if exist('parent', 'var') && isvalid(parent) && isgraphics(parent)
            	obj.hFigure.Parent = parent;
            end
            
            % menubar --------------
            hFileMenu = uimenu(obj.hFigure, 'Text', '&File');
            uimenu(hFileMenu, 'Text', '&Open', 'Accelerator', 'O', ...
                'Callback', @(varargin) obj.open());
            uimenu(hFileMenu, 'Text', '&Reload All Missing Images', 'Separator', 'on', ...
                'Callback', @(varargin) obj.reloadAllMissingImages());
            uimenu(hFileMenu, 'Text', '&Save', 'Accelerator', 'S', 'Separator', 'on', ...
                'Callback', @(varargin) obj.save());
            uimenu(hFileMenu, 'Text', '&Export Figure', 'Separator', 'on', ...
                'Callback', @(varargin) obj.saveFigure());
            uimenu(hFileMenu, 'Text', '&Close', 'Accelerator', 'W', 'Separator', 'on', ...
                'Callback', @(varargin) obj.close());
            
            hEditMenu = uimenu(obj.hFigure, 'Text', '&Edit');
            uimenu(hEditMenu, 'Text', '&Refresh UI', 'Accelerator', 'R', ...
                'Callback', @(varargin) obj.refresh());
            uimenu(hEditMenu, 'Text', '&Notes', 'Separator', 'on', ...
                'Callback', @(varargin) obj.editNotes());
            
            % channel controls --------------
            obj.hChannelsListHeaderText = uicontrol(obj.hFigure, 'Style', 'text', ...
                'String', ' Channels', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.hAddChannelBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', '+', 'BackgroundColor', [.6 .9 .6], ...
                'Tooltip', 'Add Channel', ...
                'Callback', @(varargin) obj.addChannel());
            obj.hRemoveChannelsBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', '-', 'BackgroundColor', [1 .6 .6], ...
                'Tooltip', 'Remove Selected Channels', ...
                'Callback', @(varargin) obj.removeChannels());
            obj.hChannelsListBox = uicontrol(obj.hFigure, 'Style', 'listbox', ...
                'Callback', @(varargin) obj.refresh());
            
            % layout controls --------------
            obj.hLayoutHeaderText = uicontrol(obj.hFigure, 'Style', 'text', ...
                'String', ' Layout', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.hLayoutBtnGroup = uibuttongroup(obj.hFigure, ...
                'BorderType', 'none', 'Units', 'pixels');
            obj.hShowImagesOnlyBtn = uicontrol(obj.hLayoutBtnGroup, 'Style', 'togglebutton', ...
                'String', 'Img', 'Value', 0, ...
                'Tooltip', 'Show Images Only', ...
                'Callback', @(varargin) obj.resize());
            obj.hShowTracesOnlyBtn = uicontrol(obj.hLayoutBtnGroup, 'Style', 'togglebutton', ...
                'String', 'Trace', 'Value', 0, ...
                'Tooltip', 'Show Spot Traces Only', ...
                'Callback', @(varargin) obj.resize());
            obj.hShowImagesAndTracesBtn = uicontrol(obj.hLayoutBtnGroup, 'Style', 'togglebutton', ...
                'String', 'Img & Trace', 'Value', 1, ...
                'Tooltip', 'Show Images and Spot Traces', ...
                'Callback', @(varargin) obj.resize());
            
            % spot controls --------------
            obj.hSpotsHeaderText = uicontrol(obj.hFigure, 'Style', 'text', ...
                'String', ' Spots', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.hPrevSpotBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', '<', 'Tooltip', 'Previous Spot', ...
                'Callback', @(varargin) obj.prevSpot());
            obj.hNextSpotBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', '>', 'Tooltip', 'Next Spot', ...
                'Callback', @(varargin) obj.nextSpot());
            obj.hSpotIndexEdit = uicontrol(obj.hFigure, 'Style', 'edit', ...
                'Tooltip', 'Selected Spot Index', ...
                'Callback', @(varargin) obj.goToSpot());
            obj.hSpotTagsEdit = uicontrol(obj.hFigure, 'Style', 'edit', ...
                'Tooltip', 'Selected Spot Tags (comma-separated)', ...
                'Callback', @(varargin) obj.onSpotTagsEdited());
            obj.hShowSpotMarkersCBox = uicontrol(obj.hFigure, 'Style', 'checkbox', ...
                'String', 'show spot markers', 'Value', 1, ...
                'Tooltip', 'Show all spots on image', ...
                'Callback', @(varargin) obj.updateShowSpotMarkers());
            obj.hZoomOnSelectedSpotCBox = uicontrol(obj.hFigure, 'Style', 'checkbox', ...
                'String', 'zoom on selected spot', 'Value', 0, ...
                'Tooltip', 'Zoom images on selected spot', ...
                'Callback', @(varargin) obj.updateZoomOnSelectedSpot());
            
            % selection controls --------------
            obj.hSelectionHeaderText = uicontrol(obj.hFigure, 'Style', 'text', ...
                'String', ' Selection', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.hSelectionBtnGroup = uibuttongroup(obj.hFigure, ...
                'BorderType', 'none', 'Units', 'pixels');
            obj.hSelectAllChannelsBtn = uicontrol(obj.hSelectionBtnGroup, ...
                'Style', 'radiobutton', 'String', 'all channels', 'Value', 0);
            obj.hSelectVisibleChannelsBtn = uicontrol(obj.hSelectionBtnGroup, ...
                'Style', 'radiobutton', 'String', 'visible channels', 'Value', 0);
            obj.hSelectVisibleSpotsBtn = uicontrol(obj.hSelectionBtnGroup, ...
                'Style', 'radiobutton', 'String', 'visible spots', 'Value', 1);
            obj.hSelectionTagsMaskCBox = uicontrol(obj.hFigure, 'Style', 'checkbox', ...
                'String', 'tags', 'Value', 1, ...
                'Tooltip', 'Only select spots with any of these tags');
            obj.hSelectionTagsMaskEdit = uicontrol(obj.hFigure, 'Style', 'edit', ...
                'Tooltip', 'Only select spots with any of these tags');
            
            % action controls --------------
            obj.hActionsHeaderText = uicontrol(obj.hFigure, 'Style', 'text', ...
                'String', 'Actions', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 0]);
            obj.hZProjectSpotsBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', 'Z-Project Spot Traces', 'Callback', @(varargin) obj.zprojectSpots());
            obj.hModelSpotTracesBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', 'Model Spot Traces', 'Callback', @(varargin) obj.modelSpotTraces());
            obj.hSelectTsModelPopup = uicontrol(obj.hFigure, 'Style', 'popupmenu', ...
                'String', {'DISC'}, ...
                'Tooltip', 'Select Model', ...
                'Callback', @(s,e) obj.setTsModel(s.String{s.Value}));
            obj.hEditTsModelParamsBtn = uicontrol(obj.hFigure, 'Style', 'pushbutton', ...
                'String', char(hex2dec('23e3')), ...
                'Tooltip', 'Edit Model Parameters', ...
                'Callback', @(varargin) obj.editTsModelParams());

            % message text --------------
            obj.hMsgText = uicontrol(obj.hFigure, 'Style', 'text', ...
                'String', '... UI messages ...', 'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1 1 1], 'BackgroundColor', [0 0 1]);
            
            % make sure we have a valid experiment
            obj.hExperiment = Experiment();

            % layout
            obj.hFigure.SizeChangedFcn = @(varargin) obj.resize();
            %obj.resize(); % called when setting experiment
        end
        function delete(obj)
            %DELETE Delete all graphics objects and listeners.
            obj.deleteListeners();
            delete(obj.hChannelImageViewers);
%             delete(obj.timeSeriesViewers);
            delete(obj.hFigure); % will delete all other child graphics objects
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
            obj.selectedSpotIndexChangedListener = ...
                addlistener(obj.hExperiment, 'SelectedSpotIndexChanged', ...
                @(varargin) obj.onSelectedSpotIndexChanged());
            for c = 1:numel(obj.hExperiment.hChannels)
                obj.channelLabelChangedListeners(c) = ...
                    addlistener(obj.hExperiment.hChannels(c), 'LabelChanged', ...
                    @(varargin) obj.updateChannelsListBox());
            end
        end
        
        function set.hExperiment(obj, h)
            obj.hExperiment = h;

            % update channel viewers
            for c = 1:numel(obj.hChannelImageViewers)
                obj.hChannelImageViewers(c).clearAllRelatedViewers;
            end
            for c = 1:numel(obj.hChannelSpotViewers)
                obj.hChannelSpotViewers(c).clearAllRelatedViewers;
            end
            numChannels = numel(obj.hExperiment.hChannels);
            for c = 1:min(numChannels, numel(obj.hChannelImageViewers))
                obj.hChannelImageViewers(c).hChannel = obj.hExperiment.hChannels(c);
            end
            for c = 1:min(numChannels, numel(obj.hChannelSpotViewers))
                obj.hChannelSpotViewers(c).hChannel = obj.hExperiment.hChannels(c);
            end
            for c = numel(obj.hChannelImageViewers)+1:numChannels
                obj.hChannelImageViewers(c) = ChannelImageViewer(obj.hFigure);
                obj.hChannelImageViewers(c).hChannel = obj.hExperiment.hChannels(c);
                obj.hChannelImageViewers(c).hPanel.Units = 'pixels';
            end
            for c = numel(obj.hChannelSpotViewers)+1:numChannels
                obj.hChannelSpotViewers(c) = ChannelSpotViewer(obj.hFigure);
                obj.hChannelSpotViewers(c).hChannel = obj.hExperiment.hChannels(c);
                obj.hChannelSpotViewers(c).hPanel.Units = 'pixels';
            end
            if numel(obj.hChannelImageViewers) > numChannels
                delete(obj.hChannelImageViewers(numChannels+1:end));
                obj.hChannelImageViewers(numChannels+1:end) = [];
            end
            if numel(obj.hChannelSpotViewers) > numChannels
                delete(obj.hChannelSpotViewers(numChannels+1:end));
                obj.hChannelSpotViewers(numChannels+1:end) = [];
            end
            for k = 1:numChannels
                obj.hChannelImageViewers(k).setSiblingViewers(setdiff(obj.hChannelImageViewers, obj.hChannelImageViewers(k)));
                obj.hChannelSpotViewers(k).setSiblingViewers(setdiff(obj.hChannelSpotViewers, obj.hChannelSpotViewers(k)));
            end
            
            % link axes
            if ~isempty(obj.hChannelImageViewers)
                linkaxes(horzcat(obj.hChannelImageViewers.hAxes), 'xy');
            end
            if ~isempty(obj.hChannelSpotViewers)
                linkaxes(horzcat(obj.hChannelSpotViewers.hTraceAxes), 'x');
            end
            
            % update stuff
            obj.hSelectionTagsMaskEdit.String = obj.hExperiment.getSpotSelectionTagsMaskString();
            obj.hSelectionTagsMaskEdit.Callback = @(s,e) obj.hExperiment.setSpotSelectionTagsMask(s.String);
            obj.hSelectionTagsMaskCBox.Value = obj.hExperiment.applySpotSelectionTagsMask;
            obj.hSelectionTagsMaskCBox.Callback = @(s,e) obj.hExperiment.setApplySpotSelectionTagsMask(s.Value == 1);
            obj.updateListeners();
            obj.updateChannelsListBox();
            
            % initial spot
            if ~isempty(obj.hExperiment.selectedSpotIndex)
                obj.goToSpot(obj.hExperiment.selectedSpotIndex);
            else
                obj.goToSpot(1);
            end
            
%             % update channels list box and refresh channels display
%             obj.showChannels();

            obj.resize(); % update layout
        end
        
        function resize(obj)
            %RESIZE Reposition all objects.
            
            showImages = logical(obj.hShowImagesOnlyBtn.Value) || logical(obj.hShowImagesAndTracesBtn.Value);
            showTraces = logical(obj.hShowTracesOnlyBtn.Value) || logical(obj.hShowImagesAndTracesBtn.Value);
            
            bbox = getpixelposition(obj.hFigure);
            margin = 2;
            lineh = 20;
            
            x = margin;
            y = bbox(4) - margin;
            w = 150;
            
            y = y - lineh;
            obj.hChannelsListHeaderText.Position = [x y w-2*lineh lineh];
            obj.hAddChannelBtn.Position = [x+w-2*lineh y lineh lineh];
            obj.hRemoveChannelsBtn.Position = [x+w-lineh y lineh lineh];
            y = y - 8*lineh;
            obj.hChannelsListBox.Position = [x y w 8*lineh];
            
            y = y - margin - lineh;
            obj.hLayoutHeaderText.Position = [x y w lineh];
            y = y - lineh;
            obj.hLayoutBtnGroup.Position = [x y w lineh];
            obj.hShowImagesOnlyBtn.Position = [0 0 0.27*w lineh];
            obj.hShowTracesOnlyBtn.Position = [0.27*w 0 0.27*w lineh];
            obj.hShowImagesAndTracesBtn.Position = [0.54*w 0 0.46*w lineh];
            
            y = y - margin - lineh;
            obj.hSpotsHeaderText.Position = [x y w lineh];
            y = y - 2*lineh;
            obj.hPrevSpotBtn.Position = [x y 2*lineh 2*lineh];
            obj.hNextSpotBtn.Position = [x+w-2*lineh y 2*lineh 2*lineh];
            obj.hSpotIndexEdit.Position = [x+2*lineh y+lineh w-4*lineh lineh];
            obj.hSpotTagsEdit.Position = [x+2*lineh y w-4*lineh lineh];
            if showImages
                y = y - lineh;
                obj.hShowSpotMarkersCBox.Position = [x y w lineh];
                obj.hShowSpotMarkersCBox.Visible = 'on';
                y = y - lineh;
                obj.hZoomOnSelectedSpotCBox.Position = [x y w lineh];
                obj.hZoomOnSelectedSpotCBox.Visible = 'on';
            else
                obj.hShowSpotMarkersCBox.Visible = 'off';
                obj.hZoomOnSelectedSpotCBox.Visible = 'off';
            end
            
            y = y - margin - lineh;
            obj.hSelectionHeaderText.Position = [x y w lineh];
            y = y - 3*lineh;
            obj.hSelectionBtnGroup.Position = [x y w 3*lineh];
            obj.hSelectAllChannelsBtn.Position = [0 2*lineh w lineh];
            obj.hSelectVisibleChannelsBtn.Position = [0 lineh w lineh];
            obj.hSelectVisibleSpotsBtn.Position = [0 0 w lineh];
            y = y - lineh;
            obj.hSelectionTagsMaskCBox.Position = [x y 50 lineh];
            obj.hSelectionTagsMaskEdit.Position = [x+50 y w-50 lineh];
            
            y = y - margin - lineh;
            obj.hActionsHeaderText.Position = [x y w lineh];
            y = y - lineh;
            obj.hZProjectSpotsBtn.Position = [x y w lineh];
            y = y - lineh;
            obj.hModelSpotTracesBtn.Position = [x y w lineh];
            y = y - lineh;
            obj.hSelectTsModelPopup.Position = [x y w-lineh lineh];
            obj.hEditTsModelParamsBtn.Position = [x+w-lineh y lineh lineh];
            
            y = margin;
            obj.hMsgText.Position = [x y w lineh];
            
            % channels
            numChannels = numel(obj.hExperiment.hChannels);
            visChannelIndices = obj.getVisibleChannelIndices();
            numVisChannels = numel(visChannelIndices);
            invisChannelIndices = setdiff(1:numChannels, visChannelIndices);
            % hide stuff
            if ~showImages
                [obj.hChannelImageViewers.Visible] = deal('off');
            end
            if ~showTraces
                [obj.hChannelSpotViewers.Visible] = deal('off');
            end
            if ~isempty(invisChannelIndices)
                [obj.hChannelImageViewers(invisChannelIndices).Visible] = deal('off');
                [obj.hChannelSpotViewers(invisChannelIndices).Visible] = deal('off');
            end
            % show stuff
            if numVisChannels > 0
                sep = margin;
                x = x + w + margin + 5;
                y = margin;
                w = bbox(3) - margin - x;
                h = bbox(4) - margin - y;
                y = y + h;
                h = floor((h - (numVisChannels - 1) * sep) / numVisChannels); % per vis channel
                y = y - h;
                if showImages && showTraces
                    whratio = 1; % width / height image ratio
                    for c = visChannelIndices
                        hImage = obj.hChannelImageViewers(c).hImageStack;
                        if ~isempty(hImage)
                            ratio = hImage.width / hImage.height;
                            if ~isinf(ratio) && ratio > 0 && ratio > whratio
                                whratio = ratio;
                            end
                        end
                    end
                    wim = max(1, min(whratio * (h - 30 - 2 * margin), w / 2 - 50)) + 15;
                end
                for c = visChannelIndices
                    if showImages && showTraces
                        obj.hChannelImageViewers(c).Position = [x y wim h];
                        obj.hChannelSpotViewers(c).Position = [x+wim+5 y w-wim-5 h];
                    elseif showImages
                        obj.hChannelImageViewers(c).Position = [x y w h];
                    elseif showTraces
                        obj.hChannelSpotViewers(c).Position = [x y w h];
                    end
%                     if showImages
%                         obj.imageViewers(c).showFrame();
%                     end
                    y = y - sep - h;
                end
                if showImages
                    [obj.hChannelImageViewers(visChannelIndices).Visible] = deal('on');
                end
                if showTraces
                    [obj.hChannelSpotViewers(visChannelIndices).Visible] = deal('on');
                end
            end
        end
        function refresh(obj)
            obj.hExperiment = obj.hExperiment;
        end
        
        function idx = getVisibleChannelIndices(obj)
            idx = obj.hChannelsListBox.Value;
            numChannels = numel(obj.hExperiment.hChannels);
            idx(idx < 1) = [];
            idx(idx > numChannels) = [];
        end
        function setVisibleChannelIndices(obj, idx)
            obj.updateChannelsListBox();
            obj.hChannelsListBox.Value = idx;
            obj.refresh();
        end
        function hVisibleChannels = getVisibleChannels(obj)
            idx = obj.getVisibleChannelIndices();
            hVisibleChannels = obj.hExperiment.hChannels(idx);
        end
        function addChannel(obj)
            obj.hExperiment.hChannels = [obj.hExperiment.hChannels Channel()];
            obj.updateChannelsListBox();
            % add new channel to list box selection
            numChannels = numel(obj.hExperiment.hChannels);
            if numChannels > 1
                obj.hChannelsListBox.Value = unique([obj.hChannelsListBox.Value numel(obj.hExperiment.hChannels)]);
            end
            % updates everything
            obj.hExperiment = obj.hExperiment;
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
            % find new selected channels
            selected = false(1, numel(obj.hExperiment.hChannels));
            selected(obj.getVisibleChannelIndices()) = true;
            selected(idx) = [];
            % remove channels
            delete(obj.hExperiment.hChannels(idx));
            obj.hExperiment.hChannels(idx) = [];
            % update selection
            obj.hChannelsListBox.Value = find(selected);
            % updates everything
            obj.hExperiment = obj.hExperiment;
        end
        function updateChannelsListBox(obj)
            numChannels = numel(obj.hExperiment.hChannels);
            if numChannels
                obj.hChannelsListBox.String = cellstr(horzcat(obj.hExperiment.hChannels.label));
            else
                obj.hChannelsListBox.String = {};
            end
            obj.hChannelsListBox.Min = 0;
            obj.hChannelsListBox.Max = numChannels;
            if numChannels == 0
                obj.hChannelsListBox.Value = [];
            elseif numChannels == 1
                obj.hChannelsListBox.Value = 1;
            elseif numChannels > 1
                idx = obj.hChannelsListBox.Value;
                idx(idx < 1) = [];
                idx(idx > numChannels) = [];
                if isempty(idx)
                    idx = 1;
                end
                obj.hChannelsListBox.Value = unique(idx);
            end
        end
        
        function open(obj, filepath)
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
            obj.hExperiment = tmp.hExperiment; % updates everything
            % update figure name
            [path, file, ext] = fileparts(filepath);
            obj.hFigure.Name = strrep(file, '_', ' ');
            figure(obj.hFigure);
        end
        function save(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uiputfile('*.mat', 'Save data to file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            wb = waitbar(0, 'Saving experiment to file...');
            hExperiment = obj.hExperiment;
            save(filepath, 'hExperiment', '-v7.3');
            close(wb);
            % update figure name
            [path, file, ext] = fileparts(filepath);
            obj.hFigure.Name = strrep(file, '_', ' ');
            figure(obj.hFigure);
        end
        function saveFigure(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath) || ~isfile(filepath)
                [file, path] = uiputfile({'*.fig'; '*.png'; '*.svg'});
                if isequal(file,0) || isequal(path,0)
                    return
                end
                filepath = fullfile(path, file);
            end
            saveas(obj.hFigure, filepath);
        end
        function close(obj)
            delete(obj);
        end
        function reloadAllMissingImages(obj)
            for c = 1:numel(obj.hExperiment.hChannels)
                obj.hExperiment.hChannels(c).reloadAllMissingImages();
            end
            obj.refresh();
        end
        
        function editNotes(obj)
            obj.hExperiment.editNotes();
        end
        
        function goToSpot(obj, k)
            if ~exist('k', 'var')
                k = str2num(obj.hSpotIndexEdit.String);
            end
            obj.hExperiment.selectedSpotIndex = k;
        end
        function prevSpot(obj)
            obj.hExperiment.prevSpot();
        end
        function nextSpot(obj)
            obj.hExperiment.nextSpot();
        end
        function onSelectedSpotIndexChanged(obj)
            k = obj.hExperiment.selectedSpotIndex;
            % index edit
            obj.hSpotIndexEdit.String = num2str(k);
            % visible channels
            hVisChannels = obj.getVisibleChannels();
            % tags edit
            for hChannel = hVisChannels
                if numel(hChannel.hSpots) >= k
                    obj.hSpotTagsEdit.String = hChannel.hSpots(k).getTagsString();
                    break
                end
            end
            % header
            numSpots = arrayfun(@(hChannel) numel(hChannel.hSpots), hVisChannels);
            obj.hSpotsHeaderText.String = ['Spots (' num2str(max(numSpots)) ')'];
        end
        function onSpotTagsEdited(obj)
            k = obj.hExperiment.selectedSpotIndex;
            for hChannel = obj.hExperiment.hChannels
                if numel(hChannel.hSpots) >= k
                    hChannel.hSpots(k).tags = obj.hSpotTagsEdit.String;
                end
            end
        end
        
        function updateShowSpotMarkers(obj)
            for hViewer = obj.hChannelImageViewers
                if hViewer.Visible == "on"
                    hViewer.hSpotMarkers.Visible = obj.hShowSpotMarkersCBox.Value == 1;
                end
            end
        end
        function updateZoomOnSelectedSpot(obj)
            % TODO ...
        end
        
        function hSpots = getAllSelectedSpots(obj)
            hSpots = Spot.empty(0,1);
            if obj.hSelectAllChannelsBtn.Value
                hSpots = vertcat(obj.hExperiment.hChannels.hSpots);
            elseif obj.hSelectVisibleChannelsBtn.Value
                hVisChannels = obj.getVisibleChannels();
                if ~isempty(hVisChannels)
                    hSpots = vertcat(hVisChannels.hSpots);
                end
            elseif obj.hSelectVisibleSpotsBtn.Value
                hVisChannels = obj.getVisibleChannels();
                if ~isempty(hVisChannels)
                    hSpots = vertcat(hVisChannels.hSelectedSpot);
                end
            end
            if obj.hExperiment.applySpotSelectionTagsMask
                hSpots = Spot.getTaggedSpots(hSpots, obj.hExperiment.spotSelectionTagsMask);
            end
        end
        function zprojectSpots(obj)
            tic;
            hSpots = obj.getAllSelectedSpots();
            numSpots = numel(hSpots);
            obj.hMsgText.String = ['Z-Projecting ' num2str(numSpots) ' spots...'];
            drawnow;
            for k = 1:numSpots
                hSpots(k).updateZProjectionFromImageStack();
            end
            sec = toc;
            obj.hMsgText.String = sprintf('Done in %.1fs', sec);
            for hViewer = obj.hChannelSpotViewers
                hViewer.updateTrace();
            end
        end
        function modelSpotTraces(obj)
            tic;
            sec = toc;
            hSpots = obj.getAllSelectedSpots();
            numSpots = numel(hSpots);
            obj.hMsgText.String = ['Modeling ' num2str(numSpots) ' traces...'];
            drawnow;
            model = obj.hExperiment.tsModel;
            if model.name == "DISC"
                try
                    disc_input = initDISC();
                    if isfield(model, 'alpha')
                        disc_input.input_type = 'alpha_value';
                        disc_input.input_value = model.alpha;
                    end
                    if isfield(model, 'divInformationCriterion')
                        disc_input.divisive = model.divInformationCriterion;
                    end
                    if isfield(model, 'aggInformationCriterion')
                        disc_input.agglomerative = model.aggInformationCriterion;
                    end
                    if isfield(model, 'numViterbiIterations')
                        disc_input.viterbi = model.numViterbiIterations;
                    end
                    if 0
                        % global DISC all spots
                    else
                        % per spot DISC
                        for k = 1:numSpots
                            sec2 = toc;
                            if sec2 - sec > 30
                                obj.hMsgText.String = ['Modeling trace ' num2str(k) '/' num2str(numSpots) '...'];
                                drawnow;
                                sec = sec2;
                            end
                            [x, y, isMasked] = hSpots(k).getTimeSeriesData();
                            y(isMasked) = nan;
                            disc_fit = runDISC(y(~isMasked), disc_input);
                            hSpots(k).tsModel = model;
                            hSpots(k).tsModel.time = x;
                            hSpots(k).tsModel.data = y;
                            hSpots(k).tsModel.idealData = nan(size(y));
                            hSpots(k).tsModel.idealData(~isMasked) = disc_fit.ideal;
                        end
                    end
                catch err
                    errordlg([err.message ' Requires DISC (https://github.com/ChandaLab/DISC)'], 'DISC');
                    return
                end
            end
            sec = toc;
            obj.hMsgText.String = sprintf('Done in %.1fs', sec);
            for hViewer = obj.hChannelSpotViewers
                hViewer.updateTrace();
            end
        end
        function setTsModel(obj, name)
            obj.hExperiment.tsModel = name;
        end
        function editTsModelParams(obj)
            obj.hExperiment.editTsModelParams();
        end
        function simulateTraces(obj)
            disp('Simulating traces...');
            wb = waitbar(0, 'Simulating traces...');
            try
                [x, y, ideal] = Simulation.simulateTimeSeries();
                numChannels = size(y,3);
                numSpots = size(y,2);
                delete(obj.hExperiment.hChannels);
                obj.hExperiment.hChannels = Channel.empty(1,0);
                for c = 1:numChannels
                    hChannel = Channel();
                    obj.hExperiment.hChannels(c) = hChannel;
                    hChannel.hSpots = Spot.empty(0,1);
                    hChannel.hSpots(numSpots,1) = Spot();
                    for k = 1:numSpots
                        hChannel.hSpots(k).tsData.timeUnits = 'seconds';
                        hChannel.hSpots(k).tsData.time = diff(x(1:2));
                        hChannel.hSpots(k).tsData.data = y(:,k,c);
                        hChannel.hSpots(k).tsKnownModel.idealData = ideal(:,k,c);
                    end
                    hChannel.hSpots = hChannel.hSpots;
                end
                obj.hExperiment = obj.hExperiment;
                obj.setVisibleChannelIndices(1:numChannels);
                obj.goToSpot(1);
                disp('... Done.');
            catch err
                disp(['... Aborted: ' err.message]);
            end
            close(wb);
        end
    end
end

