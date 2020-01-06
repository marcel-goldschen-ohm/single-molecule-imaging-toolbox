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
        
        sumEveryN = 1; % e.g. simulate longer imaging frame durations
%         filter = digitalFilter.empty;
    end
    
    properties (Dependent)
        time % time array (same size as data)
        data % offset and scaled rawData
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
            obj.sumEveryN = 1;
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
            if ~isempty(x) && obj.sumEveryN > 1
                n = obj.sumEveryN;
                x = x(1:n:end);
            end
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
            if ~isempty(y) && obj.sumEveryN > 1
                n = obj.sumEveryN;
                y0 = y;
                npts = int32(round(floor(double(length(y0)) / n) * n));
                y = y0(1:n:npts);
                for k = 2:n
                    y = y + y0(k:n:npts);
                end
            end
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
        function y = get.maskedData(obj)
            y = obj.data;
            if isempty(y) || ~any(obj.isMasked)
                return
            end
            if numel(obj.isMasked) == 1
                y = nan(size(y));
                return
            end
            if obj.sumEveryN > 1
                n = obj.sumEveryN;
                npts = length(y);
                mask = false(npts, n);
                for k = 1:n
                    mask(:,k) = obj.isMasked(k:n:npts);
                end
                mask = any(mask, 2);
                y(mask) = nan;
            else
                y(obj.isMasked) = nan;
            end
        end
        
        % cell array of nonmasked data chunks
        function [x,y] = getNonMaskedDataChunks(obj)
            if ~any(obj.isMasked)
                x = {obj.time};
                y = {obj.data};
                return
            end
            if numel(obj.isMasked) == 1
                x = {};
                y = {};
                return
            end
            x0 = obj.time;
            y0 = obj.maskedData;
            [y, startIndices] = getNonNanSegments(y0);
            x = {};
            for k = 1:numel(y)
                n = length(y{k});
                i = startIndices(k);
                x{k} = x0(i:i+n-1);
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(TimeSeries, s);
        end
        
        function [segments, segmentStartIndices] = getNonNanSegments(dataWithNan)
            % return cell array of non-nan subarrays
            dataWithNan = reshape(dataWithNan, [], 1);
            idx = isnan(dataWithNan);
            segmentLengths = diff(find([1; diff(idx); 1]));
            segmentStartIndices = [1; cumsum(segmentLengths(1:end-1))];
            segments = mat2cell(dataWithNan, segmentLengths(:));
            % remove nan segments
            segments(2:2:end) = [];
            segmentStartIndices(2:2:end) = [];
        end
    end
end

