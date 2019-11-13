classdef ExperimentViewer < handle
    %EXPERIMENTVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Experiment handle.
        experiment = Experiment();
    end
    
    properties (Access = private)
        channelImageViewers = ChannelImageViewer.empty;
        
        loadDataBtn = gobjects(0);
        saveDataBtn = gobjects(0);
        refreshUiBtn = gobjects(0);
        
        channelsListHeaderText = gobjects(0);
        addChannelBtn = gobjects(0);
        removeChannelsBtn = gobjects(0);
        channelsListBox = gobjects(0);
        
        showImagesAndOrProjectionsBtnGroup = gobjects(0);
        showImagesBtn = gobjects(0);
        showProjectionsBtn = gobjects(0);
        showImagesAndProjectionsBtn = gobjects(0);
        
        resizeListener = [];
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
    end
    
    methods
        function obj = ExperimentViewer(parent)
            %EXPERIMENTVIEWER Construct an instance of this class
            %   Detailed explanation goes here
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure('units', 'normalized', 'position', [0 0 1 1]);
                parent.Units = 'pixels';
                addToolbarExplorationButtons(parent); % old style
            end
            
            obj.loadDataBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'Load', 'Callback', @(varargin) obj.loadData());
            obj.saveDataBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'Save', 'Callback', @(varargin) obj.saveData());
            obj.refreshUiBtn = uicontrol(parent, 'Style', 'pushbutton', ...
                'String', 'Refresh', 'Callback', @(varargin) obj.refreshUi());
            
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
            
            obj.resize();
            obj.updateResizeListener();
        end
        
        function set.experiment(obj, experiment)
            obj.experiment = experiment;
            nchannels = numel(experiment.channels);
            delete(obj.channelImageViewers);
            obj.channelImageViewers = ChannelImageViewer.empty;
            for c = 1:nchannels
                obj.channelImageViewers(c) = ChannelImageViewer(obj.Parent);
                obj.channelImageViewers(c).channel = experiment.channels(c);
                obj.channelImageViewers(c).removeResizeListener();
            end
            obj.updateChannelsListBox();
            obj.showChannels();
            linkaxes(horzcat(obj.channelImageViewers.imageAxes), 'xy');
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
            obj.resize();
            obj.updateResizeListener();
        end
        
        function resize(obj, varargin)
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
            obj.loadDataBtn.Position = [x0 y wc/3 lh];
            obj.saveDataBtn.Position = [x0+wc/3 y wc/3 lh];
            obj.refreshUiBtn.Position = [x0+wc*2/3 y wc/3 lh];
            y = y - margin - lh;
            obj.channelsListHeaderText.Position = [x0 y wc-2*lh lh];
            obj.addChannelBtn.Position = [x0+wc-2*lh y lh lh];
            obj.removeChannelsBtn.Position = [x0+wc-lh y lh lh];
            y = y - 75;
            obj.channelsListBox.Position = [x0 y wc 75];
            y = y - margin - lh;
            obj.showImagesAndOrProjectionsBtnGroup.Position = [x0 y wc lh];
            obj.showImagesBtn.Position = [0 0 .3*wc lh];
            obj.showProjectionsBtn.Position = [.3*wc 0 .3*wc lh];
            obj.showImagesAndProjectionsBtn.Position = [.6*wc 0 .4*wc lh];
            
            % visible channels
            nchannels = numel(obj.experiment.channels);
            vischannels = obj.getVisibleChannelIndices();
            nvischannels = numel(vischannels);
            invischannels = setdiff(1:nchannels, vischannels);
            if ~isempty(invischannels)
                [obj.channelImageViewers(invischannels).Visible] = deal(0);
            end
            if nvischannels > 0
                x = x0 + wc + margin;
                wc = w - x;
                sep = margin;
                hc = floor((h - (nvischannels - 1) * sep) / nvischannels);
                y = y0 + h - hc;
                for c = vischannels
                    obj.channelImageViewers(c).Position = [x y wc hc];
                    y = y - sep - hc;
                end
                [obj.channelImageViewers(vischannels).Visible] = deal(1);
            end
        end
        
        function updateResizeListener(obj)
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = addlistener(ancestor(obj.Parent, 'Figure'), 'SizeChanged', @obj.resize);
        end
        
        function addChannel(obj)
            obj.experiment.addChannel(Channel());
            
            civ = ChannelImageViewer(obj.Parent);
            civ.channel = obj.experiment.channels(end);
            civ.removeResizeListener();
            obj.channelImageViewers = [obj.channelImageViewers civ];
            linkaxes(horzcat(obj.channelImageViewers.imageAxes), 'xy');
            
            obj.channelsListBox.Value = [obj.channelsListBox.Value numel(obj.experiment.channels)];
            obj.updateChannelsListBox();
            
            obj.showChannels();
        end
        
        function removeChannels(obj, idx)
            if ~exist('idx', 'var')
                idx = obj.getVisibleChannelIndices();
            end
            if isempty(idx)
                return
            end
            selected = false(1, numel(obj.experiment.channels));
            selected(obj.getVisibleChannelIndices()) = true;
            selected(idx) = [];
            
            delete(obj.experiment.channels(idx));
            obj.experiment.channels(idx) = [];
            
            delete(obj.channelImageViewers(idx));
            obj.channelImageViewers(idx) = [];
            
            obj.channelsListBox.Value = find(selected);
            obj.updateChannelsListBox();
            
            obj.showChannels();
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
            idx = obj.channelsListBox.Value;
            idx(idx < 1) = [];
            idx(idx > nchannels) = [];
            obj.channelsListBox.Value = unique(idx);
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
            fig = ancestor(obj.Parent, 'Figure');
            fig.Name = strrep(file, '_', ' ');
        end
        
        function saveData(obj, filepath, maxImageStackFrames)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uiputfile('*.mat', 'Save data to file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            
            % Do NOT save image stacks with frame count exceeding maxImageStackFrames.
            if ~exist('maxImageStackFrames', 'var')
                answer = inputdlg({'Only save image stack data when frame count <='}, 'Save Large Image Stacks?', 1, {'inf'});
                if isempty(answer)
                    return
                end
                maxImageStackFrames = str2num(answer{1});
            end
            for channel = obj.experiment.channels
                for imstack = channel.images
                    if imstack.numFrames() > maxImageStackFrames
                        imstack.ownData = false;
                    else
                        imstack.ownData = true;
                    end
                end
            end
            
            wb = waitbar(0, 'Saving experiment to file...');
            experiment = obj.experiment;
            save(filepath, 'experiment', '-v7.3');
            close(wb);
            fig = ancestor(obj.Parent, 'Figure');
            fig.Name = strrep(file, '_', ' ');
        end
        
        function loadAllMissingImageStacks(obj)
            for channel = obj.experiment.channels
                for imstack = channel.images
                    if isempty(imstack.data)
                        imstack.reload();
                    end
                end
            end
        end
        
        function refreshUi(obj)
            obj.experiment = obj.experiment;
            obj.resize();
        end
    end
end

