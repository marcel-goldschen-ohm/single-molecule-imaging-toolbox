classdef ChannelImageViewer < ImageStackViewer
    %CHANNELIMAGEVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % Channel handle.
        channel = Channel();
    end
    
    properties (Access = private)
    end
    
    methods
        function obj = ChannelImageViewer(parent)
            %CHANNELIMAGEVIEWER Construct an instance of this class
            %   Detailed explanation goes here
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
            obj@ImageStackViewer(parent);
        end
        
        function set.channel(obj, channel)
            % set handle to channel and update displayed image
            obj.channel = channel;
            if ~isempty(channel.images)
                obj.imageStack = channel.images(1);
            else
                obj.imageStack = ImageStack();
            end
        end
        
        function idx = getSelectedImageIndex(obj)
            idx = 0;
            for i = 1:numel(obj.channel.images)
                if obj.imageStack == obj.channel.images(i)
                    idx = i;
                    return
                end
            end
        end
        
        function channels = getOtherChannelsInParentExperiment(obj)
            channels = [];
            if ~isempty(obj.channel.experiment)
                channels = setdiff(obj.channel.experiment.channels, obj.channel);
            end
        end
        
        function rightClickInImage(obj, x, y)
            fig = ancestor(obj.Parent, 'Figure');
            menu = uicontextmenu(fig);
            
            uimenu(menu, 'Label', 'Load', ...
                'Callback', @obj.loadImage);
            
            selectedImageIndex = obj.getSelectedImageIndex();
            selectImageMenu = uimenu(menu, 'Label', 'Select', ...
                'Separator', 'on');
            for i = 1:numel(obj.channel.images)
                uimenu(selectImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Checked', i == selectedImageIndex, ...
                    'Callback', @(varargin) obj.selectImage(i));
            end
            
            uimenu(menu, 'Label', 'Edit Info', ...
                'Separator', 'on', ...
                'Callback', @obj.editSelectedImageInfo);
            
            removeImageMenu = uimenu(menu, 'Label', 'Remove', ...
                'Separator', 'on');
            for i = 1:numel(obj.channel.images)
                uimenu(removeImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Checked', i == selectedImageIndex, ...
                    'Callback', @(varargin) obj.removeImage(i, true));
            end
            
            uimenu(menu, 'Label', 'Autoscale', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            
            uimenu(menu, 'Label', 'Duplicate', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.duplicate());
            
            if obj.imageStack.numFrames() > 1
                uimenu(menu, 'Label', 'Z-Project', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.zproject());
            end
            
            filterMenu = uimenu(menu, 'Label', 'Filter', ...
                'Separator', 'on');
            uimenu(filterMenu, 'Label', 'Gaussian', ...
                    'Callback', @(varargin) obj.gaussFilter());
            uimenu(filterMenu, 'Label', 'Tophat', ...
                    'Callback', @(varargin) obj.tophatFilter());
            
            uimenu(menu, 'Label', 'Threshold', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.threshold());
            
            uimenu(menu, 'Label', 'Find Spots', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.findSpots());
            
            otherChannels = obj.getOtherChannelsInParentExperiment();
            if ~isempty(otherChannels)
                alignToMenu = uimenu(menu, 'Label', 'Align To', ...
                    'Separator', 'on');
                for channel = otherChannels
                    alignToChannelMenu = uimenu(alignToMenu, 'Label', channel.label);
                    uimenu(alignToChannelMenu, 'Label', 'Align Images');
                    uimenu(alignToChannelMenu, 'Label', 'Align Spots');
                    uimenu(alignToChannelMenu, 'Label', 'Identity');
                end
            end
            
            menu.Position(1:2) = get(fig, 'CurrentPoint');
            menu.Visible = 1;
        end
        
        function selectImage(obj, idx)
            obj.imageStack = obj.channel.images(idx);
        end
        
        function editSelectedImageInfo(obj, varargin)
            if ~obj.getSelectedImageIndex()
                return
            end
            answer = inputdlg( ...
                {'label'}, ...
                'Image Info', 1, ...
                {char(obj.imageStack.label)});
            if isempty(answer)
                return
            end
            obj.imageStack.label = string(answer{1});
            obj.updateInfoText();
        end
        
        function loadImage(obj, varargin)
            newImage = ImageStack;
            newImage.load('', '', [], [], true);
            obj.channel.images = [obj.channel.images newImage];
            obj.imageStack = newImage;
            [~, newImage.label, ~] = fileparts(newImage.filepath);
            obj.editSelectedImageInfo();
        end
        
        function removeImage(obj, idx, ask)
            if exist('ask', 'var') && ask
                if questdlg(['Remove image ' char(obj.channel.images(idx).label) '?'], ...
                        'Remove image?', ...
                        'OK', 'Cancel', 'Cancel') == "Cancel"
                    return
                end
            end
            delete(obj.channel.images(idx));
            obj.channel.images(idx) = [];
            if isempty(obj.channel.images)
                obj.imageStack = ImageStack;
            else
                obj.imageStack = obj.channel.images(min(idx, numel(obj.channel.images)));
            end
        end
        
        function duplicate(obj, frames)
            if ~exist('frames', 'var')
                frames = [];
            end
            try
                newImage = obj.imageStack.duplicate(frames);
                if ~isempty(newImage.data)
                    obj.channel.images = [obj.channel.images newImage];
                    obj.imageStack = newImage;
                end
            catch
            end
%             if isempty(obj.imageStack.data)
%                 errordlg('Requires an image.', 'Duplicate');
%                 return
%             end
%             nframes = obj.imageStack.numFrames();
%             if nframes > 1
%                 ok = true;
%                 if ~exist('frames', 'var') || isempty(frames)
%                     frames = 1:nframes;
%                     d = dialog('Name', 'Duplicate');
%                     d.Position(3) = 200;
%                     d.Position(4) = 50;
%                     uicontrol(d, 'Style', 'text', 'String', 'Frames', ...
%                         'Units', 'normalized', 'Position', [0, 0.6, 0.5, 0.4]);
%                     uicontrol(d, 'Style', 'edit', 'String', [ num2str(frames(1)) '-' num2str(frames(end))], ...
%                         'Units', 'normalized', 'Position', [0.5, 0.6, 0.5, 0.4], ...
%                         'Callback', @setFrames_);
%                     uicontrol(d, 'Style', 'pushbutton', 'String', 'OK', ...
%                         'Units', 'normalized', 'Position', [0.1, 0, 0.4, 0.6], ...
%                         'Callback', @ok_);
%                     uicontrol(d, 'Style', 'pushbutton', 'String', 'Cancel', ...
%                         'Units', 'normalized', 'Position', [0.5, 0, 0.4, 0.6], ...
%                         'Callback', 'delete(gcf)');
%                     ok = false;
%                     uiwait(d);
%                 end
%                 if ~ok
%                     return
%                 end
%             elseif nframes == 1
%                 frames = 1;
%             end
%             function setFrames_(edit, varargin)
%                 firstlast = split(edit.String, '-');
%                 first = str2num(firstlast{1});
%                 if numel(firstlast) == 2
%                     last = str2num(firstlast{2});
%                     frames = max(1, first):min(last, nframes);
%                 else
%                     frames = first;
%                 end
%             end
%             function ok_(varargin)
%                 ok = true;
%                 delete(d);
%             end
%             try
%                 newImage = ImageStack;
%                 newImage.data = obj.imageStack.data(:,:,:,frames);
%                 if numel(frames) > 1
%                     newImage.label = string(sprintf('%s %d-%d', obj.imageStack.label, frames(1), frames(end)));
%                 else
%                     newImage.label = string(sprintf('%s %d', obj.imageStack.label, frames));
%                 end
%                 obj.channel.images = [obj.channel.images newImage];
%                 obj.imageStack = newImage;
%             catch
%             end
        end
        
        function zproject(obj, frames, method)
            if ~exist('frames', 'var')
                frames = [];
            end
            if ~exist('method', 'var')
                method = '';
            end
            try
                newImage = obj.imageStack.zproject(frames, method, obj.imageFrame);
                if ~isempty(newImage.data)
                    obj.channel.images = [obj.channel.images newImage];
                    obj.imageStack = newImage;
                else
                    obj.imageStack = obj.imageStack;
                end
            catch
                obj.imageStack = obj.imageStack;
            end
        end
        
        function gaussFilter(obj, sigma, applyToAllFrames)
            if ~exist('sigma', 'var')
                sigma = [];
            end
            if ~exist('applyToAllFrames', 'var')
                applyToAllFrames = [];
            end
            try
                nframes = obj.imageStack.numFrames();
                if nframes > 1
                    frame = max(1, min(obj.frameSlider.Value, nframes));
                else
                    frame = 1;
                end
                obj.imageStack.gaussFilter(frame, sigma, obj.imageFrame, applyToAllFrames);
            catch
            end
            obj.imageStack = obj.imageStack;
        end
        
        function tophatFilter(obj, diskRadius, applyToAllFrames)
            if ~exist('diskRadius', 'var')
                diskRadius = [];
            end
            if ~exist('applyToAllFrames', 'var')
                applyToAllFrames = [];
            end
            try
                nframes = obj.imageStack.numFrames();
                if nframes > 1
                    frame = max(1, min(obj.frameSlider.Value, nframes));
                else
                    frame = 1;
                end
                obj.imageStack.tophatFilter(frame, diskRadius, obj.imageFrame, applyToAllFrames);
            catch
            end
            obj.imageStack = obj.imageStack;
        end
        
        function threshold(obj, threshold)
            if ~exist('threshold', 'var')
                threshold = [];
            end
            try
                nframes = obj.imageStack.numFrames();
                if nframes > 1
                    frame = max(1, min(obj.frameSlider.Value, nframes));
                else
                    frame = 1;
                end
                newImage = obj.imageStack.threshold(frame, threshold, obj.imageFrame);
                if ~isempty(newImage.data)
                    obj.channel.images = [obj.channel.images newImage];
                    obj.imageStack = newImage;
                else
                    obj.imageStack = obj.imageStack;
                end
            catch
                obj.imageStack = obj.imageStack;
            end
        end
        
        function findSpots(obj)
        end
    end
end

