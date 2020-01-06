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
        
        % STATE PROPERTIES
        
        % Selected spot index.
        selectedSpotIndex = [];
        
        % generic container for model info and params
        model = struct( ...
            'name', 'DISC', ...
            'alpha', 0.05, ...
            'informationCriterion', 'BIC-GMM' ...
            );
    end
    
    events
        IdChanged
        NotesChanged
        ChannelsChanged
        SelectedSpotIndexChanged
        ModelChanged
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Constructor.
        end
        
        function set.id(obj, id)
            obj.id = id;
            notify(obj, 'IdChanged');
        end
        
        function set.notes(obj, notes)
            obj.notes = notes;
            notify(obj, 'NotesChanged');
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
            if isempty(k) || isempty(nspots) || nspotsmax == 0
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
        function prevSpot(obj, tagsMask)
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
            if ~exist('tagsMask', 'var') || isempty(tagsMask)
                obj.selectedSpotIndex = k;
            else
                % find prev spot (any channel) whose tags intersect the mask tags
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
            if ~exist('tagsMask', 'var') || isempty(tagsMask)
                obj.selectedSpotIndex = k;
            else
                % find next spot (any channel) whose tags intersect the mask tags
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
        
        function set.model(obj, model)
            if isstruct(model)
                obj.model = model;
            else % assume model is a string or char name
                obj.model.name = string(model);
                obj.editModelParams();
            end
            notify(obj, 'ModelChanged');
        end
        function editModelParams(obj)
            if ~isfield(obj.model, 'name') || isempty(obj.model.name)
                return
            end
            if obj.model.name == "DISC"
                obj.editDiscModelParams();
            end
        end
        function editDiscModelParams(obj)
            % default params
            newmodel.name = 'DISC';
            newmodel.alpha = 0.05;
            newmodel.informationCriterion = "BIC-GMM";
            try
                alpha = obj.model.alpha;
                if alpha > 0 && alpha < 1
                    newmodel.alpha = alpha;
                end
            catch
            end
            ICs = ["AIC-GMM", "BIC-GMM", "BIC-RSS", "HQC-GMM", "MDL"];
            try
                IC = string(obj.model.informationCriterion);
                if any(ICs == IC)
                    newmodel.informationCriterion = IC;
                end
            catch
            end
            % params dialog
            dlg = dialog('Name', 'DISC');
            w = 200;
            lh = 20;
            h = 2*lh + 30;
            dlg.Position(3) = w;
            dlg.Position(4) = h;
            y = h - lh;
            uicontrol(dlg, 'Style', 'text', 'String', 'alpha', ... % char(hex2dec('03b1'))
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [0, y, w/2, lh]);
            uicontrol(dlg, 'Style', 'edit', 'String', num2str(newmodel.alpha), ...
                'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
                'Callback', @setAlpha_);
            y = y - lh;
            uicontrol(dlg, 'Style', 'text', 'String', 'Information Criterion', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [0, y, w/2, lh]);
            uicontrol(dlg, 'Style', 'popupmenu', ...
                'String', ICs, ...
                'Value', find(ICs == newmodel.informationCriterion, 1), ...
                'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
                'Callback', @setInformationCriterion_);
            y = 0;
            uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
                'Units', 'pixels', 'Position', [w/2-55, y, 50, 30], ...
                'Callback', @ok_);
            uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
                'Units', 'pixels', 'Position', [w/2+5, y, 50, 30], ...
                'Callback', 'delete(gcf)');
            uiwait(dlg);
            function setAlpha_(s,e)
                newmodel.alpha = str2num(s.String);
            end
            function setInformationCriterion_(s,e)
                newmodel.informationCriterion = string(s.String{s.Value});
            end
            function ok_(varargin)
                obj.model = newmodel;
                % close dialog
                delete(dlg);
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(Experiment(), s);
        end
    end
end

