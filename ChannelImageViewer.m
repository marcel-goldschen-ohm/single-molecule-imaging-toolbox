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
        channel = Channel();
        
        % Handle to the selected spot.
        % If it's NOT in the channel's list of spots, it will reflect the
        % last click position within the image axes.
        selectedSpot = Spot.empty;
        
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
        
        % Handle image stack change events.
        imageStackChangedListener = [];
        
        % Handle frame change events.
        frameChangedListener = [];
    end
    
    events
        % Notify when selected spot changes.
        SelectedSpotChanged
    end
    
    methods
        function obj = ChannelImageViewer(parent)
            %CHANNELIMAGEVIEWER Constructor
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
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
                'HitTest', 'off', 'PickableParts', 'none');
            obj.selectedSpotMarker.MarkerHandle.LineWidth = 2;
            
            obj.imageStackChangedListener = ...
                addlistener(obj, 'ImageStackChanged', @(varargin) obj.onImageStackChanged());
            obj.frameChangedListener = ...
                addlistener(obj, 'FrameChanged', @(varargin) obj.onFrameChanged());
            
            obj.resize();
        end
        
        function delete(obj)
            %DELETE Destructor
            %   Delete all graphics objects not in ImageStackViewer.
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
            % set handle to selected spot
            obj.selectedSpot = spot;
            obj.updateSelectedSpotMarker();
            notify(obj, 'SelectedSpotChanged');
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
        
        function onImageStackChanged(obj)
            %ONIMAGESTACKCHANGED Handle image stack changed event.
            if any(obj.channel.images == obj.imageStack)
                obj.channel.selectedImage = obj.imageStack;
            else
                obj.channel.selectedImage = ImageStack.empty;
            end
        end
        
        function onFrameChanged(obj)
            %ONFRAMECHANGED Handle frame changed event.
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
                % T1 aligns I1 -> experiment coords
                T1 = [];
                channel = obj.channel;
                while ~isempty(channel.alignedToChannel)
                    if isempty(T1)
                        T1 = channel.alignment.transformation;
                    else
                        T1.T = channel.alignment.transformation.T * T1.T;
                    end
                    channel = channel.alignedToChannel;
                end
                % T2 aligns I2 -> experiment coords
                T2 = [];
                channel = obj.overlayChannelImageViewer.channel;
                while ~isempty(channel.alignedToChannel)
                    if isempty(T2)
                        T2 = channel.alignment.transformation;
                    else
                        T2.T = channel.alignment.transformation.T * T2.T;
                    end
                    channel = channel.alignedToChannel;
                end
                % I2 -> inv(T1) * T2 * I2
                if ~isempty(T1) && ~isempty(T2)
                    T2.T = invert(T1).T * T2.T;
                    I2 =  imwarp(I2, T2, 'OutputView', imref2d(size(I1)));
                elseif ~isempty(T2)
                    I2 =  imwarp(I2, T2, 'OutputView', imref2d(size(I1)));
                elseif ~isempty(T1)
                    I2 =  imwarp(I2, invert(T1), 'OutputView', imref2d(size(I1)));
                end
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
                    obj.frameSlider.Value = t;
                end
                obj.updateInfoText();
                notify(obj, 'FrameChanged');
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
                'Callback', @obj.renameChannel);
            
            nimages = numel(obj.channel.images);
            selectedImageIndex = obj.getSelectedImageIndex();
            if nimages > 1
                selectImageMenu = uimenu(menu, 'Label', 'Select Image', ...
                    'Separator', 'on');
                for i = 1:nimages
                    uimenu(selectImageMenu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                        'Checked', i == selectedImageIndex, ...
                        'Callback', @(varargin) obj.selectImage(i));
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
                    'Checked', i == selectedImageIndex, ...
                    'Callback', @(varargin) obj.removeImage(i, true));
            end
            
            otherChannels = obj.channel.getOtherChannelsInExperiment();
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
            
            nimages = numel(obj.channel.images);
            selectedImageIndex = obj.getSelectedImageIndex();
            for i = 1:nimages
                uimenu(menu, 'Label', obj.channel.images(i).getLabelWithSizeInfo(), ...
                    'Checked', i == selectedImageIndex, ...
                    'Callback', @(varargin) obj.selectImage(i));
            end
        end
        
        function imageAxesButtonDown(obj, src, event)
            %IMAGEAXESBUTTONDOWN Handle button press in image axes.
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            if event.Button == 1 % left
                % select spot
                spotIdx = obj.selectSpot(x, y);
                if spotIdx
                    obj.selectedSpot = obj.channel.spots(spotIdx);
                else
                    clickSpot = Spot;
                    clickSpot.xy = [x y];
                    obj.selectedSpot = clickSpot;
                end
                obj.updateSelectedSpotMarker();
            elseif event.Button == 2 % middle
            elseif event.Button == 3 % right
                % popup menu
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
        end
        
        function idx = selectSpot(obj, x, y)
            %SELECTSPOT Return index of spot at (x,y).
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
            %RENAMECHANNEL Edit channel label.
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
            %LOADIMAGE Load new image stack from file.
            newImage = ImageStack;
            newImage.load('', '', [], [], true);
            obj.channel.images = [obj.channel.images newImage];
            obj.imageStack = newImage;
            [~, newImage.label, ~] = fileparts(newImage.filepath);
            obj.editImageInfo();
        end
        
        function reloadImage(obj, varargin)
            %RELOADIMAGE Reload selected image stack from file.
            obj.imageStack.reload();
            obj.imageStack = obj.imageStack;
        end
        
        function selectImage(obj, idx)
            %SELECTIMAGE Set selected image stack.
            obj.imageStack = obj.channel.images(idx);
        end
        
        function idx = getSelectedImageIndex(obj)
            %GETSELECTEDIMAGEINDEX Return index of selected image stack.
            idx = 0;
            for i = 1:numel(obj.channel.images)
                if obj.imageStack == obj.channel.images(i)
                    idx = i;
                    return
                end
            end
        end
        
        function removeImage(obj, idx, ask)
            %REMOVEIMAGE Delete image stack(s).
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
            %RENAMEIMAGE Edit selected image stack label.
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
            if isempty(obj.selectedSpot)
                obj.selectedSpotMarker.XData = nan;
                obj.selectedSpotMarker.YData = nan;
            else
                obj.selectedSpotMarker.XData = obj.selectedSpot.xy(1);
                obj.selectedSpotMarker.YData = obj.selectedSpot.xy(2);
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
        
        function alignToChannel(obj, channel, method)
            %ALIGNTOCHANNEL Align channels by images or spots
            if ~isempty(channel) && ~isempty(channel.alignedToChannel) && channel.alignedToChannel == obj.channel
                warndlg({[char(channel.label) ' is already aligned to ' char(obj.channel.label)], ...
                    ['Aligning ' char(obj.channel.label) ' to ' char(channel.label) ' would result in a cyclic alignment loop.'], ...
                    'This is not allowed.'}, ...
                    'Cyclic Alignment Attempt');
                return
            end
            obj.channel.alignedToChannel = channel;
            obj.channel.alignment = ImageRegistration;
            if isempty(channel)
                return
            end
            if ~exist('method', 'var') || isempty(method)
                methods = {'images', 'spots', 'identical'};
                [idx, tf] = listdlg('PromptString', 'Alignment Method',...
                    'SelectionMode', 'single', ...
                    'ListString', methods);
                if ~tf
                    return
                end
                method = methods{idx};
            end
            % get handles to ChannelImageViewers for channels to be aligned
            movingViewer = obj;
            idx = find(horzcat(obj.experimentViewer.channelImageViewers.channel) == channel, 1);
            if ~idx
                return
            end
            fixedViewer = obj.experimentViewer.channelImageViewers(idx);
            if movingViewer == fixedViewer
                return
            end
            if method == "images"
                moving = movingViewer.getFrameData();
                fixed = fixedViewer.getFrameData();
                moving = imadjust(uint16(moving));
                fixed = imadjust(uint16(fixed));
                obj.channel.alignment.registerImages(moving, fixed);
            elseif method == "spots"
                % TODO
                warndlg('Aligning spots not yet implemented.', 'Coming Soon');
            elseif method == "identical"
                obj.channel.alignment = ImageRegistration;
            end
        end
    end
end

