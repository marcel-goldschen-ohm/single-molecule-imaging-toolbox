classdef ChannelImageViewer < ImageStackViewer
    %CHANNELIMAGEVIEWER Image stack viewer for a channel.
    %   I/O for the channel's list of image stacks.
    %   Select amongst the channel's list of image stacks.
    %   Apply various image operations, possibly adding new images to the
    %   channel's list of images.
    %   Find spots, select spots by clicking on them.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % Channel handle.
        channel = Channel;
        
        % Markers indicating the position of the channel's spots.
        spotMarkers = gobjects(0);
        
        % Marker indicating the position of the selcted spot.
        selectedSpotMarker = gobjects(0);
        
        % Drop down menu button (menu is also available via right click in
        % the image axes).
        menuButton = gobjects(0);
        
        % Zoom to show full image button.
        zoomOutButton = gobjects(0);
        
        % Brightness/Contrast button.
        brightnessContrastButton = gobjects(0);
        
        % Handle to viewer for channel's parent experiment.
        experimentViewer = ExperimentViewer.empty;
        
        % Handle to viewer whose image should be overlaid on this viewer.
        overlayChannelImageViewer = ChannelImageViewer.empty;
        
        % Overlay color scheme.
        overlayColorChannels = 'green-magenta';
    end
    
    properties (Access = private)
        channelLabelChangedListener = event.listener.empty;
        imageStackChangedListener = event.listener.empty;
        frameChangedListener = event.listener.empty;
        selectedImageChangedListener = event.listener.empty;
        spotsChangedListener = event.listener.empty;
        selectedSpotChangedListener = event.listener.empty;
    end
    
    methods
        function obj = ChannelImageViewer(parent)
            %CHANNELIMAGEVIEWER Constructor.
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
            % ImageStackViewer constructor.
            obj@ImageStackViewer(parent);
            
            % change info text to a pushbutton
            if isgraphics(obj.infoText)
                delete(obj.infoText);
            end
            obj.infoText = uicontrol(parent, 'Style', 'pushbutton', ...
                'Callback', @(varargin) obj.infoTextPressed());
            
            obj.menuButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.menuButtonPressed());
            
            obj.zoomOutButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            
            obj.brightnessContrastButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('25d0')), 'Position', [0 0 15 15], ...
                'Callback', @(varargin) obj.editBrightnessContrast());
            
            obj.leftHeaderButtons = obj.menuButton;
            obj.rightHeaderButtons = [obj.brightnessContrastButton obj.zoomOutButton];
            
            obj.spotMarkers = scatter(obj.imageAxes, nan, nan, 'mo', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.selectedSpotMarker = scatter(obj.imageAxes, nan, nan, 'co', ...
                'LineWidth', 2, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            obj.imageStackChangedListener = ...
                addlistener(obj, 'ImageStackChanged', @(varargin) obj.onImageStackChanged());
            obj.frameChangedListener = ...
                addlistener(obj, 'FrameChanged', @(varargin) obj.onFrameChanged());
            
            obj.resize();
        end
        
        function delete(obj)
            %DELETE Delete all graphics object properties.
            h = [ ...
                obj.spotMarkers ...
                obj.selectedSpotMarker ...
                obj.menuButton ...
                obj.zoomOutButton ...
                obj.brightnessContrastButton ...
                obj.selectedSpotMarker ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function set.channel(obj, channel)
            % set handle to channel and update displayed image
            obj.channel = channel;
            obj.imageAxes.YLabel.String = channel.label;
            % show selected image frame
            if channel.selectedImageFrameIndex
                obj.frameSlider.Value = channel.selectedImageFrameIndex;
            end
            if ~isempty(channel.selectedImage) && any(channel.images == channel.selectedImage)
                obj.imageStack = channel.selectedImage;
            elseif ~isempty(channel.images)
                obj.imageStack = channel.images(1);
            else
                obj.imageStack = ImageStack;
            end
            % update spots
            obj.updateSpotMarkers();
            obj.updateSelectedSpotMarker();
            % update listeners
            if ~isempty(obj.channelLabelChangedListener)
                delete(obj.channelLabelChangedListener);
            end
            obj.channelLabelChangedListener = ...
                addlistener(obj.channel, 'LabelChanged', @(varargin) obj.onChannelLabelChanged());
            if ~isempty(obj.selectedImageChangedListener)
                delete(obj.selectedImageChangedListener);
            end
            obj.selectedImageChangedListener = ...
                addlistener(obj.channel, 'SelectedImageChanged', @(varargin) obj.onSelectedImageChanged());
            if ~isempty(obj.spotsChangedListener)
                delete(obj.spotsChangedListener);
            end
            obj.spotsChangedListener = ...
                addlistener(obj.channel, 'SpotsChanged', @(varargin) obj.updateSpotMarkers());
            if ~isempty(obj.selectedSpotChangedListener)
                delete(obj.selectedSpotChangedListener);
            end
            obj.selectedSpotChangedListener = ...
                addlistener(obj.channel, 'SelectedSpotChanged', @(varargin) obj.updateSelectedSpotMarker());
        end
        
        function set.overlayChannelImageViewer(obj, viewer)
            obj.overlayChannelImageViewer = viewer;
            obj.showFrame();
        end
        
        function set.overlayColorChannels(obj, colors)
            obj.overlayColorChannels = colors;
            obj.showFrame();
        end
        
        function setOverlayColorChannels(obj, colors)
            % Only needed because setters aren't valid callbacks.
            obj.overlayColorChannels = colors;
        end
        
        function onChannelLabelChanged(obj)
            obj.imageAxes.YLabel.String = obj.channel.label;
            obj.resize();
%             if ~isempty(obj.experimentViewer)
%                 obj.experimentViewer.refreshUi();
%             end
        end
        
        function onImageStackChanged(obj)
            %ONIMAGESTACKCHANGED Handle image stack changed event.
            obj.channel.selectedImage = obj.imageStack;
        end
        
        function onFrameChanged(obj)
            %ONFRAMECHANGED Handle frame changed event.
            obj.channel.selectedImageFrameIndex = obj.getCurrentFrameIndex();
            obj.updateOtherViewersOverlaidWithThisViewer();
        end
        
        function onSelectedImageChanged(obj)
            obj.imageStack = obj.channel.selectedImage;
            obj.updateOtherViewersOverlaidWithThisViewer();
        end
        
        function updateOtherViewersOverlaidWithThisViewer(obj)
            if ~isempty(obj.experimentViewer)
                otherChannelImageViewers = setdiff(obj.experimentViewer.channelImageViewers, obj);
                for viewer = otherChannelImageViewers
                    if ~isempty(viewer.overlayChannelImageViewer) && viewer.overlayChannelImageViewer == obj
                        viewer.showFrame();
                    end
                end
            end
        end
        
        function showFrame(obj, t)
            %SHOWFRAME Display frame t.
            if ~exist('t', 'var')
                t = obj.getCurrentFrameIndex();
            end
            if isempty(obj.overlayChannelImageViewer)
                % show frame as ususal
                obj.showFrame@ImageStackViewer(t);
                return
            end
            % if we got here we have an overlay
            try
                I1 = obj.imageStack.getFrameData(t);
                I2 = obj.overlayChannelImageViewer.getFrameData();
                % only overlay grayscale images
                if size(I1,3) ~= 1 || size(I2,3) ~= 1
                    throw MException('', '');
                end
                I1 = imadjust(uint16(I1));
                I2 = imadjust(uint16(I2));
                I2 = obj.channel.getAlignedImageInLocalCoords(obj.overlayChannelImageViewer.channel, I2);
                % show overlaid images
                obj.imageFrame.CData = imfuse(I1, I2, 'ColorChannels', obj.overlayColorChannels);
                if isempty(obj.imageFrame.CData)
                    obj.imageFrame.XData = [];
                    obj.imageFrame.YData = [];
                else
                    w = size(obj.imageFrame.CData,2);
                    h = size(obj.imageFrame.CData,1);
                    obj.imageFrame.XData = [1 w];
                    obj.imageFrame.YData = [1 h];
                    if obj.imageStack.numFrames() > 1
                        obj.frameSlider.Value = t;
                        notify(obj, 'FrameChanged');
                    end
                end
                obj.updateInfoText();
            catch
                % show frame as ususal
                obj.showFrame@ImageStackViewer(t);
            end
        end
        
        function menuButtonPressed(obj)
            %MENUBUTTONPRESSED Handle menu button press.
            menu = obj.getActionsMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.menuButton.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getActionsMenu(obj)
            %GETACTIONSMENU Return menu with channel image actions.
            menu = uicontextmenu;
            
            if isempty(obj.channel)
                return
            end
            
            uimenu(menu, 'Label', 'Rename Channel', ...
                'Callback', @(varargin) obj.channel.editLabel());
            
            nimages = numel(obj.channel.images);
            if nimages > 1
                selectImageMenu = uimenu(menu, 'Label', 'Select Image', ...
                    'Separator', 'on');
                for image = obj.channel.images
                    uimenu(selectImageMenu, 'Label', image.getLabelWithSizeInfo(), ...
                        'Checked', isequal(image, obj.channel.selectedImage), ...
                        'Callback', @(varargin) obj.channel.setSelectedImage(image));
                end
            end
            
            uimenu(menu, 'Label', 'Load Image', ...
                'Separator', nimages <= 1, ...
                'Callback', @obj.loadImage);
            
            if isempty(obj.channel.images)
                return
            end
            
            uimenu(menu, 'Label', 'Reload Image', ...
                'Callback', @obj.reloadImage);
            
            uimenu(menu, 'Label', 'Rename Image', ...
                'Callback', @obj.renameImage);
            
            removeImageMenu = uimenu(menu, 'Label', 'Remove Image');
            for i = 1:nimages
                uimenu(removeImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Checked', isequal(obj.channel.images(i), obj.channel.selectedImage), ...
                    'Callback', @(varargin) obj.removeImage(i, true));
            end
            
            otherChannels = obj.channel.getOtherChannelsInParentExperiment();
            if ~isempty(otherChannels)
                overlayMenu = uimenu(menu, 'Label', 'Overlay Channel', ...
                    'Separator', 'on');
                uimenu(overlayMenu, 'Label', 'None', ...
                    'Checked', isempty(obj.overlayChannelImageViewer), ...
                    'Callback', @(varargin) obj.setOverlayChannel(Channel.empty));
                for channel = otherChannels
                    uimenu(overlayMenu, 'Label', channel.label, ...
                        'Checked', ~isempty(obj.overlayChannelImageViewer) ...
                        && (obj.overlayChannelImageViewer.channel == channel), ...
                        'Callback', @(varargin) obj.setOverlayChannel(channel));
                end
                overlayColorsMenu = uimenu(menu, 'Label', 'Overlay Colors');
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
                    'Checked', isempty(obj.channel.alignedTo.channel), ...
                    'Callback', @(varargin) obj.channel.alignToChannel(Channel.empty));
                for channel = otherChannels
                    uimenu(alignToMenu, 'Label', channel.label, ...
                        'Checked', ~isempty(obj.channel.alignedTo.channel) && (obj.channel.alignedTo.channel == channel), ...
                        'Callback', @(varargin) obj.channel.alignToChannel(channel));
                end
            end
            
            uimenu(menu, 'Label', 'Find Spots', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.findSpots());
            
            uimenu(menu, 'Label', 'Copy Aligned Spots to all Channels', ...
                'Callback', @(varargin) obj.channel.copyAlignedSpotsToAllOtherChannels());
            
            uimenu(menu, 'Label', 'Clear Spots', ...
                'Callback', @(varargin) obj.clearSpots());
        end
        
        function infoTextPressed(obj)
            %INFOTEXTPRESSED Handle button press in info text area.
            if numel(obj.channel.images) <= 1
                return
            end
            menu = obj.getImageSelectionMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.infoText.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getImageSelectionMenu(obj)
            %GETIMAGESELECTIONMENU Return menu for channel image selection.
            menu = uicontextmenu;
            
            if isempty(obj.channel)
                return
            end
            
            for image = obj.channel.images
                uimenu(menu, 'Label', image.getLabelWithSizeInfo(), ...
                    'Checked', isequal(image, obj.channel.selectedImage), ...
                    'Callback', @(varargin) obj.channel.setSelectedImage(image));
            end
        end
        
        function imageAxesButtonDown(obj, src, event)
            %IMAGEAXESBUTTONDOWN Handle button press in image axes.
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            if event.Button == 1 % left
                % select spot
                idx = obj.spotIndexAt(x, y);
                if idx
                    obj.channel.selectedSpot = obj.channel.spots(idx);
                else
                    clickSpot = Spot;
                    clickSpot.xy = [x y];
                    obj.channel.selectedSpot = clickSpot;
                end
            elseif event.Button == 2 % middle
            elseif event.Button == 3 % right
                % popup menu
                menu = obj.getActionsMenu();
                fig = ancestor(obj.Parent, 'Figure');
                menu.Parent = fig;
                menu.Position(1:2) = get(fig, 'CurrentPoint');
                idx = obj.spotIndexAt(x, y);
                if idx
                    uimenu(menu, 'Label', 'Remove Spot', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.removeSpot(idx));
                else
                    uimenu(menu, 'Label', 'Add Spot', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.addSpot([x y]));
                end
                menu.Visible = 1;
            end
        end
        
        function idx = spotIndexAt(obj, x, y)
            %SPOTINDEXAT Return index of spot at (x,y).
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
        
        function loadImage(obj, varargin)
            %LOADIMAGE Load new image stack from file.
            newImage = ImageStack;
            newImage.load('', '', [], [], true);
            obj.channel.images = [obj.channel.images newImage];
            obj.imageStack = newImage;
            [~, newImage.label, ~] = fileparts(newImage.filepath);
            obj.renameImage();
        end
        
        function reloadImage(obj, varargin)
            %RELOADIMAGE Reload selected image stack from file.
            obj.imageStack.reload();
            obj.imageStack = obj.imageStack;
        end
        
        function removeImage(obj, idx, ask)
            %REMOVEIMAGE Delete image stack(s).
            if ~exist('idx', 'var') || isempty(idx)
                if isempty(obj.channel.selectedImage)
                    return
                end
                idx = find(obj.channel.images == obj.channel.selectedImage);
                if isempty(idx)
                    return
                end
            end
            if exist('ask', 'var') && ask
                if questdlg(['Remove image ' char(obj.channel.images(idx).label) '?'], ...
                        'Remove image?', ...
                        'OK', 'Cancel', 'Cancel') == "Cancel"
                    return
                end
            end
            if isequal(obj.channel.selectedImage, obj.channel.images(idx))
                nimages = numel(obj.channel.images);
                if nimages > idx
                    obj.channel.selectedImage = obj.channel.images(idx+1);
                elseif idx > 1
                    obj.channel.selectedImage = obj.channel.images(idx-1);
                else
                    obj.channel.selectedImage = ImageStack.empty;
                end
            end
            delete(obj.channel.images(idx));
            obj.channel.images(idx) = [];
        end
        
        function renameImage(obj, varargin)
            %RENAMEIMAGE Edit selected image stack label.
            if isempty(obj.imageStack)
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
            %DUPLICATE Duplicate frames of selected image stack.
            %   Append duplicate image to channel's image list.
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
            %ZPROJECT Z-Project frames of selected image stack.
            %   Append z-projected image to channel's image list.
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
            %GAUSSFILTER Apply Gaussian filter to selected image (stack).
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
            %TOPHATFILTER Apply tophat filter to selected image (stack).
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
            %THRESHOLD Threshold selected image stack frame.
            %   Append thresholded mask to channel's image list.
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
            %FINDSPOTS Locate spots in selected image frame.
            %   For a binary mask, call regionprops().
            %   For a grayscale image, find the local maxima.
            if obj.imageStack.numChannels() > 1
                errordlg('Requires a grayscale intensity image.', 'Find Spots');
                return
            end
            t = obj.getCurrentFrameIndex();
            if ~t
                return
            end
            im = obj.imageStack.getFrameData(t);
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
            %CLEARSPOTS Delete all current spots.
            obj.channel.spots = Spot.empty;
            obj.selectedSpot = Spot.empty;
            obj.updateSpotMarkers();
        end
        
        function addSpot(obj, xy)
            %ADDSPOT Add a new spot at (x,y).
            newSpot = Spot;
            newSpot.xy = xy;
            obj.channel.spots = [obj.channel.spots; newSpot];
            obj.updateSpotMarkers();
            obj.selectedSpot = newSpot;
        end
        
        function removeSpot(obj, idx)
            %REMOVESPOT Delete spot(s).
            if obj.selectedSpot == obj.channel.spots(idx)
                obj.selectedSpot = Spot.empty;
            end
            obj.channel.spots(idx) = [];
            obj.updateSpotMarkers();
        end
        
        function updateSpotMarkers(obj)
            %UPDATESPOTMARKERS Update graphics to show spot locations.
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
            %UPDATESELECTEDSPOTMARKER Update graphics to show selected spot location.
            if isempty(obj.channel.selectedSpot)
                obj.selectedSpotMarker.XData = nan;
                obj.selectedSpotMarker.YData = nan;
            else
                obj.selectedSpotMarker.XData = obj.channel.selectedSpot.xy(1);
                obj.selectedSpotMarker.YData = obj.channel.selectedSpot.xy(2);
            end
        end
        
        function setOverlayChannel(obj, channel)
            %SETOVERLAYCHANNEL Set channel overlay.
            %   Overlay the selected image frame from the overlay channel
            %   on the selcted image frame of this channel.
            if ~isempty(channel) && ~isempty(obj.experimentViewer)
                c = find(obj.experimentViewer.experiment.channels == channel);
                if ~isempty(c)
                    obj.overlayChannelImageViewer = obj.experimentViewer.channelImageViewers(c);
                    return
                end
            end
            obj.overlayChannelImageViewer = ChannelImageViewer.empty;
        end
    end
end

