classdef TimeSeries
    %TIMESERIES Time series data.
    %   Adjustments to raw data are stored separately.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        rawTime = []; % special cases: [] => frames, dt => sample interval
        rawData = [];
        
        timeUnits = '';
        dataUnits = '';
        
        offset = 0; % 1x1 OR size(rawData)
        scale = 1; % 1x1 OR size(rawData)
        isMasked = false; % 1x1 OR size(rawData)
    end
    
    properties (Dependent)
        time % time array (same size as rawData)
        data % offset and scaled rawData
        mask % logical mask array (same size as data)
        maskedData % data with masked points set to nan
    end
    
    methods
        function obj = TimeSeries()
            %TIMESERIES Constructor.
        end
        
        function obj = set.rawTime(obj, x)
            obj.rawTime = reshape(x, [], 1);
        end
        function obj = set.rawData(obj, y)
            obj.rawData = reshape(y, [], 1);
        end
        
        function obj = set.time(obj, x)
            obj.rawTime = reshape(x, [], 1);
        end
        function obj = set.data(obj, y)
            obj.rawData = reshape(y, [], 1);
            obj.offset = 0;
            obj.scale = 1;
%             obj.sumEveryN = 1;
        end
        function x = get.time(obj)
            x = obj.rawTime;
            if isempty(x)
                % frames
                x = reshape(1:length(obj.rawData), [], 1);
            elseif numel(x) == 1
                % sample interval
                x = reshape(0:length(obj.rawData)-1, [], 1) .* x;
            end
%             if ~isempty(x) && obj.sumEveryN > 1
%                 n = obj.sumEveryN;
%                 x = x(1:n:end);
%             end
        end
        function y = get.data(obj)
            y = obj.rawData;
            if isempty(y)
                return
            end
            if any(obj.offset ~= 0)
                y = y + obj.offset;
            end
            if any(obj.scale ~= 1)
                y = y .* obj.scale;
            end
%             if ~isempty(y) && obj.sumEveryN > 1
%                 n = obj.sumEveryN;
%                 y0 = y;
%                 npts = int32(round(floor(double(length(y0)) / n) * n));
%                 y = y0(1:n:npts);
%                 for k = 2:n
%                     y = y + y0(k:n:npts);
%                 end
%             end
%             if ~isempty(obj.filter)
%                 y = filter(obj.filter, y);
%             end
        end
        
        function obj = set.offset(obj, offset)
            obj.offset = reshape(offset, [], 1);
        end
        function obj = set.scale(obj, scale)
            obj.scale = reshape(scale, [], 1);
        end
        
        function obj = set.isMasked(obj, tf)
            obj.isMasked = reshape(tf, [], 1);
        end
        function mask = get.mask(obj)
            if isempty(obj.isMasked)
                mask = [];
            elseif numel(obj.isMasked) == 1
                if obj.isMasked
                    mask = true(size(obj.rawData));
                else
                    mask = false(size(obj.rawData));
                end
            else
                mask = obj.isMasked; % Should be same size as rawData.
            end
        end
        function y = get.maskedData(obj)
            y = obj.data;
            if isempty(y) || ~any(obj.isMasked)
                return
            end
            if numel(obj.isMasked) == 1
                y = nan(size(y));
                return
            end
%             if obj.sumEveryN > 1
%                 n = obj.sumEveryN;
%                 npts = length(y);
%                 mask = false(npts, n);
%                 for k = 1:n
%                     mask(:,k) = obj.isMasked(k:n:npts);
%                 end
%                 mask = any(mask, 2);
%                 y(mask) = nan;
%             else
                y(obj.isMasked) = nan;
%             end
        end
        
        % cell array of nonmasked data segments
        function [xsegs, ysegs] = getNonMaskedDataSegments(obj)
            if ~any(obj.isMasked)
                xsegs = {obj.time};
                ysegs = {obj.data};
                return
            end
            if numel(obj.isMasked) == 1
                xsegs = {};
                ysegs = {};
                return
            end
            x0 = obj.time;
            y0 = obj.maskedData;
            [ysegs, xsegidxs] = getNonNanSegments(y0);
            xsegs = {};
            for k = 1:numel(xsegidxs)
                xsegs{k} = x0(xsegidxs{k});
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(TimeSeries, s);
        end
        
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

