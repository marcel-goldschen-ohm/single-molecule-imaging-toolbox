classdef (ConstructOnLoad) TimeSeriesExt < handle
    %TIMESERIESEXT Time series data with offset, scaling and masking.
    %   Adjustments to raw data are stored separately.
    %   Also stores named data point selections.
    %   !!! Time series data MUST be column data.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % raw data is MATLAB timeseries object
        raw = timeseries;
        
        % optionally store sample interval instead of explicit time array
        sampleInterval = 1;
        
        % offset, scaling and masking of raw data
        offset = 0; % 1x1 OR size(raw.data)
        scale = 1; % 1x1 OR size(raw.data)
        isMasked = false; % 1x1 OR size(raw.data)
        
        % map of named selections (logical or indices)
        % (built in constructor)
        selections
        
        % model of time series data (generic struct for flexibility)
        % e.g. Markov model
        model = struct();
        
        % idealized data
        % e.g. from above model
        ideal = timeseries;
        
        % known data (e.g. from simulation)
        % for comparison with model idealization
        known = timeseries;
    end
    
    properties (Dependent)
        time % time array (same size as raw.data)
        data % offset and scaled raw.data
        mask % logical mask array (same size as data)
        maskedData % data with masked points set to nan
        
        % raw timeseries meta data
        name
        timeUnits
        dataUnits
        timeInfo
        dataInfo
    end
    
    methods
        function this = TimeSeriesExt()
            %TIMESERIESEXT Constructor.
            
            this.selections = containers.Map();
        end
        
        function set.time(this, x)
            if isempty(x)
                this.sampleInterval = 1;
            elseif numel(x) == 1
                this.sampleInterval = x;
            else
                this.raw.time = x;
                this.sampleInterval = [];
            end
        end
        function set.data(this, y)
            this.raw.data = y;
            this.offset = 0;
            this.scale = 1;
        end
        function x = get.time(this)
            if numel(this.sampleInterval) == 1
                x = (0:size(this.raw.data, 1)-1)' .* this.sampleInterval;
            else
                x = this.raw.time;
                if isempty(x)
                    x = (0:size(this.raw.data, 1)-1)';
                end
            end
        end
        function y = get.data(this)
            y = this.raw.data;
            if isempty(y)
                return
            end
            if any(this.offset ~= 0)
                y = y + this.offset;
            end
            if any(this.scale ~= 1)
                y = y .* this.scale;
            end
        end
        
        function mask = get.mask(this)
            if isempty(this.isMasked)
                mask = [];
            elseif numel(this.isMasked) == 1
                if this.isMasked
                    mask = true(size(this.raw.data));
                else
                    mask = false(size(this.raw.data));
                end
            else
                mask = this.isMasked; % Should be same size as raw.data.
            end
        end
        function y = get.maskedData(this)
            y = this.data;
            if isempty(y) || ~any(this.isMasked)
                return
            end
            if numel(this.isMasked) == 1
                y = nan(size(y));
                return
            end
            y(this.isMasked) = nan;
        end
        
        function name = get.name(this)
            name = this.raw.Name;
        end
        function set.name(this, name)
            this.raw.Name = name;
        end
        function editName(this)
            answer = inputdlg({'Name:'}, 'TimeSeriesExt.name', 1, {char(this.name)});
            if isempty(answer)
                return
            end
            this.name = answer{1};
        end
        
        function units = get.timeUnits(this)
            units = this.raw.TimeInfo.Units;
        end
        function units = get.dataUnits(this)
            units = this.raw.DataInfo.Units;
        end
        function set.timeUnits(this, units)
            this.raw.TimeInfo.Units = units;
        end
        function set.dataUnits(this, units)
            this.raw.DataInfo.Units = units;
        end
        function editDataUnits(this)
            answer = inputdlg({['Data Units (' char(this.dataUnits) '):'], 'Scale By:'}, ...
                'TimeSeriesExt.dataUnits', 1, {char(this.dataUnits), '1'});
            if isempty(answer)
                return
            end
            scaleBy = str2num(answer{2});
            this.raw.data = this.raw.data .* scaleBy;
            this.offset = this.offset .* scaleBy;
            this.ideal.data = this.ideal.data .* scaleBy;
            this.dataUnits = answer{1};
        end
        
        function meta = get.timeInfo(this)
            meta = this.raw.TimeInfo;
        end
        function meta = get.dataInfo(this)
            meta = this.raw.DataInfo;
        end
        function set.timeInfo(this, meta)
            this.raw.TimeInfo = meta;
        end
        function set.dataInfo(this, meta)
            this.raw.DataInfo = meta;
        end
        
        % cell array of nonmasked data segments
        % !!! currenlty ONLY works for 1-D arrays
        function [xsegs, ysegs] = getNonMaskedDataSegments(this)
            if ~any(this.isMasked)
                xsegs = {this.time};
                ysegs = {this.data};
                return
            end
            if numel(this.isMasked) == 1
                xsegs = {};
                ysegs = {};
                return
            end
            x0 = this.time;
            y0 = this.maskedData;
            [ysegs, segIdxs] = TimeSeriesExt.getNonNanSegments(y0);
            xsegs = {};
            for k = 1:numel(segIdxs)
                xsegs{k} = x0(segIdxs{k});
            end
        end
    end
    
    methods (Static)
