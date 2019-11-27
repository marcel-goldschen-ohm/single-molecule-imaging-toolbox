classdef Experiment < handle
    %EXPERIMENT Data for an entire single-molecule imaging experiment.
    %   Mostly just an array of channels with associated images and spots.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        notes = '';
        
        % Row vector of channels.
        channels = Channel.empty(1,0);
        
        % Flag indicating whether spots are aligned across channels or not.
        areSpotsAlignedAcrossChannels = false;
    end
    
%     properties (Access = private)
%         % working dir
%         wd = pwd();
%     end
    
    events
        ChannelsChanged
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Constructor.
        end
        
        function set.channels(obj, channels)
            % Make sure each channel's parentExperiment refers to obj.
            obj.channels = channels;
            for channel = channels
                channel.parentExperiment = obj;
            end
            notify(obj, 'ChannelsChanged');
        end
        
%         function tf = get.areSpotsAlignedAcrossChannels(obj)
%             tf = false;
%             if ~obj.areSpotsAlignedAcrossChannels
%                 return
%             end
%             % obj.areSpotsAlignedAcrossChannels == true
%             % double check that all channels have the same number of spots
%             nchannels = numel(obj.channels);
%             nspots = zeros(1, nchannels);
%             for c = 1:nchannels
%                 nspots(c) = numel(obj.channels(c).spots);
%             end
%             if all(nspots > 0) && all(diff(nspots) == 0)
%                 tf = true;
%             end
%         end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Experiment(), s);
        end
    end
end

