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
    end
    
    methods(Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Channel(), s);
        end
    end
end

