classdef Channel < handle
    %CHANNEL Collection of images (stacks) and associated spots.
    %   Images may also be aligned to images in another channel.
    
    properties
        hExperiment = Experiment.empty; % parent experiment
        label = "Channel";
        
        hImages = ImageStack.empty(1,0); % row vector of image (stacks)
        hProjectionImageStack = ImageStack.empty;
        
        hSpots = Spot.empty(0,1); % column vector of spots
        hSelectedSpot = Spot.empty;
        autoSelectMappedSpotsInSiblingChannels = true;
        
        hAlignedToChannel = Channel.empty; % map obj onto hAlignedToChannel
        alignmentTransform = []; % transforms obj --> hAlignedToChannel, e.g. affine2d
        
        hOverlayChannel = Channel.empty; % overlay another channel (view only)
        overlayColorChannels = [2 1 2]; % green-magenta
        
        % spot time series options
        spotTsSumEveryN = 1; % e.g. simulate longer exposures
        spotTsFilter = digitalFilter.empty;
        spotTsApplyFilter = false;
    end
    
    events
        LabelChanged
        ImagesChanged
        ProjectionImageStackChanged
        SpotsChanged
        SelectedSpotChanged
        AlignmentChanged
        OverlayChanged
    end
    
    methods
        function obj = Channel()
            %CHANNEL Constructor.
        end
        
        function delete(obj)
            % If any other channels in the parent experiment refer to this
            % channel (e.g. alignment), remove the refs.
            hSiblingChannels = obj.getSiblingChannels();
            if ~isempty(hSiblingChannels)
                for hSiblingChannel = hSiblingChannels
                    if isvalid(hSiblingChannel)
                        if isequal(hSiblingChannel.hAlignedToChannel, obj)
                            hSiblingChannel.hAlignedToChannel = Channel.empty;
                        end
                        if isequal(hSiblingChannel.hOverlayChannel, obj)
                            hSiblingChannel.hOverlayChannel = Channel.empty;
                        end
                    end
                end
            end
        end
        
        function set.hExperiment(obj, h)
            obj.hExperiment = h;
            % make sure parent experiment's list of channels contains obj
            if ~isempty(obj.hExperiment) && ~any(obj.hExperiment.hChannels == obj)
                obj.hExperiment.hChannels = [obj.hExperiment.hChannels obj];
            end
        end
        
        function set.label(obj, str)
            obj.label = string(str);
            notify(obj, 'LabelChanged');
        end
        function editLabel(obj)
            answer = inputdlg({'Label'}, 'Channel Label', 1, {char(obj.label)});
            if isempty(answer)
                return
            end
            obj.label = string(answer{1});
        end
        
        function set.hImages(obj, h)
            obj.hImages = h;
            notify(obj, 'ImagesChanged');
%             if isempty(obj.selectedImage) && ~isempty(obj.images)
%                 obj.selectedImage = obj.images(1);
%             end
            % update projection image stack
            if isempty(obj.hImages)
                obj.hProjectionImageStack = ImageStack.empty;
            elseif isempty(obj.hProjectionImageStack) || ~any(obj.hImages == obj.hProjectionImageStack)
                obj.selectFirstValidProjectionImageStack();
            end
