classdef Experiment < handle
    %EXPERIMENT All data for a single-molecule imaging experiment.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % DATA PROPERTIES
        
        uid = [];
        notes = '';
        
        % Row vector of channels.
        channels = Channel.empty(1,0);
        
        % STATE PROPERTIES
        
        % Selected spot index.
        selectedSpotIndex = [];
        
        % Select only spots with any of these tags.
        spotSelectionTagsMask = string.empty;
        applySpotSelectionTagsMask = true;
        
        % Generic container for time series model info and params.
        tsModel = struct( ...
            'name', 'DISC', ...
            'alpha', 0.05, ...
            'informationCriterion', 'BIC-GMM' ...
            );
    end
    
    events
        SelectedSpotIndexChanged
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
                channel.experiment = obj;
            end
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
        
        function set.spotSelectionTagsMask(obj, tags)
            if isempty(tags)
                obj.spotSelectionTagsMask = string.empty;
            elseif ischar(tags) || (isstring(tags) && numel(tags) == 1)
                obj.spotSelectionTagsMask = Spot.str2arr(tags, ',');
            elseif isstring(tags)
                obj.spotSelectionTagsMask = tags;
            else
                return
            end
        end
        function setSpotSelectionTagsMask(obj, tags)
            obj.spotSelectionTagsMask = tags;
        end
        function str = getSpotSelectionTagsMaskString(obj)
            str = Spot.arr2str(obj.spotSelectionTagsMask, ",");
        end
        function setApplySpotSelectionTagsMask(obj, tf)
            obj.applySpotSelectionTagsMask = tf;
        end
        
        function set.tsModel(obj, model)
            if isstruct(model)
                obj.tsModel = model;
            else % assume model is a string or char name
                obj.tsModel.name = string(model);
                obj.editTsModelParams();
            end
        end
        function editTsModelParams(obj)
            if obj.tsModel.name == "DISC"
                obj.editDiscTsModelParams();
            end
        end
        function editDiscTsModelParams(obj)
            % default params
            newmodel.name = 'DISC';
            newmodel.alpha = 0.05;
            newmodel.informationCriterion = "BIC-GMM";
            try
                alpha = obj.tsModel.alpha;
                if alpha > 0 && alpha < 1
                    newmodel.alpha = alpha;
                end
            catch
            end
            ICs = ["AIC-GMM", "BIC-GMM", "BIC-RSS", "HQC-GMM", "MDL"];
            try
                IC = string(obj.tsModel.informationCriterion);
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
                obj.tsModel = newmodel;
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

