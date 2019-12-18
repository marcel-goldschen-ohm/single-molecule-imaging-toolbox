classdef Channel < handle
    %CHANNEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        label = "Channel";
        color = [0 1 0]; % [r g b]
        notes = '';
        
        % Row vector of 2D images or 3D image stacks.
        % e.g. main image stack, spot mask image, alignment image, etc.
        images = ImageStack.empty(1,0);
        
        % Column vector of spots.
        spots = Spot.empty(0,1);
        
        % Map this channel onto another channel.
        alignedTo = struct( ...
            'channel', Channel.empty, ... % Handle to channel to which this channel is aligned.
            'registration', ImageRegistration.empty ... % Transforms this obj onto alignedTo.channel.
            );
        
        % Parent experiment handle.
        Parent = Experiment.empty;
        
        % BELOW PROPERTIES ARE PRIMARILY FOR THE USER INTERFACE
        % THEY MOSTLY JUST REFER TO THE ABOVE DATA PROPERTIES
        
        % Selected image. Should reference one of the channel's images.
        selectedImage = ImageStack.empty;
        
        % Selected spot. Either should reference one of the channel's
        % spots, or else it will reflect the user's last click position
        % within the image axes.
        selectedSpot = Spot.empty;
        
        % If true, setting selectedSpot in this channel will automatically
        % set the selectedSpot in all other channels in the parent
        % experiment to their mapped spots or locations.
        autoSelectAlignedSpotsInOtherChannels = true;
        
        % Image stack to use for spot projections. Should reference one of
        % the channel's images.
        selectedProjectionImageStack = ImageStack.empty;
        
        % Handle to channel whose image should be visually overlaid.
        overlayChannel = Channel.empty;
        overlayColorChannels = [2 1 2]; % green-magenta
        
        % Sum blocks of frames together (i.e. to simulate a longer frame
        % exposure).
        sumEveryNFramesOfProjection = 1;
        
        projectionHistogramNumBins = 80;
        projectionHistogramSqrtCounts = false;
    end
    
    properties (Dependent)
        selectedImageFrame
    end
    
    events
        % EVENTS ARE PRIMARILY FOR THE USER INTERFACE
        LabelChanged
        ImagesChanged
        SpotsChanged
        AlignedToChanged
        ParentChanged
        SelectedImageChanged
        SelectedSpotChanged
        SelectedProjectionImageStackChanged
        OverlayChannelChanged
    end
    
    methods
        function obj = Channel()
            %CHANNEL Constructor.
        end
        
        function set.images(obj, images)
            obj.images = images;
            notify(obj, 'ImagesChanged');
            % resetting these makes sure they remain valid
            obj.selectedImage = obj.selectedImage;
            obj.selectedProjectionImageStack = obj.selectedProjectionImageStack;
        end
        
        function set.spots(obj, spots)
            obj.spots = spots;
            notify(obj, 'SpotsChanged');
        end
        
        function set.alignedTo(obj, alignedTo)
            obj.alignedTo = alignedTo;
            notify(obj, 'AlignedToChanged');
        end
        
        function set.Parent(obj, h)
            obj.Parent = h;
            if ~isempty(obj.Parent) && ~any(obj.Parent.channels == obj)
                obj.Parent.channels = [obj.Parent.channels obj];
            end
            notify(obj, 'ParentChanged');
        end
        
        function set.selectedImage(obj, h)
            if isempty(h)
                %if ~isempty(obj.selectedImage)
                    obj.selectedImage = ImageStack.empty;
                    obj.updateOverlayInOtherChannels();
                    notify(obj, 'SelectedImageChanged');
                %end
            elseif ~isempty(obj.images) && any(obj.images == h)
                % h is in obj.images
                %if ~isequal(obj.selectedImage, h)
                    obj.selectedImage = h;
                    obj.updateOverlayInOtherChannels();
                    notify(obj, 'SelectedImageChanged');
                %end
            else
                % h is NOT in obj.images
                % If the current selected image is valid, leave it alone.
                % Otherwise, clear it.
                if ~isempty(obj.selectedImage) && ~any(obj.images == obj.selectedImage)
                    obj.selectedImage = ImageStack.empty;
                    obj.updateOverlayInOtherChannels();
                    notify(obj, 'SelectedImageChanged');
                end
            end
        end
        function setSelectedImage(obj, h)
            % because setters are not valid callbacks
            obj.selectedImage = h;
        end
        
        function updateOverlayInOtherChannels(obj)
            for channel = obj.getOtherChannels()
                if isequal(channel.overlayChannel, obj)
                    notify(channel, 'OverlayChannelChanged');
                end
            end
        end
        
        function frame = get.selectedImageFrame(obj)
            frame = [];
            if ~isempty(obj.selectedImage)
                frame = obj.selectedImage.getFrame();
            end
        end
        
        function set.selectedSpot(obj, selectedSpot)
            if obj.autoSelectAlignedSpotsInOtherChannels && ~isempty(obj.Parent)
                obj.selectAlignedSpotsInOtherChannels(selectedSpot);
            end
            obj.selectedSpot = selectedSpot;
            notify(obj, 'SelectedSpotChanged');
        end
        
        function selectAlignedSpotsInOtherChannels(obj, selectedSpot)
            if ~exist('selectedSpot', 'var')
                selectedSpot = obj.selectedSpot;
            end
            idx = [];
            if ~isempty(selectedSpot) && ~isempty(obj.spots)
                idx = find(obj.spots == selectedSpot, 1);
            end
            nspots = numel(obj.spots);
            for channel = obj.getOtherChannels()
                tmp = channel.autoSelectAlignedSpotsInOtherChannels;
                channel.autoSelectAlignedSpotsInOtherChannels = false;
                if isempty(selectedSpot)
                    % clear selected spot in all channels
                    channel.selectedSpot = Spot.empty;
                else
                    isMapped = ~isempty(idx) && numel(channel.spots) >= idx;
                    if isMapped
                        % show the mapped spot in channel
                        channel.selectedSpot = channel.spots(idx);
                    else
                        % select aligned location in channel
                        alignedSpot = Spot;
                        alignedSpot.xy = channel.getOtherChannelSpotsInLocalCoords(obj, selectedSpot.xy);
                        channel.selectedSpot = alignedSpot;
                    end
                end
                channel.autoSelectAlignedSpotsInOtherChannels = tmp;
            end
        end
        
        function set.selectedProjectionImageStack(obj, h)
            if isempty(h)
                %if ~isempty(obj.selectedProjectionImageStack)
                    obj.selectedProjectionImageStack = ImageStack.empty;
                    notify(obj, 'SelectedProjectionImageStackChanged');
                %end
            elseif ~isempty(obj.images) && any(obj.images == h)
                % h is in obj.images
                %if ~isequal(obj.selectedProjectionImageStack, h)
                    obj.selectedProjectionImageStack = h;
                    notify(obj, 'SelectedProjectionImageStackChanged');
                %end
            else
                % h is NOT in obj.images
                % If the current selected image is valid, leave it alone.
                % Otherwise, select the first image stack.
                if isempty(obj.selectedProjectionImageStack) || ~any(obj.images == obj.selectedProjectionImageStack)
                    prev = obj.selectedProjectionImageStack;
                    obj.selectFirstValidProjectionImageStack();
                    %if ~isequal(prev, obj.selectedProjectionImageStack)
                        notify(obj, 'SelectedProjectionImageStackChanged');
                    %end
                end
            end
        end
        function setSelectedProjectionImageStack(obj, h)
            % because setters are not valid callbacks
            obj.selectedProjectionImageStack = h;
        end
        
        function selectFirstValidProjectionImageStack(obj)
            for image = obj.images
                if image.numFrames > 1
                    obj.selectedProjectionImageStack = image;
                    return
                end
            end
            obj.selectedProjectionImageStack = ImageStack.empty;
        end
        
        function set.overlayChannel(obj, channel)
            obj.overlayChannel = channel;
            notify(obj, 'OverlayChannelChanged');
        end
        function setOverlayChannel(obj, channel)
            % Only needed because setters aren't valid callbacks.
            obj.overlayChannel = channel;
        end
        
        function set.overlayColorChannels(obj, colors)
            if isnumeric(colors)
                obj.overlayColorChannels = colors;
            elseif colors == "green-magenta"
                obj.overlayColorChannels = [2 1 2];
            elseif colors == "magenta-green"
                obj.overlayColorChannels = [1 2 1];
            elseif colors == "red-cyan"
                obj.overlayColorChannels = [1 2 2];
            elseif colors == "cyan-red"
                obj.overlayColorChannels = [2 1 1];
            elseif colors == "green-red"
                obj.overlayColorChannels = [2 1 0];
            elseif colors == "red-green"
                obj.overlayColorChannels = [1 2 0];
            elseif colors == "green-blue"
                obj.overlayColorChannels = [0 1 2];
            elseif colors == "blue-green"
                obj.overlayColorChannels = [0 2 1];
            elseif colors == "red-blue"
                obj.overlayColorChannels = [1 0 2];
            elseif colors == "blue-red"
                obj.overlayColorChannels = [2 0 1];
            end
            notify(obj, 'OverlayChannelChanged');
        end
        function setOverlayColorChannels(obj, colors)
            % Only needed because setters aren't valid callbacks.
            obj.overlayColorChannels = colors;
        end
        
        function set.sumEveryNFramesOfProjection(obj, n)
            obj.sumEveryNFramesOfProjection = n;
            if ~isempty(obj.selectedSpot)
                % update selected spot projection
                notify(obj, 'SelectedSpotChanged');
            end
        end
        
        function channels = getOtherChannels(obj)
            channels = Channel.empty(1,0);
            if ~isempty(obj.Parent)
                channels = setdiff(obj.Parent.channels, obj);
            end
        end
        
        function [x,y] = getSpotProjection(obj, spot)
            x = spot.projection.time;
            y = spot.projection.data;
            if isempty(y)
                return
            end
            % sum frame blocks?
            if obj.sumEveryNFramesOfProjection > 1
                n = obj.sumEveryNFramesOfProjection;
                npts = floor(double(length(y)) / n) * n;
                x = x(1:n:npts);
                y0 = y;
                y = y0(1:n:npts);
                for k = 2:n
                    y = y + y0(k:n:npts);
                end
            end
        end
        
        function tf = areSpotsMappedToOtherChannelSpots(obj, channel, dmax)
            if isempty(obj.spots) || isempty(channel.spots) ...
                    || numel(obj.spots) ~= numel(channel.spots)
                tf = false;
                return
            end
            if exist('dmax', 'var')
                xy = obj.getOtherChannelSpotsInLocalCoords(channel, vertcat(channel.spots.xy));
                d2 = sum((xy - vertcat(obj.spots.xy)).^2, 2);
                % only considered to be mapped if locations are closely aligned
                tf = all(d2 <= dmax^2);
            else
                tf = true;
            end
        end
        
        function editLabel(obj)
            answer = inputdlg({'label'}, 'Channel Label', 1, {char(obj.label)});
            if isempty(answer)
                return
            end
            obj.label = string(answer{1});
        end
        
        function editSumEveryNFramesOfProjection(obj)
            answer = inputdlg({'Sum blocks of N frames:'}, ...
                'Sum Frames', 1, {num2str(obj.sumEveryNFramesOfProjection)});
            if isempty(answer)
                return
            end
            obj.sumEveryNFramesOfProjection = str2num(answer{1});
        end
        
        function loadNewImage(obj, filepath)
            %LOADNEWIMAGE Load new image stack from file.
            if ~exist('filepath', 'var')
                filepath = '';
            end
            newImage = ImageStack;
            newImage.load(filepath, '', [], [], true);
            [~, newImage.label, ~] = fileparts(newImage.fileInfo(1).Filename);
            obj.images = [obj.images newImage];
            obj.selectedImage = newImage;
        end
        
        function reloadSelectedImage(obj)
            %RELOADSELECTEDIMAGE Reload selected image stack from file.
            if isempty(obj.selectedImage)
                return
            end
            obj.selectedImage.reload();
        end
        
        function removeImage(obj, idx, ask)
            %REMOVEIMAGEAT Delete obj.images(idx).
            if ~exist('idx', 'var') || isempty(idx)
                if isempty(obj.selectedImage)
                    return
                end
                idx = find(obj.images == obj.selectedImage);
                if isempty(idx)
                    return
                end
            end
            % If idx is an ImageStack handle, convert it to an index.
            if class(idx) == "ImageStack"
                idx = find(obj.images == idx, 1);
                if isempty(idx)
                    return
                end
            end
            if exist('ask', 'var') && ask
                if questdlg(['Remove image ' char(obj.images(idx).label) '?'], ...
                        'Remove image?', ...
                        'OK', 'Cancel', 'Cancel') == "Cancel"
                    return
                end
            end
            % update selected image if it was removed
            if isequal(obj.selectedImage, obj.images(idx))
                nimages = numel(obj.images);
                if nimages > idx
                    obj.selectedImage = obj.images(idx+1);
                elseif idx > 1
                    obj.selectedImage = obj.images(idx-1);
                else
                    obj.selectedImage = ImageStack.empty;
                end
            end
            delete(obj.images(idx));
            obj.images(idx) = [];
        end
        
        function duplicateSelectedImage(obj, frames)
            %DUPLICATE Duplicate frames of selected image stack.
            %   Append duplicate image to channel's image list.
            if isempty(obj.selectedImage)
                return
            end
            if ~exist('frames', 'var')
                frames = [];
            end
            try
                newImage = obj.selectedImage.duplicate(frames);
                if ~isempty(newImage.data)
                    obj.images = [obj.images newImage];
                    obj.selectedImage = newImage;
                end
            catch
            end
        end
        
        function zprojectSelectedImage(obj, frames, method, previewImage)
            %ZPROJECT Z-Project frames of selected image stack.
            %   Append z-projected image to channel's image list.
            if isempty(obj.selectedImage)
                return
            end
            if ~exist('frames', 'var')
                frames = [];
            end
            if ~exist('method', 'var')
                method = '';
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            try
                newImage = obj.selectedImage.zproject(frames, method, previewImage);
                if ~isempty(newImage.data)
                    obj.images = [obj.images newImage];
                    obj.selectedImage = newImage;
                end
            catch
            end
        end
        
        function gaussFilterSelectedImage(obj, sigma, applyToAllFrames, previewImage)
            %GAUSSFILTER Apply Gaussian filter to selected image (stack).
            if isempty(obj.selectedImage)
                return
            end
            if ~exist('sigma', 'var')
                sigma = [];
            end
            if ~exist('applyToAllFrames', 'var')
                applyToAllFrames = [];
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            try
                t = obj.selectedImage.selectedFrameIndex;
                obj.selectedImage.gaussFilter(t, sigma, previewImage, applyToAllFrames);
            catch
            end
        end
        
        function tophatFilterSelectedImage(obj, diskRadius, applyToAllFrames, previewImage)
            %TOPHATFILTER Apply tophat filter to selected image (stack).
            if isempty(obj.selectedImage)
                return
            end
            if ~exist('diskRadius', 'var')
                diskRadius = [];
            end
            if ~exist('applyToAllFrames', 'var')
                applyToAllFrames = [];
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            try
                t = obj.selectedImage.selectedFrameIndex;
                obj.selectedImage.tophatFilter(t, diskRadius, previewImage, applyToAllFrames);
            catch
            end
        end
        
        function thresholdSelectedImage(obj, threshold, previewImage)
            %THRESHOLD Threshold selected image stack frame.
            %   Append thresholded mask to channel's image list.
            if isempty(obj.selectedImage)
                return
            end
            if ~exist('threshold', 'var')
                threshold = [];
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            try
                t = obj.selectedImage.selectedFrameIndex;
                newImage = obj.selectedImage.threshold(t, threshold, previewImage);
                if ~isempty(newImage.data)
                    obj.images = [obj.images newImage];
                    obj.selectedImage = newImage;
                end
            catch
            end
        end
        
        function findSpotsInSelectedImage(obj, previewImage)
            %   For a binary mask, call regionprops().
            %   For a grayscale image, find the local maxima.
            if isempty(obj.selectedImage)
                return
            end
            im = obj.selectedImageFrame;
            if isempty(im)
                return
            end
            if numel(unique(im)) == 2
                % convert two-valued image to logical
                im = im > min(im(:));
            end
            if islogical(im)
                props = regionprops(im, 'all');
                nspots = numel(props);
                if nspots
                    newSpots = Spot.empty(0,1);
                    newSpots(nspots,1) = Spot;
                    for k = 1:nspots
                        newSpots(k).xy = props(k).Centroid;
                        newSpots(k).props = props(k);
                    end
                    obj.spots = newSpots;
                else
                    obj.spots = Spot.empty(0,1);
                end
            else
                xy = ImageOps.findMaximaPreview(im, [], [], 0, 0, previewImage);
                nspots = size(xy,1);
                if nspots
                    newSpots = Spot.empty(0,1);
                    newSpots(nspots,1) = Spot;
                    for k = 1:nspots
                        newSpots(k).xy = xy(k,:);
                    end
                    obj.spots = newSpots;
                else
                    obj.spots = Spot.empty(0,1);
                end
            end
            if ~isempty(obj.spots)
                obj.selectedSpot = obj.spots(1);
            else
                obj.selectedSpot = Spot.empty;
            end
        end
        
        function clearSpots(obj)
            %CLEARSPOTS Delete all current spots.
            obj.spots = Spot.empty(0,1);
            obj.selectedSpot = Spot.empty;
            % clear spots in all other channels?
            otherChannels = obj.getOtherChannels();
            if ~isempty(otherChannels)
                if questdlg('Clear spots in all other channels?', 'Clear Spots') == "Yes"
                    for channel = otherChannels
                        channel.clearSpots();
                    end
                end
            end
        end
        
        function addSpot(obj, xy)
            %ADDSPOT Add a new spot at (x,y).
            nspots = numel(obj.spots);
            newSpot = Spot;
            newSpot.xy = xy;
            obj.spots = [obj.spots; newSpot];
            obj.selectedSpot = newSpot;
            % add spot in all other 1 to 1 mapped channels?
            otherChannels = obj.getOtherChannels();
            if ~isempty(otherChannels)
                %if questdlg('Add mapped spot to all other channels?', 'Add Spot') == "Yes"
                    for channel = otherChannels
                        if numel(channel.spots) == nspots
                            newSpot = Spot;
                            newSpot.xy = obj.getOtherChannelSpotsInLocalCoords(channel, xy);
                            channel.spots = [channel.spots; newSpot];
                            channel.selectedSpot = newSpot;
                        end
                    end
                %end
            end
        end
        
        function removeSpot(obj, idx)
            %REMOVESPOT Delete spot(s).
            nspots = numel(obj.spots);
            if any(obj.spots(idx) == obj.selectedSpot)
                obj.selectedSpot = Spot.empty;
            end
            obj.spots(idx) = [];
            % remove spot(s) from all other 1 to 1 mapped channels?
            otherChannels = obj.getOtherChannels();
            if ~isempty(otherChannels)
                %if questdlg('Remove mapped spot(s) in all other channels?', 'Remove Spot') == "Yes"
                    for channel = otherChannels
                        if numel(channel.spots) == nspots
                            if any(channel.spots(idx) == channel.selectedSpot)
                                channel.selectedSpot = Spot.empty;
                            end
                            channel.spots(idx) = [];
                        end
                    end
                %end
            end
        end
        
        function alignToChannel(obj, channel, method, moving, fixed)
            %ALIGNTOCHANNEL Align obj --> channel by images or spots
            if ~isempty(channel) && ~isempty(channel.alignedTo.channel) && channel.alignedTo.channel == obj
                warndlg({[char(channel.label) ' is already aligned to ' char(obj.label)], ...
                    ['Aligning ' char(obj.label) ' to ' char(channel.label) ' would result in a cyclic alignment loop.'], ...
                    'This is not allowed.'}, ...
                    'Cyclic Alignment Attempt');
                return
            end
            alignedTo.channel = channel;
            alignedTo.registration = ImageRegistration;
            if isempty(channel)
                obj.alignedTo = alignedTo;
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
            if method == "images"
                if ~exist('moving', 'var') || isempty(moving)
                    moving = obj.selectedImageFrame;
                end
                if ~exist('fixed', 'var') || isempty(fixed)
                    fixed = channel.selectedImageFrame;
                end
                if isempty(moving) || isempty(fixed)
                    warndlg('First select the image frames to be aligned.', 'No selected image frames.');
                    return
                end
                moving = imadjust(uint16(moving));
                fixed = imadjust(uint16(fixed));
                alignedTo.registration.registerImages(moving, fixed);
                obj.alignedTo = alignedTo;
            elseif method == "spots"
                % TODO
                warndlg('Aligning spots not yet implemented.', 'Coming Soon');
            elseif method == "identical"
                alignedTo.registration = ImageRegistration;
                obj.alignedTo = alignedTo;
            end
        end
        
        function T = getTransformationToAlignedCoords(obj)
            % Return 2D transformation to parent experiment (aligned) coordinates.
            T = [];
            channel = obj;
            while ~isempty(channel.alignedTo.channel)
                if isempty(T)
                    T = channel.alignedTo.registration.transformation;
                else
                    T.T = channel.alignedTo.registration.transformation.T * T.T;
                end
                channel = channel.alignedTo.channel;
            end
        end
        
        function im = getOtherChannelImageInLocalCoords(obj, channel, im)
            T = Channel.getTransformationBetweenChannels(channel, obj);
            if ~isempty(T)
                im =  imwarp(im, T, 'OutputView', imref2d(size(im)));
            end
        end
        
        function xy = getOtherChannelSpotsInLocalCoords(obj, channel, xy)
            T = Channel.getTransformationBetweenChannels(channel, obj);
            if ~isempty(T)
                xy = transformPointsForward(T, xy);
            end
        end
        
        function copyAlignedSpotsToOtherChannels(obj, channels)
            xy = vertcat(obj.spots.xy);
            nspots = numel(obj.spots);
            for channel = channels
                cxy = channel.getOtherChannelSpotsInLocalCoords(obj, xy);
                newSpots = Spot.empty;
                newSpots(nspots,1) = Spot;
                for i = 1:nspots
                    newSpots(i).xy = cxy(i,:);
                    newSpots(i).tags = obj.spots(i).tags;
                end
                channel.spots = newSpots;
            end
        end
        
        function copyAlignedSpotsToAllOtherChannels(obj)
            channels = obj.getOtherChannels();
            obj.copyAlignedSpotsToOtherChannels(channels);
        end
        
        function menu = removeImageMenu(obj, parent)
            menu = uimenu(parent, 'Label', 'Remove Image');
            for image = obj.images
                uimenu(menu, 'Label', image.getLabelWithSizeInfo(), ...
                    'Checked', isequal(image, obj.selectedImage), ...
                    'Callback', @(varargin) obj.removeImage(image, true));
            end
        end
        
        function menu = selectImageMenu(obj, parent)
            menu = uimenu(parent, 'Label', 'Select Image');
            for image = obj.images
                uimenu(menu, 'Label', image.getLabelWithSizeInfo(), ...
                    'Checked', isequal(image, obj.selectedImage), ...
                    'Callback', @(varargin) obj.setSelectedImage(image));
            end
        end
        
        function menu = selectProjectionImageStackMenu(obj, parent)
            menu = uimenu(parent, 'Label', 'Select Projection Image Stack');
            for image = obj.images
                if image.numFrames > 1
                    uimenu(menu, 'Label', image.getLabelWithSizeInfo(), ...
                        'Checked', isequal(image, obj.selectedProjectionImageStack), ...
                        'Callback', @(varargin) obj.setSelectedProjectionImageStack(image));
                end
            end
        end
        
        function menu = overlayChannelMenu(obj, parent)
            menu = uimenu(parent, 'Label', 'Overlay Channel');
            uimenu(menu, 'Label', 'None', ...
                'Checked', isempty(obj.overlayChannel), ...
                'Callback', @(varargin) obj.setOverlayChannel(Channel.empty));
            for channel = obj.getOtherChannels()
                uimenu(menu, 'Label', channel.label, ...
                    'Checked', isequal(channel, obj.overlayChannel), ...
                    'Callback', @(varargin) obj.setOverlayChannel(channel));
            end
        end
        
        function menu = overlayColorsMenu(obj, parent)
            menu = uimenu(parent, 'Label', 'Overlay Colors');
            uimenu(menu, 'Label', 'green-magenta', ...
                'Checked', isequal(obj.overlayColorChannels, [2 1 2]), ...
                'Callback', @(varargin) obj.setOverlayColorChannels([2 1 2]));
            uimenu(menu, 'Label', 'magenta-green', ...
                'Checked', isequal(obj.overlayColorChannels, [1 2 1]), ...
                'Callback', @(varargin) obj.setOverlayColorChannels([1 2 1]));
            uimenu(menu, 'Label', 'red-cyan', ...
                'Checked', isequal(obj.overlayColorChannels, [1 2 2]), ...
                'Callback', @(varargin) obj.setOverlayColorChannels([1 2 2]));
            uimenu(menu, 'Label', 'cyan-red', ...
                'Checked', isequal(obj.overlayColorChannels, [2 1 1]), ...
                'Callback', @(varargin) obj.setOverlayColorChannels([2 1 1]));
            uimenu(menu, 'Label', 'green-red', ...
                'Checked', isequal(obj.overlayColorChannels, [2 1 0]), ...
                'Callback', @(varargin) obj.setOverlayColorChannels([2 1 0]));
            uimenu(menu, 'Label', 'red-green', ...
                'Checked', isequal(obj.overlayColorChannels, [1 2 0]), ...
                'Callback', @(varargin) obj.setOverlayColorChannels([1 2 0]));
        end
        
        function menu = alignToChannelMenu(obj, parent)
            menu = uimenu(parent, 'Label', 'Align To Channel');
            uimenu(menu, 'Label', 'None', ...
                'Checked', isempty(obj.alignedTo.channel), ...
                'Callback', @(varargin) obj.alignToChannel(Channel.empty));
            for channel = obj.getOtherChannels()
                uimenu(menu, 'Label', channel.label, ...
                    'Checked', isequal(obj.alignedTo.channel, channel), ...
                    'Callback', @(varargin) obj.alignToChannel(channel));
            end
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Channel(), s);
        end
        
        function T = getTransformationBetweenChannels(fromChannel, toChannel)
            T = []; % fromChannel -> toChannel
            T1 = fromChannel.getTransformationToAlignedCoords(); % fromChannel -> aligned coords
            T2 = toChannel.getTransformationToAlignedCoords(); % toChannel -> aligned coords
            % T = inv(T2) * T1 = (aligned -> toChannel) (fromChannel -> aligned)
            if ~isempty(T1) && ~isempty(T2)
                T = T1;
                T.T = invert(T2).T * T.T;
            elseif ~isempty(T1)
                T = T1;
            elseif ~isempty(T2)
                T = invert(T2);
            end
        end
    end
end

