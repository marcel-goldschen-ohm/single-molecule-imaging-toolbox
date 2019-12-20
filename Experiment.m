classdef Experiment < handle
    %EXPERIMENT Data for an entire single-molecule imaging experiment.
    %   Mostly just an array of channels with associated images and spots.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % DATA PROPERTIES
        
        id = [];
        notes = '';
        
        % Row vector of channels.
        channels = Channel.empty(1,0);
        
        % USER INTERFACE PROPERTIES
        
        % Selected spot index.
        selectedSpotIndex = [];
        
        % Spot selection tags mask.
        % Navigation and selection will only involve spots with tags that
        % intersect these tags.
        spotTagsMask = string.empty;
    end
    
    events
        ChannelsChanged
        SelectedSpotIndexChanged
        SpotTagsMaskChanged
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Constructor.
        end
        
        function setNotes(obj, notes)
            obj.notes = notes;
        end
        function editNotes(obj)
            fig = figure('Name', 'Notes', ...
                'Menu', 'none', 'Toolbar', 'none', 'numbertitle', 'off');
            uicontrol(fig, ...
                'Style', 'edit', ...
                'Min', 0, ...
                'Max', 2, ...
                'String', obj.notes, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, 1], ...
                'HorizontalAlignment', 'left', ...
                'Callback', @(s,e) obj.setNotes(s.String));
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
            % Selects indexed spot in all channels.
            
            % # spots for each channel
            nspots = arrayfun(@(channel) numel(channel.spots), obj.channels);
            % max # spots across channels
            [nspotsmax, cmax] = max(nspots);
            % nothing
            if isempty(k) || nspotsmax == 0
                obj.selectedSpotIndex = [];
                notify(obj, 'SelectedSpotIndexChanged');
                return
            end
            % constrain to valid index
            k = max(1, min(k, nspotsmax));
            % select spot in each channel that has enough spots
            channel = obj.channels(cmax);
            if channel.autoSelectMappedSpotsInOtherChannels
                channel.selectedSpot = channel.spots(k);
            else
                for c = 1:numel(obj.channels)
                    channel = obj.channels(c);
                    if nspots(c) >= k
                        channel.selectedSpot = channel.spots(k);
                    else
                        channel.selectedSpot = Spot.empty;
                    end
                end
            end
            obj.selectedSpotIndex = k;
            notify(obj, 'SelectedSpotIndexChanged');
        end
        
        function set.spotTagsMask(obj, tags)
            if isempty(tags)
                obj.spotTagsMask = string.empty;
            elseif ischar(tags) || (isstring(tags) && numel(tags) == 1)
                obj.spotTagsMask = Spot.str2arr(tags, ',');
            elseif isstring(tags)
                obj.spotTagsMask = tags;
            else
                return
            end
            notify(obj, 'SpotTagsMaskChanged');
        end
        
        function prevSpot(obj)
            % # spots for each channel
            nspots = arrayfun(@(channel) numel(channel.spots), obj.channels);
            % max # spots across channels
            nspotsmax = max(nspots);
            % no spots?
            if nspotsmax == 0
                obj.selectedSpotIndex = [];
                return
            end
            if isempty(obj.selectedSpotIndex)
                % back from end
                k = nspotsmax;
            else
                % prev valid index
                k = max(1, min(obj.selectedSpotIndex - 1, nspotsmax));
            end
            if isempty(obj.spotTagsMask)
                obj.selectedSpotIndex = k;
            else
                % find prev spot (any channel) whose tags intersect the mask tags
                while k >= 1
                    for c = 1:numel(obj.channels)
                        channel = obj.channels(c);
                        if nspots(c) >= k
                            if ~isempty(intersect(obj.spotTagsMask, channel.spots(k).tags))
                                obj.selectedSpotIndex = k;
                                return
                            end
                        end
                    end
                    k = k - 1;
                end
            end
        end
        
        function nextSpot(obj)
            % # spots for each channel
            nspots = arrayfun(@(channel) numel(channel.spots), obj.channels);
            % max # spots across channels
            nspotsmax = max(nspots);
            % no spots?
            if nspotsmax == 0
                obj.selectedSpotIndex = [];
                return
            end
            if isempty(obj.selectedSpotIndex)
                % start from beginning
                k = 1;
            else
                % next valid index
                k = max(1, min(obj.selectedSpotIndex + 1, nspotsmax));
            end
            if isempty(obj.spotTagsMask)
                obj.selectedSpotIndex = k;
            else
                % find next spot (any channel) whose tags intersect the mask tags
                while k <= nspotsmax
                    for c = 1:numel(obj.channels)
                        channel = obj.channels(c);
                        if nspots(c) >= k
                            if ~isempty(intersect(obj.spotTagsMask, channel.spots(k).tags))
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

