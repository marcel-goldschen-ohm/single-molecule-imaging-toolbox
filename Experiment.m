classdef Experiment < handle
    %EXPERIMENT All data for a single-molecule imaging experiment.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        uid = []; % unique ID
        notes = '';
        hChannels = Channel.empty(1,0); % row vector of channels
        
        selectedSpotIndex = [];
        spotSelectionTagsMask = string.empty; % select only spots with any of these tags
        applySpotSelectionTagsMask = true;
        
        % Generic container for time series model info and params.
        tsModel = struct( ...
            'name', 'DISC', ...
            'alpha', 0.05, ...
            'divInformationCriterion', 'BIC-GMM', ...
            'aggInformationCriterion', 'BIC-GMM', ...
            'numViterbiIterations', 2 ...
            );
    end
    
    events
        SelectedSpotIndexChanged
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Constructor.
        end
        
        function setNotes(obj, str)
            obj.notes = str;
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
        
        function set.hChannels(obj, h)
%             % Remove link to parent experiment for previous channels.
%             if ~isempty(obj.hChannels)
%                 for hChannel = obj.hChannels
%                     hChannel.hExperiment = Experiment.empty;
%                 end
%             end
            % Make sure each channel's parent experiment refers to obj.
            obj.hChannels = h;
            if ~isempty(obj.hChannels)
                for hChannel = obj.hChannels
                    hChannel.hExperiment = obj;
                end
            end
        end
        
        function set.selectedSpotIndex(obj, k)
            % Selects indexed spot in all channels.
            
            % # spots for each channel
            numSpots = arrayfun(@(hChannel) numel(hChannel.hSpots), obj.hChannels);
            % max # spots across channels
            [numSpotsMax, cmax] = max(numSpots);
            % nothing
            if isempty(k) || isempty(numSpots) || numSpotsMax == 0
                obj.selectedSpotIndex = [];
                notify(obj, 'SelectedSpotIndexChanged');
                return
            end
            % constrain to valid index
            k = max(1, min(k, numSpotsMax));
            % select spot in each channel that has enough spots
            hChannel = obj.hChannels(cmax);
            if hChannel.autoSelectMappedSpotsInSiblingChannels
                hChannel.hSelectedSpot = hChannel.hSpots(k);
            else
                for c = 1:numel(obj.hChannels)
                    hChannel = obj.hChannels(c);
                    if numSpots(c) >= k
                        hChannel.hSelectedSpot = hChannel.hSpots(k);
                    else
                        hChannel.hSelectedSpot = Spot.empty;
                    end
                end
            end
            obj.selectedSpotIndex = k;
            notify(obj, 'SelectedSpotIndexChanged');
        end
        function prevSpot(obj)
            % # spots for each channel
            numSpots = arrayfun(@(hChannel) numel(hChannel.hSpots), obj.hChannels);
            % max # spots across channels
            [numSpotsMax, cmax] = max(numSpots);
            % no spots?
            if numSpotsMax == 0
                obj.selectedSpotIndex = [];
                return
            end
            if isempty(obj.selectedSpotIndex)
                % back from end
                k = numSpotsMax;
            else
                % prev valid index
                k = max(1, min(obj.selectedSpotIndex - 1, numSpotsMax));
            end
            if isempty(obj.spotSelectionTagsMask)
                obj.selectedSpotIndex = k;
            else
                % find prev spot (any channel) whose tags intersect the mask tags
                while k >= 1
                    for c = 1:numel(obj.hChannels)
                        hChannel = obj.hChannels(c);
                        if numSpots(c) >= k
                            if ~isempty(intersect(obj.spotSelectionTagsMask, hChannel.hSpots(k).tags))
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
            numSpots = arrayfun(@(hChannel) numel(hChannel.hSpots), obj.hChannels);
            % max # spots across channels
            [numSpotsMax, cmax] = max(numSpots);
            % no spots?
            if numSpotsMax == 0
                obj.selectedSpotIndex = [];
                return
            end
            if isempty(obj.selectedSpotIndex)
                % start from beginning
                k = 1;
            else
                % next valid index
                k = max(1, min(obj.selectedSpotIndex + 1, numSpotsMax));
            end
            if isempty(obj.spotSelectionTagsMask)
                obj.selectedSpotIndex = k;
            else
                % find next spot (any channel) whose tags intersect the mask tags
                while k <= numSpotsMax
                    for c = 1:numel(obj.hChannels)
                        hChannel = obj.hChannels(c);
                        if numSpots(c) >= k
                            if ~isempty(intersect(obj.spotSelectionTagsMask, hChannel.hSpots(k).tags))
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
            elseif isstring(model) || ischar(model)
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
            newmodel.divInformationCriterion = "BIC-GMM";
            newmodel.aggInformationCriterion = "BIC-GMM";
            newmodel.numViterbiIterations = 1;
            try
                alpha = obj.tsModel.alpha;
                if alpha > 0 && alpha < 1
                    newmodel.alpha = alpha;
                end
            catch
            end
            ICs = ["AIC-GMM", "BIC-GMM", "BIC-RSS", "HQC-GMM", "MDL", "DIC"];
            try
                divIC = string(obj.tsModel.divInformationCriterion);
                if any(ICs == divIC)
                    newmodel.divInformationCriterion = divIC;
                end
            catch
            end
            try
                aggIC = string(obj.tsModel.aggInformationCriterion);
                if any(ICs == aggIC)
                    newmodel.aggInformationCriterion = aggIC;
                end
            catch
            end
            try
                newmodel.numViterbiIterations = obj.tsModel.numViterbiIterations;
            catch
            end
            % params dialog
            dlg = dialog('Name', 'DISC');
            w = 400;
            lineh = 20;
            h = 4*lineh + 30;
            dlg.Position(3) = w;
            dlg.Position(4) = h;
            y = h - lineh;
            uicontrol(dlg, 'Style', 'text', 'String', 'Cutoff (alpha)', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [0, y, w/2, lineh]);
            uicontrol(dlg, 'Style', 'edit', 'String', num2str(newmodel.alpha), ...
                'Units', 'pixels', 'Position', [w/2, y, w/2, lineh], ...
                'Callback', @setAlpha_);
            y = y - lineh;
            uicontrol(dlg, 'Style', 'text', 'String', 'Divisive Information Criterion', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [0, y, w/2, lineh]);
            uicontrol(dlg, 'Style', 'popupmenu', ...
                'String', ICs, ...
                'Value', find(ICs == newmodel.divInformationCriterion, 1), ...
                'Units', 'pixels', 'Position', [w/2, y, w/2, lineh], ...
                'Callback', @setDivIC_);
            y = y - lineh;
            uicontrol(dlg, 'Style', 'text', 'String', 'Agglomerative Information Criterion', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [0, y, w/2, lineh]);
            uicontrol(dlg, 'Style', 'popupmenu', ...
                'String', ICs, ...
                'Value', find(ICs == newmodel.aggInformationCriterion, 1), ...
                'Units', 'pixels', 'Position', [w/2, y, w/2, lineh], ...
                'Callback', @setAggIC_);
            y = y - lineh;
            uicontrol(dlg, 'Style', 'text', 'String', '# Viterbi Iterations', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [0, y, w/2, lineh]);
            uicontrol(dlg, 'Style', 'edit', 'String', num2str(newmodel.numViterbiIterations), ...
                'Units', 'pixels', 'Position', [w/2, y, w/2, lineh], ...
                'Callback', @setNumViteriIter_);
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
            function setDivIC_(s,e)
                newmodel.divInformationCriterion = string(s.String{s.Value});
            end
            function setAggIC_(s,e)
                newmodel.aggInformationCriterion = string(s.String{s.Value});
            end
            function setNumViteriIter_(s,e)
                newmodel.numViterbiIterations = str2num(s.String);
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