% %             % resetting these makes sure they remain valid
% %             obj.selectedImage = obj.selectedImage;
% %             obj.selectedProjectionImageStack = obj.selectedProjectionImageStack;
        end
        function set.hProjectionImageStack(obj, h)
            obj.hProjectionImageStack = h;
            notify(obj, 'ProjectionImageStackChanged');
        end
        function setProjectionImageStack(obj, h)
            obj.hProjectionImageStack = h;
        end
        function selectFirstValidProjectionImageStack(obj)
            if isempty(obj.hImages)
                obj.hProjectionImageStack = ImageStack.empty;
                return
            end
            for hImage = obj.hImages
                if hImage.numFrames > 1
                    obj.hProjectionImageStack = hImage;
                    return
                end
            end
            obj.hProjectionImageStack = ImageStack.empty;
        end
        
        function set.hSpots(obj, h)
            obj.hSpots = h;
            if ~isempty(obj.hSpots)
                [obj.hSpots.hChannel] = deal(obj);
            end
            notify(obj, 'SpotsChanged');
        end
        function set.hSelectedSpot(obj, h)
            if obj.autoSelectMappedSpotsInSiblingChannels && ~isempty(obj.hExperiment)
                hSiblingChannels = obj.getSiblingChannels();
                if ~isempty(hSiblingChannels)
                    obj.selectMappedSpotsInSiblingChannels(h, hSiblingChannels);
                end
            end
            obj.hSelectedSpot = h;
            if ~isempty(obj.hSelectedSpot)
                obj.hSelectedSpot.hChannel = obj;
            end
            notify(obj, 'SelectedSpotChanged');
        end
        
        function hSiblingChannels = getSiblingChannels(obj)
            % GETSIBLINGCHANNELS Get other channels in parent experiment.
            hSiblingChannels = Channel.empty(1,0);
            if ~isempty(obj.hExperiment) && isvalid(obj.hExperiment)
                hSiblingChannels = setdiff(obj.hExperiment.hChannels, obj);
            end
        end
        
        function hNewImage = loadNewImage(obj, filepath)
            %LOADNEWIMAGE Load new image stack from file.
            if ~exist('filepath', 'var')
                filepath = '';
            end
            hNewImage = ImageStack;
            hNewImage.load(filepath, '', [], [], true);
            if isempty(hNewImage.fileInfo)
                hNewImage = ImageStack.empty;
                return
            end
            [~, hNewImage.label, ~] = fileparts(hNewImage.fileInfo(1).Filename);
            obj.hImages = [obj.hImages hNewImage];
