classdef Channel < handle
    %CHANNEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        label = "Channel";
        color = [0 1 0]; % [r g b]
        notes = '';
        
        % Row vector of images or image stacks.
        % e.g. main image stack, spot mask image, alignment image, etc.
        images = ImageStack.empty(1,0);
        
        % Column vector of spots.
        spots = Spot.empty(0,1);
        
        % Map this channel onto another channel.
        alignedTo = struct( ...
            'channel', Channel.empty, ... % Handle to channel to which this channel is aligned.
            'registration', ImageRegistration ... % Transforms this obj onto alignedTo.channel.
            );
        
        % Parent experiment handle.
        parentExperiment = Experiment.empty;
        
        % Selected image (and frame index). Should reference one of the
        % channel's images.
        selectedImage = ImageStack.empty;
        selectedImageFrameIndex = 0;
        
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
    end
    
    events
        ImagesChanged
        SpotsChanged
        AlignedToChanged
        ParentExperimentChanged
        SelectedImageChanged
        SelectedImageFrameChanged
        SelectedSpotChanged
        SelectedProjectionImageStackChanged
    end
    
    methods
        function obj = Channel()
            %CHANNEL Constructor.
            
            % Default to first stack with multiple frames.
            if isempty(obj.selectedProjectionImageStack)
                for im = obj.images
                    if im.numFrames() > 1
                        obj.selectedProjectionImageStack = im;
                        break
                    end
                end
            end
        end
        
        function set.images(obj, images)
            obj.images = images;
            notify(obj, 'ImagesChanged');
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
        
        function set.parentExperiment(obj, h)
            obj.parentExperiment = h;
            if ~isempty(obj.parentExperiment) && ~any(obj.parentExperiment.channels == obj)
                obj.parentExperiment.channels = [obj.parentExperiment.channels obj];
            end
            notify(obj, 'ParentExperimentChanged');
        end
        
        function set.selectedImage(obj, h)
            if ~isempty(h) && ~isempty(obj.images) && any(obj.images == h) && ~isequal(obj.selectedImage, h)
                obj.selectedImage = h;
                notify(obj, 'SelectedImageChanged');
            elseif ~isempty(obj.selectedImage) && ~any(obj.images == obj.selectedImage)
                obj.selectedImage = ImageStack.empty;
                notify(obj, 'SelectedImageChanged');
            end
        end
        
        function setSelectedImage(obj, h)
            % because setters are not valid callbacks
            obj.selectedImage = h;
        end
        
        function set.selectedImageFrameIndex(obj, t)
            if ~isempty(obj.selectedImage)
                obj.selectedImageFrameIndex = max(1, min(t, obj.selectedImage.numFrames()));
                notify(obj, 'SelectedImageFrameChanged');
            end
        end
        
        function set.selectedSpot(obj, h)
            obj.selectedSpot = h;
            notify(obj, 'SelectedSpotChanged');
            if obj.autoSelectAlignedSpotsInOtherChannels && ~isempty(obj.parentExperiment)
                obj.selectAlignedSpotsInOtherChannels();
            end
        end
        
        function selectAlignedSpotsInOtherChannels(obj)
            idx = [];
            if ~isempty(obj.selectedSpot) && ~isempty(obj.spots)
                idx = find(obj.spots == obj.selectedSpot, 1);
            end
            nspots = numel(obj.spots);
            for channel = obj.getOtherChannelsInParentExperiment()
                if isequal(channel, obj)
                    continue
                end
                tmp = channel.autoSelectAlignedSpotsInOtherChannels;
                channel.autoSelectAlignedSpotsInOtherChannels = false;
                if isempty(obj.selectedSpot)
                    % clear selected spot in all channels
                    channel.selectedSpot = Spot.empty;
                else
                    if isempty(idx) || nspots == 0 || nspots ~= numel(channel.spots)
                        isMapped = false;
                    else
                        xy = obj.getOtherChannelSpotsInLocalCoords(channel, channel.spots(idx).xy);
                        d2 = sum((xy - obj.selectedSpot.xy).^2);
                        % only considered to be mapped if locations are
                        % closely aligned
                        isMapped = d2 <= 3^2;
                    end
                    if isMapped
                        % show the mapped spot in channel
                        channel.selectedSpot = channel.spots(idx);
                    else
                        % select aligned location in channel
                        alignedSpot = Spot;
                        alignedSpot.xy = channel.getOtherChannelSpotsInLocalCoords(obj, obj.selectedSpot.xy);
                        channel.selectedSpot = alignedSpot;
                    end
                end
                channel.autoSelectAlignedSpotsInOtherChannels = tmp;
            end
        end
        
        function set.selectedProjectionImageStack(obj, h)
            if ~isempty(h) && ~isempty(obj.images) && any(obj.images == h)
                if ~isequal(obj.selectedProjectionImageStack, h)
                    obj.selectedProjectionImageStack = h;
                    notify(obj, 'SelectedProjectionImageStackChanged');
                end
            else
                prev = obj.selectedProjectionImageStack;
                obj.selectFirstValidProjectionImageStack();
                if ~isequal(prev, obj.selectedProjectionImageStack)
                    notify(obj, 'SelectedProjectionImageStackChanged');
                end
            end
        end
        
        function selectFirstValidProjectionImageStack(obj)
            for im = obj.images
                if im.numFrames() > 1
                    obj.selectedProjectionImageStack = im;
                    return
                end
            end
            obj.selectedProjectionImageStack = ImageStack.empty;
        end
        
        function setSelectedProjectionImageStack(obj, h)
            % because setters are not valid callbacks
            obj.selectedProjectionImageStack = h;
        end
        
        function channels = getOtherChannelsInParentExperiment(obj)
            channels = Channel.empty(1,0);
            if ~isempty(obj.parentExperiment)
                channels = setdiff(obj.parentExperiment.channels, obj);
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
        
        function copyAlignedSpotsToOtherChannel(obj, channel)
            xy = vertcat(obj.spots.xy);
            nspots = numel(obj.spots);
            xy = channel.getOtherChannelSpotsInLocalCoords(obj, xy);
            newSpots = Spot.empty;
            newSpots(nspots,1) = Spot;
            for i = 1:nspots
                newSpots(i,1).xy = xy(i,:);
            end
            channel.spots = newSpots;
        end
        
        function copyAlignedSpotsToAllOtherChannels(obj)
            otherChannels = obj.getOtherChannelsInParentExperiment();
            xy = vertcat(obj.spots.xy);
            nspots = numel(obj.spots);
            for channel = otherChannels
                cxy = channel.getOtherChannelSpotsInLocalCoords(obj, xy);
                newSpots = Spot.empty;
                newSpots(nspots,1) = Spot;
                for i = 1:nspots
                    newSpots(i,1).xy = cxy(i,:);
                end
                channel.spots = newSpots;
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

