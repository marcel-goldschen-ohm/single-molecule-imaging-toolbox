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
    end
    
    properties (Dependent)
        time % time array (same size as rawData)
        data % offset and scaled rawData
        mask % logical mask array (same size as data)
        maskedData % data with masked points set to nan
        
        % raw timeseries meta data
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
        
        function meta = get.timeInfo(this)
            meta = this.raw.TimeInfo;
        end
        function meta = get.dataInfo(this)
            meta = this.raw.DataInfo.Units;
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
            [ysegs, xsegidxs] = getNonNanSegments(y0);
            xsegs = {};
            for k = 1:numel(xsegidxs)
                xsegs{k} = x0(xsegidxs{k});
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
            idx = isnan(dataWithNan);
            segmentLengths = diff(find([1; diff(idx); 1]));
            segmentStartIndices = [1; cumsum(segmentLengths(1:end-1))];
            segments = mat2cell(dataWithNan, segmentLengths(:));
            % remove nan segments
            segments(2:2:end) = [];
            segmentStartIndices(2:2:end) = [];
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
                    isMasked0 = isMasked;
                    isMasked = false(n,N);
                    for k = 1:N
                        isMasked(:,k) = isMasked0(k:N:n*N);
                    end
                    isMasked = any(isMasked, 2);
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
    end
end

