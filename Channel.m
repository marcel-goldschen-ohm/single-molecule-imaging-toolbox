classdef Channel < handle
    %CHANNEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % DATA PROPERTIES
        
        % Parent experiment.
        experiment = Experiment.empty;
        
        % Channel label.
        label = "Channel";
        
        % Row vector of 2D images or 3D image stacks.
        % e.g. main image stack, spot mask image, alignment image, etc.
        images = ImageStack.empty(1,0);
        
        % Column vector of spots.
        spots = Spot.empty(0,1);
        
        % Map this channel onto another channel.
        alignedToChannel = Channel.empty;
        alignment = ImageRegistration.empty; % Transforms this obj onto alignedToChannel.
        
        % STATE PROPERTIES
        
        % Selected image. Should reference one of the channel's images.
        selectedImage = ImageStack.empty;
        
        % Selected spot. Either should reference one of the channel's
        % spots, or else it will reflect the user's last click position
        % within the image axes.
        selectedSpot = Spot.empty;
        
        % If true, setting selectedSpot in this channel will automatically
        % set the selectedSpot in all other channels in the parent
        % experiment to their mapped spots or locations.
        autoSelectMappedSpotsInOtherChannels = true;
        
        % Image stack to use for spot projections. Should reference one of
        % the channel's images.
        selectedProjectionImageStack = ImageStack.empty;
        
        % Handle to channel whose image should be visually overlaid.
        overlayChannel = Channel.empty;
        overlayColorChannels = [2 1 2]; % green-magenta
        
        % Spot time series options.
        spotTsSumEveryN = 1; % e.g. simulate longer exposures
        spotTsFilter = digitalFilter.empty;
        spotTsApplyFilter = false;
    end
    
    properties (Dependent)
        % Selected frame of selectedImage.
        selectedImageFrame
        
        % selectedSpot if it's in spots, otherwise spots(1) if it exists.
        querySpot
    end
    
    events
        LabelChanged
        ImagesChanged
        SpotsChanged
        AlignmentChanged
        SelectedImageChanged
        SelectedSpotChanged
        SelectedProjectionImageStackChanged
        OverlayChannelChanged
    end
    
    methods
        function obj = Channel()
            %CHANNEL Constructor.
        end
        
        function delete(obj)
            for channel = obj.getOtherChannels()
                if channel.alignedToChannel == obj
                    channel.alignedToChannel = Channel.empty;
                end
                if channel.overlayChannel == obj
                    channel.overlayChannel = Channel.empty;
                end
            end
        end
        
        function set.experiment(obj, h)
            obj.experiment = h;
            % make sure parent experiment's list of channels contains obj
            if ~isempty(obj.experiment) && ~any(obj.experiment.channels == obj)
                obj.experiment.channels = [obj.experiment.channels obj];
            end
        end
        
        function set.label(obj, label)
            obj.label = string(label);
            notify(obj, 'LabelChanged');
        end
        function editLabel(obj)
            answer = inputdlg({'Label'}, 'Channel Label', 1, {char(obj.label)});
            if isempty(answer)
                return
            end
            obj.label = string(answer{1});
        end
        
        function set.images(obj, images)
            obj.images = images;
            notify(obj, 'ImagesChanged');
            if isempty(obj.selectedImage) && ~isempty(obj.images)
                obj.selectedImage = obj.images(1);
            end
            if isempty(obj.selectedProjectionImageStack) && ~isempty(obj.images)
                obj.selectFirstValidProjectionImageStack();
            end
