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
        alignedTo = struct( ...
            'channel', Channel.empty, ...
            'registration', ImageRegistration ...
            );
        
        % array of spots
        spots = Spot.empty;
        
        % parent experiment handle
        experiment = Experiment.empty;
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
        
        function T = getTransformationToAlignedCoords(obj)
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
        
        function T = getTransformationFromAlignedChannelToLocalCoords(obj, channel)
            T = [];
            T1 = obj.getTransformationToAlignedCoords();
            T2 = channel.getTransformationToAlignedCoords();
            % T = inv(T1) * T2
            if ~isempty(T1) && ~isempty(T2)
                T = T2;
                T.T = invert(T1).T * T2.T;
            elseif ~isempty(T2)
                T = T2;
            elseif ~isempty(T1)
                T = invert(T1);
            end
        end
        
        function im = getAlignedImageInLocalCoords(obj, channel, im)
            T = obj.getTransformationFromAlignedChannelToLocalCoords(channel);
            if ~isempty(T)
                im =  imwarp(im, T, 'OutputView', imref2d(size(im)));
            end
        end
        
        function xy = getAlignedSpotsInLocalCoords(obj, channel, xy)
            T = obj.getTransformationFromAlignedChannelToLocalCoords(channel);
            if ~isempty(T)
                xy = transformPointsForward(T, xy);
            end
        end
        
%         function findColocalizedSpots(obj, channel, radius)
%             if ~exist('radius', 'var')
%                 radius = 2.5;
%             end
%             if isempty(obj.spots) || isempty(channel.spots)
%                 return
%             end
%             xy = vertcat(channel.spots.xy);
%             n = numel(channel.spots);
%             noncolocalized = [];
%             r2 = radius^2;
%             for i = 1:numel(obj.spots)
%                 d2 = sum((xy - repmat(obj.spots(i).xy, n, 1)).^2, 2);
%                 if ~any(d2 < r2)
%                     noncolocalized = [noncolocalized i];
%                 end
%             end
%             obj.spots(noncolocalized) = [];
%         end
    end
    
    methods(Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Channel(), s);
        end
    end
end

