classdef ChannelImageViewer < ImageStackViewer
    %CHANNELIMAGEVIEWER Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % Channel handle.
        channel = Channel();
        
        selectedSpot = Spot.empty;
        
        spotMarkers = gobjects(0);
        
        selectedSpotMarker = gobjects(0);
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
            
            obj.spotMarkers = scatter(obj.imageAxes, nan, nan, 'ro');
            obj.selectedSpotMarker = scatter(obj.imageAxes, nan, nan, 'yo');
        end
        
        function set.channel(obj, channel)
            % set handle to channel and update displayed image
            obj.channel = channel;
            if ~isempty(channel.images)
                obj.imageStack = channel.images(1);
            else
                obj.imageStack = ImageStack();
            end
            obj.updateSpotMarkers();
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
        
        function rightClickInImage(obj, x, y)
            menu = obj.getActionsMenu();
            menu.Visible = 1;
        end
        
        function selectImage(obj, idx)
            obj.imageStack = obj.channel.images(idx);
        end
        
        function loadImage(obj, varargin)
            newImage = ImageStack;
            newImage.load('', '', [], [], true);
            obj.channel.images = [obj.channel.images newImage];
            obj.imageStack = newImage;
            [~, newImage.label, ~] = fileparts(newImage.filepath);
            obj.editImageInfo();
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
        
        function menu = getActionsMenu(obj)
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
                'Callback', @obj.editImageInfo);
            
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
            
            uimenu(menu, 'Label', 'Clear Spots', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearSpots());
            
%             otherChannels = obj.getOtherChannelsInExperiment();
%             if ~isempty(otherChannels)
%                 alignToMenu = uimenu(menu, 'Label', 'Align To', ...
%                     'Separator', 'on');
%                 for channel = otherChannels
%                     alignToChannelMenu = uimenu(alignToMenu, 'Label', channel.label);
%                     uimenu(alignToChannelMenu, 'Label', 'Align Images', ...
%                 'Callback', @(varargin) obj.alignImagesTo(channel));
%                     uimenu(alignToChannelMenu, 'Label', 'Align Spots', ...
%                 'Callback', @(varargin) obj.alignSpotsTo(channel));
%                     uimenu(alignToChannelMenu, 'Label', 'Identical', ...
%                 'Callback', @(varargin) obj.alignIdenticalTo(channel)));
%                 end
%             end
            
            menu.Position(1:2) = get(fig, 'CurrentPoint');
            %menu.Visible = 1;
        end
        
        function editImageInfo(obj, varargin)
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
            if obj.imageStack.numChannels() > 1
                errordlg('Requires a grayscale intensity image.', 'Find Spots');
                return
            end
            t = obj.getCurrentFrameIndex();
            if ~t
                return
            end
            im = obj.imageStack.getFrame(t);
            if islogical(im)
                props = regionprops(im, 'all');
                fieldnames(props)
                nspots = numel(props);
                obj.channel.spots = Spot.empty;
                if nspots
                    obj.channel.spots(nspots) = Spot();
                    for k = 1:nspots
                        obj.channel.spots(k).xy = props(k).Centroid;
                        obj.channel.spots(k).props = props(k);
                    end
                end
            else
                xy = ImageOps.findMaximaPreview(im, [], [], [], [], obj.imageFrame);
                if isempty(xy)
                    obj.imageStack = obj.imageStack;
                    return
                end
                nspots = size(xy,1);
                obj.channel.spots = Spot.empty;
                if nspots
                    obj.channel.spots(nspots) = Spot();
                    for k = 1:nspots
                        obj.channel.spots(k).xy = xy(k,:);
                    end
                end
            end
            obj.selectedSpot = Spot.empty;
            obj.updateSpotMarkers();
        end
        
        function clearSpots(obj)
            obj.channel.spots = Spot.empty;
            obj.selectedSpot = Spot.empty;
            obj.updateSpotMarkers();
        end
        
        function updateSpotMarkers(obj)
            xy = vertcat(obj.channel.spots.xy);
            if isempty(xy)
                obj.spotMarkers.XData = nan;
                obj.spotMarkers.YData = nan;
            else
                obj.spotMarkers.XData = xy(:,1);
                obj.spotMarkers.YData = xy(:,2);
            end
            obj.updateSelectedSpotMarker();
        end
        
        function updateSelectedSpotMarker(obj)
            if isempty(obj.selectedSpot)
                obj.selectedSpotMarker.XData = nan;
                obj.selectedSpotMarker.YData = nan;
            else
                obj.selectedSpotMarker.XData = obj.selectedSpot.xy(1);
                obj.selectedSpotMarker.YData = obj.selectedSpot.xy(2);
            end
        end
        
%         function alignImagesTo(obj, channel)
%         end
%         
%         function alignSpotsTo(obj, channel)
%             errordlg('Aligning spots is not yet implemented. Check back soon.', 'COMING SOON');
%         end
%         
%         function alignIdenticalTo(obj, channel)
%             obj.channel.alignToChannel = channel;
%             obj.channel.alignment = ImageRegistration;
%             obj.channel.alignment.transformation = affine2d();
%         end
    end
end