%             % resetting these makes sure they remain valid
%             obj.selectedImage = obj.selectedImage;
%             obj.selectedProjectionImageStack = obj.selectedProjectionImageStack;
        end
        
        function set.spots(obj, spots)
            obj.spots = spots;
            if ~isempty(obj.spots)
                [obj.spots.channel] = deal(obj);
            end
            notify(obj, 'SpotsChanged');
        end
        
        function set.alignedToChannel(obj, channel)
            obj.alignedToChannel = channel;
            notify(obj, 'AlignmentChanged');
        end
        function set.alignment(obj, alignment)
            obj.alignment = alignment;
            notify(obj, 'AlignmentChanged');
        end
        
        function set.selectedImage(obj, h)
            obj.selectedImage = h;
            obj.updateOverlayInOtherChannels();
            notify(obj, 'SelectedImageChanged');
%             if isempty(h)
%                 obj.selectedImage = ImageStack.empty;
%                 obj.updateOverlayInOtherChannels();
%                 notify(obj, 'SelectedImageChanged');
%             elseif ~isempty(obj.images) && any(obj.images == h)
%                 % h is in obj.images
%                 obj.selectedImage = h;
%                 obj.updateOverlayInOtherChannels();
%                 notify(obj, 'SelectedImageChanged');
%             else
%                 % h is NOT in obj.images
%                 % If the current selected image is valid, leave it alone.
%                 % Otherwise, clear it.
%                 if ~isempty(obj.selectedImage) && ~any(obj.images == obj.selectedImage)
%                     obj.selectedImage = ImageStack.empty;
%                     obj.updateOverlayInOtherChannels();
%                     notify(obj, 'SelectedImageChanged');
%                 end
%             end
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
        
        function set.selectedSpot(obj, selectedSpot)
            if obj.autoSelectMappedSpotsInOtherChannels && ~isempty(obj.experiment)
                otherChannels = obj.getOtherChannels();
                if ~isempty(otherChannels)
                    obj.selectMappedSpotsInOtherChannels(selectedSpot, otherChannels);
                end
            end
            obj.selectedSpot = selectedSpot;
            if ~isempty(obj.selectedSpot)
                obj.selectedSpot.channel = obj;
            end
            notify(obj, 'SelectedSpotChanged');
        end
        
        function selectMappedSpotsInOtherChannels(obj, selectedSpot, otherChannels)
            if ~exist('selectedSpot', 'var')
                selectedSpot = obj.selectedSpot;
            end
            if ~exist('otherChannels', 'var')
                otherChannels = obj.getOtherChannels();
            end
            if isempty(otherChannels)
                return
            end
            idx = [];
            if ~isempty(selectedSpot) && ~isempty(obj.spots)
                idx = find(obj.spots == selectedSpot, 1);
            end
            nspots = numel(obj.spots);
            for channel = otherChannels
                tmp = channel.autoSelectMappedSpotsInOtherChannels;
                channel.autoSelectMappedSpotsInOtherChannels = false;
                if isempty(selectedSpot)
                    % clear selected spot in other channel
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
                channel.autoSelectMappedSpotsInOtherChannels = tmp;
            end
        end
        
        function set.selectedProjectionImageStack(obj, h)
            obj.selectedProjectionImageStack = h;
            notify(obj, 'SelectedProjectionImageStackChanged');
