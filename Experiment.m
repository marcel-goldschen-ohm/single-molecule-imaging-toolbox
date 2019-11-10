classdef (ConstructOnLoad) Experiment < handle
    %EXPERIMENT Data for an entire single-molecule imaging experiment.
    %   - Array of channels with associated image stacks and spots.
    %   - Aligned spots across all channels.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        notes = '';
        
        % array of channel data
        channels = Channel.empty;
        
        % [#spots x #channels] matrix of spots
        alignedSpots = Spot.empty;
    end
    
    properties (Access = private)
        % working dir
        wd = pwd();
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Construct an instance of this class
            %   Detailed explanation goes here
        end
        
        function addChannel(obj, channel)
            obj.channels = [obj.channels channel];
            channel.experiment = obj;
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Experiment(), s);
        end
    end
end

