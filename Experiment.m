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
        
        % BELOW PROPERTIES ARE PRIMARILY FOR THE USER INTERFACE
        % THEY MOSTLY JUST REFER TO THE ABOVE DATA PROPERTIES
        
        % Selected spot index.
        selectedSpotIndex = [];
    end
    
    events
        ChannelsChanged
        SelectedSpotIndexChanged
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Constructor.
        end
        
        function set.channels(obj, channels)
            % Make sure each channel's parent experiment refers to obj.
            obj.channels = channels;
            for channel = channels
                channel.Parent = obj;
            end
            notify(obj, 'ChannelsChanged');
        end
        
        function set.selectedSpotIndex(obj, k)
            nspots = arrayfun(@(channel) numel(channel.spots), obj.channels);
            nspotsmax = max(nspots);
            if isempty(k) || nspotsmax == 0
                obj.selectedSpotIndex = [];
                notify(obj, 'SelectedSpotIndexChanged');
                return
            end
            k = max(1, min(k, nspotsmax));
            for c = 1:numel(obj.channels)
                channel = obj.channels(c);
                if nspots(c) >= k
                    channel.selectedSpot = channel.spots(k);
                else
                    channel.selectedSpot = Spot.empty;
                end
            end
            obj.selectedSpotIndex = k;
            notify(obj, 'SelectedSpotIndexChanged');
        end
        
        function prevSpot(obj, tagsMask)
            nspots = arrayfun(@(channel) numel(channel.spots), obj.channels);
            nspotsmax = max(nspots);
            if nspotsmax == 0
                obj.selectedSpotIndex = [];
                return
            end
            if isempty(obj.selectedSpotIndex)
                k = nspotsmax;
            else
                k = max(1, min(obj.selectedSpotIndex - 1, nspotsmax));
            end
            if ~exist('tagsMask', 'var') || isempty(tagsMask)
                obj.selectedSpotIndex = k;
            else
                while k >= 1
                    for c = 1:numel(obj.channels)
                        channel = obj.channels(c);
                        if nspots(c) >= k
                            if ~isempty(intersect(tagsMask, channel.spots(k).tags))
                                obj.selectedSpotIndex = k;
                                return
                            end
                        end
                    end
                    k = k - 1;
                end
            end
        end
        
        function nextSpot(obj, tagsMask)
            nspots = arrayfun(@(channel) numel(channel.spots), obj.channels);
            nspotsmax = max(nspots);
            if nspotsmax == 0
                obj.selectedSpotIndex = [];
                return
            end
            if isempty(obj.selectedSpotIndex)
                k = 1;
            else
                k = max(1, min(obj.selectedSpotIndex + 1, nspotsmax));
            end
            if ~exist('tagsMask', 'var') || isempty(tagsMask)
                obj.selectedSpotIndex = k;
            else
                while k <= nspotsmax
                    for c = 1:numel(obj.channels)
                        channel = obj.channels(c);
                        if nspots(c) >= k
                            if ~isempty(intersect(tagsMask, channel.spots(k).tags))
                                obj.selectedSpotIndex = k;
                                return
                            end
                        end
                    end
                    k = k + 1;
                end
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Experiment(), s);
        end
    end
end