%             if isempty(h)
%                 obj.selectedProjectionImageStack = ImageStack.empty;
%                 notify(obj, 'SelectedProjectionImageStackChanged');
%             elseif ~isempty(obj.images) && any(obj.images == h)
%                 % h is in obj.images
%                 obj.selectedProjectionImageStack = h;
%                 notify(obj, 'SelectedProjectionImageStackChanged');
%             else
%                 % h is NOT in obj.images
%                 % If the current selected image is valid, leave it alone.
%                 % Otherwise, select the first image stack.
%                 if isempty(obj.selectedProjectionImageStack) || ~any(obj.images == obj.selectedProjectionImageStack)
%                     obj.selectFirstValidProjectionImageStack();
%                 end
%             end
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
        
        function frame = get.selectedImageFrame(obj)
            frame = [];
            if ~isempty(obj.selectedImage)
                frame = obj.selectedImage.selectedFrame;
            end
        end
        
        function spot = get.querySpot(obj)
            if isempty(obj.spots)
                spot = Spot.empty;
            elseif ~isempty(obj.selectedSpot) && any(obj.spots == obj.selectedSpot)
                spot = obj.selectedSpot;
            else
                spot = obj.spots(1);
            end
        end
        
        function channels = getOtherChannels(obj)
            channels = Channel.empty(1,0);
            if ~isempty(obj.experiment) && isvalid(obj.experiment)
                channels = setdiff(obj.experiment.channels, obj);
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
        
        function loadNewImage(obj, filepath)
            %LOADNEWIMAGE Load new image stack from file.
            if ~exist('filepath', 'var')
                filepath = '';
            end
            newImage = ImageStack;
            newImage.load(filepath, '', [], [], true);
            if isempty(newImage.fileInfo)
                return
            end
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
            if ~isempty(obj.spots)
                if questdlg('This will overwrite current spots. Continue?', 'Overwrite Spots?') ~= "Yes"
                    return
                end
            end
            if numel(unique(im)) == 2
                % convert two-valued image to logical
                im = im > min(im(:));
            end
            if islogical(im)
                wb = waitbar(0, 'Finding spots...');
                props = regionprops(im, 'all');
                nspots = numel(props);
                if nspots
                    newSpots = Spot.empty(0,1);
                    for k = 1:nspots
                        newSpots(k,1) = Spot;
                        newSpots(k,1).xy = props(k).Centroid;
                        newSpots(k,1).props = props(k);
                    end
                    obj.spots = newSpots;
                else
                    obj.spots = Spot.empty(0,1);
                end
                close(wb);
            else
                xy = ImageOps.findMaximaPreview(im, [], [], 0, 0, previewImage);
                nspots = size(xy,1);
                if nspots
                    newSpots = Spot.empty(0,1);
                    for k = 1:nspots
                        newSpots(k,1) = Spot;
                        newSpots(k,1).xy = xy(k,:);
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
            newSpot = Spot;
            newSpot.xy = xy;
            obj.spots = [obj.spots; newSpot];
            obj.selectedSpot = newSpot;
            % add spot in all other 1 to 1 mapped channels?
            otherChannels = obj.getOtherChannels();
            if ~isempty(otherChannels)
                %if questdlg('Add mapped spot to all other channels?', 'Add Spot') == "Yes"
                    for channel = otherChannels
                        if obj.areSpotsMappedToOtherChannelSpots(channel)
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
            if any(obj.spots(idx) == obj.selectedSpot)
                obj.selectedSpot = Spot.empty;
            end
            delete(obj.spots(idx));
            obj.spots(idx) = [];
            % remove spot(s) from all other 1 to 1 mapped channels?
            otherChannels = obj.getOtherChannels();
            if ~isempty(otherChannels)
                %if questdlg('Remove mapped spot(s) in all other channels?', 'Remove Spot') == "Yes"
                    for channel = otherChannels
                        if obj.areSpotsMappedToOtherChannelSpots(channel)
                            if any(channel.spots(idx) == channel.selectedSpot)
                                channel.selectedSpot = Spot.empty;
                            end
                            delete(channel.spots(idx));
                            channel.spots(idx) = [];
                        end
                    end
                %end
            end
        end
        
        function alignToChannel(obj, channel, method, moving, fixed)
            %ALIGNTOCHANNEL Align obj --> channel by images or spots
            if ~isempty(channel) && ~isempty(channel.alignedToChannel) && channel.alignedToChannel == obj
                warndlg({[char(channel.label) ' is already aligned to ' char(obj.label)], ...
                    ['Aligning ' char(obj.label) ' to ' char(channel.label) ' would result in a cyclic alignment loop.'], ...
                    'This is not allowed.'}, ...
                    'Cyclic Alignment Attempt');
                return
            end
            obj.alignedToChannel = channel;
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
                reg = ImageRegistration;
                reg.registerImages(moving, fixed);
                if ~isempty(reg.transformation)
                    obj.alignment = reg;
                end
            elseif method == "spots"
                % TODO
                warndlg('Aligning spots not yet implemented.', 'Coming Soon');
            elseif method == "identical"
                obj.alignment = ImageRegistration;
            end
        end
        
        function T = getTransformationToAlignedCoords(obj)
            % Return 2D transformation to parent experiment (aligned) coordinates.
            T = [];
            channel = obj;
            while ~isempty(channel.alignedToChannel)
                if isempty(T)
                    T = channel.alignment.transformation;
                else
                    T.T = channel.alignment.transformation.T * T.T;
                end
                channel = channel.alignedToChannel;
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
        
        function copyMappedSpotsToOtherChannels(obj, channels)
            xy = vertcat(obj.spots.xy);
            nspots = numel(obj.spots);
            for channel = channels
                cxy = channel.getOtherChannelSpotsInLocalCoords(obj, xy);
                newSpots = Spot.empty(0,1);
                newSpots(nspots,1) = Spot;
                for i = 1:nspots
                    newSpots(i).xy = cxy(i,:);
                    newSpots(i).tags = obj.spots(i).tags;
                end
                channel.spots = newSpots;
            end
        end
        function copyMappedSpotsToAllOtherChannels(obj)
            obj.copyMappedSpotsToOtherChannels(obj.getOtherChannels());
        end
        
        function setSpotTsSampleInterval(obj, dt)
            if ~exist('dt', 'var')
                answer = inputdlg({'Sample Interval (sec):'}, 'Sample Interval', 1, {''});
                if isempty(answer)
                    return
                end
                dt = str2num(answer{1});
            end
            if ~isempty(obj.selectedProjectionImageStack)
                obj.selectedProjectionImageStack.frameIntervalSec = dt;
            end
            spots = union(obj.spots, obj.selectedSpot);
            for k = 1:numel(spots)
                spots(k).tsData.rawTime = dt;
                if isempty(dt)
                    spots(k).tsData.timeUnits = 'frames';
                else
                    spots(k).tsData.timeUnits = 'seconds';
                end
            end
            if ~isempty(obj.selectedSpot)
                notify(obj, 'SelectedSpotChanged');
            end
        end
        
        function set.spotTsSumEveryN(obj, N)
            obj.spotTsSumEveryN = N;
            if ~isempty(obj.selectedSpot)
                notify(obj, 'SelectedSpotChanged');
            end
        end
        function editSpotTsSumEveryN(obj)
            answer = inputdlg({'Sum blocks of N frames:'}, ...
                'Sum Frames', 1, {num2str(obj.spotTsSumEveryN)});
            if isempty(answer)
                return
            end
            obj.spotTsSumEveryN = str2num(answer{1});
        end
        
        function set.spotTsFilter(obj, filt)
            obj.spotTsFilter = filt;
            if ~isempty(obj.selectedSpot)
                notify(obj, 'SelectedSpotChanged');
            end
        end
        function editSpotTsDigitalFilter(obj)
            % launch MATLAB's digital filter designer
            % when complete this will put the designed digitalFilter object
            % in the base workspace ans variable
            designfilt();
            try
                %evalin('base', 'whos')
                filt = evalin('base', 'ans');
                %class(filt)
                if class(filt) == "digitalFilter"
                    obj.spotTsFilter = filt;
                end
            catch
            end
        end
        
        function toggleSpotTsApplyFilter(obj)
            obj.spotTsApplyFilter = ~obj.spotTsApplyFilter;
            if ~isempty(obj.selectedSpot)
                notify(obj, 'SelectedSpotChanged');
            end
            if isempty(obj.spotTsFilter)
                warndlg('No filter has been set for this channel.', 'No Filter');
            end
        end
    end
    
    methods (Static)
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

