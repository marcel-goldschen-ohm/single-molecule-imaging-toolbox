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
            if ~isempty(obj.channel.parentExperiment)
                channels = setdiff(obj.channel.parentExperiment.channels, obj.channel);
            end
        end
        
        function rightClickInImage(obj, x, y)
            fig = ancestor(obj.Parent, 'Figure');
            menu = uicontextmenu(fig);
            
            otherChannels = obj.getOtherChannelsInParentExperiment();
            
            selectedImageIndex = obj.getSelectedImageIndex();
            selectImageMenu = uimenu(menu, 'Label', 'Select Image');
            for i = 1:numel(obj.channel.images)
                uimenu(selectImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Checked', i == selectedImageIndex, ...
                    'Callback', @(varargin) obj.selectImage(i));
            end
            
            uimenu(menu, 'Label', 'Edit Image Label', ...
                'Separator', 'on', ...
                'Callback', @obj.editSelectedImageLabel);
            
            uimenu(menu, 'Label', 'Load Image', ...
                'Separator', 'on', ...
                'Callback', @obj.loadImage);
            
            removeImageMenu = uimenu(menu, 'Label', 'Remove Image', ...
                'Separator', 'on');
            for i = 1:numel(obj.channel.images)
                uimenu(removeImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Callback', @(varargin) obj.removeImage(i, true));
            end
            
            uimenu(menu, 'Label', 'Zoom Out Full Image', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            
            imageOpsMenu = uimenu(menu, 'Label', 'Image Operations');
            uimenu(imageOpsMenu, 'Label', 'Duplicate Image', ...
                'Callback', @(varargin) obj.duplicateSelectedImage());
            
            menu.Position(1:2) = get(fig, 'CurrentPoint');
            menu.Visible = 1;
        end
        
        function selectImage(obj, idx)
            obj.imageStack = obj.channel.images(idx);
        end
        
        function editSelectedImageLabel(obj, varargin)
            if ~obj.getSelectedImageIndex()
                return
            end
            answer = inputdlg( ...
                {char(obj.imageStack.label)}, ...
                'Image Label', 1, ...
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
            obj.channel.images = [obj.channel.images; newImage];
            obj.imageStack = newImage;
            [~, newImage.label, ~] = fileparts(newImage.filepath);
            obj.editSelectedImageLabel();
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
        
        function duplicateSelectedImage(obj, frames)
            if isempty(obj.imageStack.data)
                errordlg('Requires an image.', 'Duplicate');
                return
            end
            nframes = obj.imageStack.numFrames();
            if nframes > 1
                ok = true;
                if ~exist('frames', 'var') || isempty(frames)
                    frames = 1:nframes;
                    d = dialog('Name', 'Duplicate');
                    d.Position(3) = 200;
                    d.Position(4) = 50;
                    uicontrol(d, 'Style', 'text', 'String', 'Frames', ...
                        'Units', 'normalized', 'Position', [0, 0.6, 0.5, 0.4]);
                    uicontrol(d, 'Style', 'edit', 'String', [ num2str(frames(1)) '-' num2str(frames(end))], ...
                        'Units', 'normalized', 'Position', [0.5, 0.6, 0.5, 0.4], ...
                        'Callback', @setFrames_);
                    uicontrol(d, 'Style', 'pushbutton', 'String', 'OK', ...
                        'Units', 'normalized', 'Position', [0.1, 0, 0.4, 0.6], ...
                        'Callback', @ok_);
                    uicontrol(d, 'Style', 'pushbutton', 'String', 'Cancel', ...
                        'Units', 'normalized', 'Position', [0.5, 0, 0.4, 0.6], ...
                        'Callback', 'delete(gcf)');
                    ok = false;
                    uiwait(d);
                end
                if ~ok
                    return
                end
            end
            function setFrames_(edit, varargin)
                firstlast = split(edit.String, '-');
                first = str2num(firstlast{1});
                if numel(firstlast) == 2
                    last = str2num(firstlast{2});
                    frames = max(1, first):min(last, nframes);
                else
                    frames = first;
                end
            end
            function ok_(varargin)
                ok = true;
                delete(d);
            end
            try
                newImage = ImageStack;
                newImage.data = obj.imageStack.data(:,:,:,frames);
                if numel(frames) > 1
                    newImage.label = string(sprintf('%s %d-%d', obj.imageStack.label, frames(1), frames(end)));
                else
                    newImage.label = string(sprintf('%s %d', obj.imageStack.label, frames));
                end
                obj.channel.images = [obj.channel.images; newImage];
                obj.imageStack = newImage;
            catch
            end
        end
    end
end