%         function this = loadobj(s)
%             this = Utilities.loadobj(TimeSeriesExt, s);
%         end
        
        function [segments, segmentIndices] = getNonNanSegments(dataWithNan)
            % return cell array of non-nan subarrays
            dataWithNan = reshape(dataWithNan, [], 1);
            tf = isnan(dataWithNan);
            segmentLengths = diff(find([1; diff(tf); 1]));
            segmentStartIndices = [1; 1+cumsum(segmentLengths(1:end-1))];
            segments = mat2cell(dataWithNan, segmentLengths(:));
            % remove nan segments
            if tf(1)
                segments(1:2:end) = [];
                segmentStartIndices(1:2:end) = [];
            else
                segments(2:2:end) = [];
                segmentStartIndices(2:2:end) = [];
            end
            segmentIndices = {};
            for k = 1:numel(segments)
                n = length(segments{k});
                i = segmentStartIndices(k);
                segmentIndices{k} = i:i+n-1;
            end
            
        end
        
        function [x, y, isMasked] = sumEveryN(N, x, y, isMasked)
            % integer N > 1
            n = floor(double(length(x)) / N);
            x = x(1:N:n*N);
            n = floor(double(length(y)) / N);
            y0 = y;
            y = y0(1:N:n*N);
            for k = 2:N
                y = y + y0(k:N:n*N);
            end
            if exist('isMasked', 'var')
                n = floor(double(length(isMasked)) / N);
                if all(isMasked)
                    isMasked = true(n,1);
                elseif ~any(isMasked)
                    isMasked = false(n,1);
                else
                    isMasked = any(reshape(isMasked(1:n*N), N, n), 1)';
                end
            end
        end
        
        function [x, y] = downsample(N, x, y)
            % integer N > 1
            x = downsample(x, N);
            y = decimate(y, N);
        end
        
        function [x, y] = upsample(N, x, y)
            % integer N > 1
            dx = diff(x);
            dx(end+1) = dx(end); % assume same sample interval for last point
            x0 = x;
            x = upsample(x, N);
            for k = 2:N
                x(k:N:end) = x0 + dx .* (double(k-1) / N);
            end
            y = interp(y, N);
        end
        
        function [x, y] = resample(N, x, y)
            ts = timeseries(y, x);
            if isempty(x)
                x = 1:N:length(y);
            elseif N > 1
                x = downsample(x, N);
            elseif N < 1
                dx = diff(x);
                dx(end+1) = dx(end); % assume same sample interval for last point
                x0 = x;
                x = upsample(x, 1.0 / N);
                for k = 2:N
                    x(k:N:end) = x0 + dx .* (double(k-1) / N);
                end
            end
            ts = resample(ts, x);
            y = ts.Data;
        end

        function ts = readHEKA(filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uigetfile('*.*', 'Open HEKA data file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            [path, file, ext] = fileparts(filepath);
            % load HEKA data
            try
                heka = HEKA_Importer(filepath);
            catch
                warndlg("!!! Requires package 'HEKA Patchmaster Importer' by Christian Keine. Find in MATLAB's Add-On Explorer.", ...
                    'HEKA file loader');
                return
            end
            nrecordings = size(heka.RecTable,1);
            % info for each recording are in the nonempty leaves of dataTree
            recdata = heka.trees.dataTree(:,end);
            clip = [];
            for i = 1:numel(recdata)
                if isempty(recdata{i})
                    clip = [clip i];
                end
            end
            recdata(clip) = [];
            if numel(recdata) ~= nrecordings
                warndlg('Unexpected data structure. Please report this error.');
                return
            end
            if nrecordings > 1
                % Ask which recordings to load. Loading multiple recordings is
                % allowed provided they have the same channels.
                stimuli = {};
                for rec = 1:nrecordings
                    stimuli{rec} = heka.RecTable.Stimulus{rec};
                end
                selrec = listdlg('ListString', stimuli, ...
                    'PromptString', 'Select recordings to load:');
            else
                selrec = 1;
            end
            nchannels = numel(heka.RecTable.dataRaw{selrec(1)});
            for i = 2:numel(selrec)
                if nchannels ~= numel(heka.RecTable.dataRaw{selrec(i)}) ...
                        || ~isequal(heka.RecTable.ChName{selrec(1)}, heka.RecTable.ChName{selrec(i)})
                    warndlg('Selected recordings do NOT have the same channels, and cannot be loaded together.');
                    return
                end
            end
            ts = {};
            for i = 1:numel(selrec)
                rec = selrec(i);
                nsweeps = size(heka.RecTable.dataRaw{rec}{1},2);
                %npts = size(heka.RecTable.dataRaw{rec}{1},1);
                ts{i} = repmat(TimeSeriesExt, nsweeps, nchannels);
                for sweep = 1:nsweeps
                    for channel = 1:nchannels
                        ts{i}(sweep,channel).sampleInterval = recdata{rec}.TrXInterval;
                        ts{i}(sweep,channel).data = heka.RecTable.dataRaw{rec}{channel}(:,sweep);
                        ts{i}(sweep,channel).timeUnits = string(heka.RecTable.TimeUnit{rec}{channel});
                        ts{i}(sweep,channel).dataUnits = string(heka.RecTable.ChUnit{rec}{channel});
                        ts{i}(sweep,channel).name = string(heka.RecTable.ChName{rec}{channel});
                    end
                end
            end
        end
    end
end

