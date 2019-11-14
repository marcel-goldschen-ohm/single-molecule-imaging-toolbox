classdef Channel < handle
    %CHANNEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        label = "Channel";
        color = [0 1 0]; % [r g b]
        notes = '';
        
        % a collection of images or image stacks for this channel
        % e.g. main image stack, spot mask image, alignment image, etc.
        images = ImageStack.empty;
        
        % map this channel onto another channel
        alignedToChannel = Channel.empty;
        alignment = ImageRegistration;
        
        % array of spots
        spots = Spot.empty;
        
        % parent experiment handle
        experiment = Experiment.empty;
        
        % handle to selected image
        selectedImage = ImageStack.empty;
    end
    
    methods
        function obj = Channel()
            %CHANNEL Construct an instance of this class
            %   Detailed explanation goes here
        end
        
        function channels = getOtherChannelsInExperiment(obj)
            channels = Channel.empty;
            if ~isempty(obj.experiment)
                channels = setdiff(obj.experiment.channels, obj);
            end
        end
        
        function alignToChannel(obj, channel, method)
            if ~isempty(channel) && ~isempty(channel.alignedToChannel) && channel.alignedToChannel == obj
                warndlg({[char(channel.label) ' is already aligned to ' char(obj.label)], ...
                    ['Aligning ' char(obj.label) ' to ' char(channel.label) ' would result in a cyclic alignment loop.'], ...
                    'This is not allowed.'}, ...
                    'Cyclic Alignment Attempt');
                return
            end
            obj.alignedToChannel = channel;
            obj.alignment = ImageRegistration;
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
                disp('align images'); % TODO
            elseif method == "spots"
                disp('align spots'); % TODO
            elseif method == "identical"
                obj.alignment = ImageRegistration;
            end
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Channel(), s);
        end
    end
end