%             obj.selectedImage = hNewImage;
        end
        function removeImage(obj, hImage, ask)
            %REMOVEIMAGE Delete channel image.
            if isempty(obj.hImages)
                return
            end
            idx = find(obj.hImages == hImage, 1);
            if isempty(idx)
                return
            end
            if exist('ask', 'var') && ask
                if questdlg(['Remove image ' char(hImage.label) '?'], ...
                        'Remove image?', ...
                        'OK', 'Cancel', 'Cancel') == "Cancel"
                    return
                end
            end
            delete(hImage);
            obj.hImages(idx) = [];
        end
        function reloadAllMissingImages(obj)
            if ~isempty(obj.hImages)
                for hImage = obj.hImages
                    if isempty(hImage.data)
                        hImage.reload();
                    end
                end
            end
        end
        
        function setAlignmentToChannel(obj, hChannel, T)
            obj.hAlignedToChannel = hChannel;
            obj.alignmentTransform = T;
            notify(obj, 'AlignmentChanged');
        end
        function alignToChannel(obj, hChannel, method, movingImage, fixedImage)
            %ALIGNTOCHANNEL Align obj --> hChannel by images or spots
            if isempty(hChannel)
                obj.hAlignedToChannel = Channel.empty;
                return
            end
            % check for cyclic alignment
            if isequal(obj, hChannel.hAlignedToChannel)
                warndlg({[char(hChannel.label) ' is already aligned to ' char(obj.label)], ...
                    ['Aligning ' char(obj.label) ' to ' char(hChannel.label) ' would result in a cyclic alignment loop.'], ...
                    'This is not allowed.'}, ...
                    'Cyclic Alignment Attempt');
                return
            end
            % alignment method selection UI
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
            % alignment
            T = ob.alignmentTransform;
            if method == "images"
                if isempty(movingImage) || isempty(fixedImage)
                    warndlg('Requires inputting the moving and fixed images to be aligned.', 'No images given for alignment.');
                    return
                end
                %movingImage = imadjust(uint16(movingImage));
                %fixedImage = imadjust(uint16(fixedImage));
                registration = Utilities.registrationEstimatorAppWrapper(movingImage, fixedImage);
                if ~isempty(registration.transformation)
                    T = registration.transformation;
                end
            elseif method == "spots"
                % TODO
                warndlg('Aligning spots not yet implemented.', 'Coming Soon');
                return
            elseif method == "identical"
                T = [];
            end
            obj.setAlignmentToChannel(hChannel, T);
        end
        function T = getTransformationToAlignedCoords(obj)
            % Return 2D transformation to parent experiment (aligned) coordinates.
            T = [];
            hChannel = obj;
            while ~isempty(hChannel.hAlignedToChannel)
                if isempty(T)
                    T = hChannel.alignmentTransform;
                else
                    T.T = hChannel.alignmentTransform.T * T.T;
                end
                hChannel = hChannel.hAlignedToChannel;
            end
        end
        function im = getOtherChannelImageInLocalCoords(obj, hOtherhannel, im)
            T = Channel.getTransformationBetweenChannels(hOtherhannel, obj);
            if ~isempty(T)
                im =  imwarp(im, T, 'OutputView', imref2d(size(im)));
            end
        end
        function xy = getOtherChannelSpotsInLocalCoords(obj, hOtherhannel, xy)
            T = Channel.getTransformationBetweenChannels(hOtherhannel, obj);
            if ~isempty(T)
                xy = transformPointsForward(T, xy);
            end
        end
        function tf = areSpotsMappedToOtherChannelSpots(obj, hOtherhannel, dmax)
            if isempty(obj.hSpots) || isempty(hOtherhannel.hSpots) ...
                    || numel(obj.hSpots) ~= numel(hOtherhannel.hSpots)
                tf = false;
                return
            end
            if exist('dmax', 'var')
                xy = obj.getOtherChannelSpotsInLocalCoords(hOtherhannel, vertcat(hOtherhannel.hSpots.xy));
                d2 = sum((xy - vertcat(obj.hSpots.xy)).^2, 2);
                % only considered to be mapped if locations are closely aligned
                tf = all(d2 <= dmax^2);
            else
                tf = true;
            end
        end
        function selectMappedSpotsInSiblingChannels(obj, hSpot, hSiblingChannels)
            if ~exist('hSpot', 'var')
                hSpot = obj.hSelectedSpot;
            end
            if ~exist('hSiblingChannels', 'var')
                hSiblingChannels = obj.getSiblingChannels();
            end
            if isempty(hSiblingChannels)
                return
            end
            idx = [];
            if ~isempty(hSpot) && ~isempty(obj.hSpots)
                idx = find(obj.hSpots == hSpot, 1);
            end
            numSpots = numel(obj.hSpots);
            for hSiblingChannel = hSiblingChannels
                tmp = hSiblingChannel.autoSelectMappedSpotsInSiblingChannels;
                hSiblingChannel.autoSelectMappedSpotsInSiblingChannels = false;
                if isempty(hSpot)
                    % clear selected spot in sibling channel
                    hSiblingChannel.hSelectedSpot = Spot.empty;
                else
                    isMapped = ~isempty(idx) && numel(hSiblingChannel.hSpots) >= idx;
                    if isMapped
                        % select mapped spot in sibling channel
                        hSiblingChannel.hSelectedSpot = hSiblingChannel.hSpots(idx);
                    else
                        % select mapped location in sibling channel
                        mappedSpot = Spot;
                        mappedSpot.xy = hSiblingChannel.getOtherChannelSpotsInLocalCoords(obj, hSpot.xy);
                        hSiblingChannel.hSelectedSpot = mappedSpot;
                    end
                end
                hSiblingChannel.autoSelectMappedSpotsInSiblingChannels = tmp;
            end
        end
        
        function set.hOverlayChannel(obj, h)
            obj.hOverlayChannel = h;
            notify(obj, 'OverlayChanged');
        end
        function setOverlayChannel(obj, h)
            obj.hOverlayChannel = h;
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
            notify(obj, 'OverlayChanged');
        end
        function setOverlayColorChannels(obj, colors)
            obj.overlayColorChannels = colors;
        end
        
        function findSpotsInImage(obj, im, hPreviewImage)
            %   For a binary mask, call regionprops().
            %   For a grayscale image, find the local maxima.
            if isempty(im)
                return
            end
            if ~isempty(obj.hSpots)
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
                numSpots = numel(props);
                if numSpots
                    newSpots = Spot.empty(0,1);
                    newSpots(numSpots,1) = Spot;
                    for k = 1:numSpots
                        newSpots(k,1).xy = props(k).Centroid;
                        newSpots(k,1).props = props(k);
                    end
                    obj.hSpots = newSpots;
                else
                    obj.hSpots = Spot.empty(0,1);
                end
                close(wb);
            else
                xy = ImageOps.findMaximaPreview(im, [], [], 0, 0, hPreviewImage);
                numSpots = size(xy,1);
                if numSpots
                    newSpots = Spot.empty(0,1);
                    newSpots(numSpots,1) = Spot;
                    for k = 1:numSpots
                        newSpots(k,1).xy = xy(k,:);
                    end
                    obj.hSpots = newSpots;
                else
                    obj.hSpots = Spot.empty(0,1);
                end
            end
            if ~isempty(obj.hSpots)
                obj.hSelectedSpot = obj.hSpots(1);
            else
                obj.hSelectedSpot = Spot.empty;
            end
        end
        function clearSpots(obj)
            %CLEARSPOTS Delete all current spots.
            obj.hSpots = Spot.empty(0,1);
            obj.hSelectedSpot = Spot.empty;
        end
        function addSpot(obj, xy)
            %ADDSPOT Add a new spot at (x,y).
            newSpot = Spot;
            newSpot.xy = xy;
            obj.hSpots = [obj.hSpots; newSpot];
            obj.hSelectedSpot = newSpot;
            % add spot in all other 1 to 1 mapped channels?
            hSiblingChannels = obj.getSiblingChannels();
            if ~isempty(hSiblingChannels)
                %if questdlg('Add mapped spot to all other channels?', 'Add Spot') == "Yes"
                    for hSiblingChannel = hSiblingChannels
                        if obj.areSpotsMappedToOtherChannelSpots(hSiblingChannel)
                            newSpot = Spot;
                            newSpot.xy = hSiblingChannel.getOtherChannelSpotsInLocalCoords(obj, xy);
                            hSiblingChannel.hSpots = [hSiblingChannel.hSpots; newSpot];
                            hSiblingChannel.hSelectedSpot = newSpot;
                        end
                    end
                %end
            end
        end
        function removeSpot(obj, idx)
            %REMOVESPOT Delete spot(s).
            if any(obj.hSpots(idx) == obj.hSelectedSpot)
                obj.hSelectedSpot = Spot.empty;
            end
            delete(obj.hSpots(idx));
            obj.hSpots(idx) = [];
            % remove spot(s) from all other 1 to 1 mapped channels?
            hSiblingChannels = obj.getSiblingChannels();
            if ~isempty(hSiblingChannels)
                %if questdlg('Remove mapped spot(s) in all other channels?', 'Remove Spot') == "Yes"
                    for hSiblingChannel = hSiblingChannels
                        if obj.areSpotsMappedToOtherChannelSpots(hSiblingChannel)
                            if any(hSiblingChannel.hSpots(idx) == hSiblingChannel.hSelectedSpot)
                                hSiblingChannel.hSelectedSpot = Spot.empty;
                            end
                            delete(hSiblingChannel.hSpots(idx));
                            hSiblingChannel.hSpots(idx) = [];
                        end
                    end
                %end
            end
        end
        function copyMappedSpotsToOtherChannels(obj, hOtherChannels)
            if isempty(hOtherChannels)
                return
            end
            xy = vertcat(obj.hSpots.xy);
            numSpots = numel(obj.hSpots);
            for hOtherChannel = hOtherChannels
                cxy = hOtherChannel.getOtherChannelSpotsInLocalCoords(obj, xy);
                newSpots = Spot.empty(0,1);
                newSpots(numSpots,1) = Spot();
                for k = 1:numSpots
                    newSpots(k).xy = cxy(k,:);
                    newSpots(k).tags = obj.hSpots(k).tags;
                end
                hOtherChannel.hSpots = newSpots;
            end
        end
        function copyMappedSpotsToAllSiblingChannels(obj)
            obj.copyMappedSpotsToOtherChannels(obj.getSiblingChannels());
        end
        
        function set.spotTsSumEveryN(obj, N)
            obj.spotTsSumEveryN = N;
            if ~isempty(obj.hSelectedSpot)
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
            if ~isempty(obj.hSelectedSpot)
                notify(obj, 'SelectedSpotChanged');
            end
        end
        function editSpotTsDigitalFilter(obj)
            % launch MATLAB's digital filter designer
            % when complete this will put the designed digitalFilter object
            % in the base workspace ans variable
            designfilt();
            try
                filt = evalin('base', 'ans');
                if class(filt) == "digitalFilter"
                    obj.spotTsFilter = filt;
                end
            catch
            end
        end
        function toggleSpotTsApplyFilter(obj)
            obj.spotTsApplyFilter = ~obj.spotTsApplyFilter;
            if ~isempty(obj.hSelectedSpot)
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

