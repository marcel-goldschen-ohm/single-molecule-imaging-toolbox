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
        
        menuButton = gobjects(0);
        zoomOutButton = gobjects(0);
        
        experimentViewer = ExperimentViewer.empty;
        
        imageStackChangedListener = [];
        frameChangedListener = [];
    end
    
    events
        SelectedSpotChanged
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
            
            obj.menuButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', '=', 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.menuButtonPushed());
            
            obj.zoomOutButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', 'A', 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            
            obj.leftHeaderButtons = obj.menuButton;
            obj.rightHeaderButtons = obj.zoomOutButton;
            
            obj.spotMarkers = scatter(obj.imageAxes, nan, nan, 'mo', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.selectedSpotMarker = scatter(obj.imageAxes, nan, nan, 'co', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.selectedSpotMarker.MarkerHandle.LineWidth = 2;
            
            obj.imageStackChangedListener = ...
                addlistener(obj, 'ImageStackChanged', @(varargin) obj.onImageStackChanged());
            obj.frameChangedListener = ...
                addlistener(obj, 'FrameChanged', @(varargin) obj.onFrameChanged());
            
            obj.resize();
        end
        
        function delete(obj)
            h = [ ...
                obj.spotMarkers ...
                obj.selectedSpotMarker ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function set.channel(obj, channel)
            % set handle to channel and update displayed image
            obj.channel = channel;
            obj.imageAxes.YLabel.String = channel.label;
            if ~isempty(channel.images)
                if ~isempty(channel.selectedImage) && any(channel.images == channel.selectedImage)
                    obj.imageStack = channel.selectedImage;
                else
                    obj.imageStack = channel.images(1);
                end
            else
                obj.imageStack = ImageStack();
            end
            obj.updateSpotMarkers();
        end
        
        function set.selectedSpot(obj, spot)
            obj.selectedSpot = spot;
            obj.updateSelectedSpotMarker();
            notify(obj, 'SelectedSpotChanged');
        end
        
        function onImageStackChanged(obj)
            if any(obj.channel.images == obj.imageStack)
                obj.channel.selectedImage = obj.imageStack;
            else
                obj.channel.selectedImage = ImageStack.empty;
            end
        end
        
        function onFrameChanged(obj)
            if ~isempty(obj.experimentViewer)
                otherChannelImageViewers = setdiff(obj.experimentViewer.channelImageViewers, obj);
                for viewer = otherChannelImageViewers
                    if ~isempty(viewer.overlayImageStackViewer) && viewer.overlayImageStackViewer == obj
                        viewer.showFrame();
                    end
                end
            end
        end
        
        function menuButtonPushed(obj)
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
            
            uimenu(menu, 'Label', 'Rename Channel', ...
                'Callback', @obj.renameChannel);
            
            uimenu(menu, 'Label', 'Load Image', ...
                'Separator', 'on', ...
                'Callback', @obj.loadImage);
            
            if isempty(obj.channel.images)
                return
            end
            
            uimenu(menu, 'Label', 'Reload Image', ...
                'Callback', @obj.reloadImage);
            
            nimages = numel(obj.channel.images);
            selectedImageIndex = obj.getSelectedImageIndex();
            if nimages > 1
                selectImageMenu = uimenu(menu, 'Label', 'Select Image');
                for i = 1:nimages
                    uimenu(selectImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                        'Checked', i == selectedImageIndex, ...
                        'Callback', @(varargin) obj.selectImage(i));
                end
            end
            
            uimenu(menu, 'Label', 'Rename Image', ...
                'Callback', @obj.renameImage);
            
            removeImageMenu = uimenu(menu, 'Label', 'Remove Image');
            for i = 1:nimages
                uimenu(removeImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Checked', i == selectedImageIndex, ...
                    'Callback', @(varargin) obj.removeImage(i, true));
            end
            
            otherChannels = obj.channel.getOtherChannelsInExperiment();
            if ~isempty(otherChannels)
                overlayMenu = uimenu(menu, 'Label', 'Overlay Channel', ...
                    'Separator', 'on');
                uimenu(overlayMenu, 'Label', 'None', ...
                    'Checked', isempty(obj.overlayImageStackViewer), ...
                    'Callback', @(varargin) obj.setOverlayChannel(Channel.empty));
                for channel = otherChannels
                    uimenu(overlayMenu, 'Label', channel.label, ...
                        'Checked', ~isempty(obj.overlayImageStackViewer) ...
                        && (obj.overlayImageStackViewer.channel == channel), ...
                        'Callback', @(varargin) obj.setOverlayChannel(channel));
                end
                overlayColorsMenu = uimenu(overlayMenu, 'Label', 'Overlay Colors', ...
                    'Separator', 'on');
                uimenu(overlayColorsMenu, 'Label', 'green-magenta', ...
                    'Checked', (~isnumeric(obj.overlayColorChannels) ...
                    && obj.overlayColorChannels == "green-magenta") ...
                    || isequal(obj.overlayColorChannels, [2 1 2]), ...
                    'Callback', @(varargin) obj.setOverlayColorChannels('green-magenta'));
                uimenu(overlayColorsMenu, 'Label', 'magenta-green', ...
                    'Checked', isequal(obj.overlayColorChannels, [1 2 1]), ...
                    'Callback', @(varargin) obj.setOverlayColorChannels([1 2 1]));
                uimenu(overlayColorsMenu, 'Label', 'red-cyan', ...
                    'Checked', (~isnumeric(obj.overlayColorChannels) ...
                    && obj.overlayColorChannels == "red-cyan") ...
                    || isequal(obj.overlayColorChannels, [1 2 2]), ...
                    'Callback', @(varargin) obj.setOverlayColorChannels('red-cyan'));
                uimenu(overlayColorsMenu, 'Label', 'cyan-red', ...
                    'Checked', isequal(obj.overlayColorChannels, [2 1 1]), ...
                    'Callback', @(varargin) obj.setOverlayColorChannels([2 1 1]));
                uimenu(overlayColorsMenu, 'Label', 'green-red', ...
                    'Checked', isequal(obj.overlayColorChannels, [2 1 0]), ...
                    'Callback', @(varargin) obj.setOverlayColorChannels([2 1 0]));
                uimenu(overlayColorsMenu, 'Label', 'red-green', ...
                    'Checked', isequal(obj.overlayColorChannels, [1 2 0]), ...
                    'Callback', @(varargin) obj.setOverlayColorChannels([1 2 0]));
            end
            
            uimenu(menu, 'Label', 'Autoscale', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            
            uimenu(menu, 'Label', 'Duplicate', ...
                'Callback', @(varargin) obj.duplicate());
            
            if obj.imageStack.numFrames() > 1
                uimenu(menu, 'Label', 'Z-Project', ...
                    'Callback', @(varargin) obj.zproject());
            end
            
            filterMenu = uimenu(menu, 'Label', 'Filter');
            uimenu(filterMenu, 'Label', 'Gaussian', ...
                    'Callback', @(varargin) obj.gaussFilter());
            uimenu(filterMenu, 'Label', 'Tophat', ...
                    'Callback', @(varargin) obj.tophatFilter());
            
            uimenu(menu, 'Label', 'Threshold', ...
                'Callback', @(varargin) obj.threshold());
            
            if ~isempty(otherChannels)
                alignToMenu = uimenu(menu, 'Label', 'Align To Channel', ...
                    'Separator', 'on');
                uimenu(alignToMenu, 'Label', 'None', ...
                    'Checked', isempty(obj.channel.alignedToChannel), ...
                    'Callback', @(varargin) obj.alignToChannel(Channel.empty));
                for channel = otherChannels
                    uimenu(alignToMenu, 'Label', channel.label, ...
                        'Checked', ~isempty(obj.channel.alignedToChannel) && (obj.channel.alignedToChannel == channel), ...
                        'Callback', @(varargin) obj.alignToChannel(channel));
                end
            end
            
            uimenu(menu, 'Label', 'Find Spots', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.findSpots());
            
            uimenu(menu, 'Label', 'Clear Spots', ...
                'Callback', @(varargin) obj.clearSpots());
        end
        
        function leftClickInImage(obj, x, y)
            spotIdx = obj.selectSpot(x, y);
            if spotIdx
                obj.selectedSpot = obj.channel.spots(spotIdx);
            else
                clickSpot = Spot;
                clickSpot.xy = [x y];
                obj.selectedSpot = clickSpot;
            end
            obj.updateSelectedSpotMarker();
        end
        
        function rightClickInImage(obj, x, y)
            menu = obj.getActionsMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = get(fig, 'CurrentPoint');
            
            spotIdx = obj.selectSpot(x, y);
            if spotIdx
                uimenu(menu, 'Label', 'Remove Spot', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.removeSpot(spotIdx));
            else
                uimenu(menu, 'Label', 'Add Spot', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.addSpot([x y]));
            end
            
            menu.Visible = 1;
        end
        
        function idx = selectSpot(obj, x, y)
            idx = [];
            if ~isempty(obj.channel.spots)
                xy = vertcat(obj.channel.spots.xy);
                nspots = numel(obj.channel.spots);
                d = sqrt(sum((xy - repmat([x y], [nspots 1])).^2, 2));
                [d, idx] = min(d);
                ax = obj.imageAxes;
                tmpUnits = ax.Units;
                ax.Units = 'pixels';
                pos = ax.Position;
                ax.Units = tmpUnits;
                dxdy = obj.channel.spots(idx).xy - [x y];
                dxdypix = dxdy ./ [diff(ax.XLim) diff(ax.YLim)] .* pos(3:4);
                dpix = sqrt(sum(dxdypix.^2));
                if dpix > 5
                    idx = [];
                end
            end
        end
        
        function renameChannel(obj, varargin)
            if isempty(obj.channel)
                return
            end
            answer = inputdlg( ...
                {'label'}, ...
                'Channel Label', 1, ...
                {char(obj.channel.label)});
            if isempty(answer)
                return
            end
            obj.channel.label = string(answer{1});
            obj.imageAxes.YLabel.String = obj.channel.label;
            obj.resize();
            if ~isempty(obj.experimentViewer)
                obj.experimentViewer.refreshUi();
            end
        end
        
        function loadImage(obj, varargin)
            newImage = ImageStack;
            newImage.load('', '', [], [], true);
            obj.channel.images = [obj.channel.images newImage];
            obj.imageStack = newImage;
            [~, newImage.label, ~] = fileparts(newImage.filepath);
            obj.editImageInfo();
        end
        
        function reloadImage(obj, varargin)
            obj.imageStack.reload();
            obj.imageStack = obj.imageStack;
        end
        
        function selectImage(obj, idx)
            obj.imageStack = obj.channel.images(idx);
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
        
        function renameImage(obj, varargin)
            if ~obj.getSelectedImageIndex()
                return
            end
            answer = inputdlg( ...
                {'label'}, ...
                'Image Label', 1, ...
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
                    obj.channel.spots(nspots,1) = Spot();
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
                    obj.channel.spots(nspots,1) = Spot();
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
        
        function addSpot(obj, xy)
            newSpot = Spot;
            newSpot.xy = xy;
            obj.channel.spots = [obj.channel.spots; newSpot];
            obj.updateSpotMarkers();
            obj.selectedSpot = newSpot;
        end
        
        function removeSpot(obj, idx)
            if obj.selectedSpot == obj.channel.spots(idx)
                obj.selectedSpot = Spot.empty;
            end
            obj.channel.spots(idx) = [];
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
        
        function setOverlayChannel(obj, channel)
            if ~isempty(channel) && ~isempty(obj.experimentViewer)
                c = find(obj.experimentViewer.experiment.channels == channel);
                if ~isempty(c)
                    obj.overlayImageStackViewer = obj.experimentViewer.channelImageViewers(c);
                    return
                end
            end
            obj.overlayImageStackViewer = ChannelImageViewer.empty;
        end
        
        function alignToChannel(obj, channel)
            obj.channel.alignToChannel(channel);
        end
    end
end

