classdef SpotProjection < handle
    %SPOTPROJECTION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        rawTime = []; % Tx1 time array OR 1x1 sample interval
        rawData = []; % Tx1 data array
        
        timeUnits = 'frames';
        dataUnits = 'au';
        
        ideal = []; % idealization of adjustedData
        known = []; % e.g. for simulations
        
        % optional masking of raw data
        isMasked = false; % 1x1 (uniform) OR Tx1 (nonuniform), true=masked
        
        % adjustments to raw data
        offsetData = 0; % 1x1 (uniform) OR Tx1 (nonuniform) baseline offset
        scaleData = 1; % 1x1 (uniform) OR Tx1 (nonuniform) scale factor
        
        % sum blocks of frames
        sumEveryNFrames = 1;
        
        % filtering
        % ...
        
        % idealization
        idealizationMethod = "";
        idealizationParams = struct;
    end
    
    properties (Dependent)
        time
        data
        mask % true=masked
    end
    
    methods
        function obj = SpotProjection()
            %SPOTPROJECTION Constructor.
        end
        
        function set.rawTime(obj, x)
            obj.rawTime = reshape(x, [], 1);
        end
        function set.rawData(obj, y)
            obj.rawData = reshape(y, [], 1);
        end
        function set.ideal(obj, y)
            obj.ideal = reshape(y, [], 1);
        end
        function set.known(obj, y)
            obj.known = reshape(y, [], 1);
        end
        function set.isMasked(obj, y)
            obj.isMasked = reshape(y, [], 1);
        end
        function set.offsetData(obj, y)
            obj.offsetData = reshape(y, [], 1);
        end
        function set.scaleData(obj, y)
            obj.scaleData = reshape(y, [], 1);
        end
        
        function x = get.time(obj)
            npts = size(obj.rawData, 1);
            if npts == 0
                x = [];
                return
            end
            if isempty(obj.rawTime)
                % frames
                x = reshape([1:npts], [], 1);
            elseif numel(obj.rawTime) == 1
                % sample interval
                dt = obj.rawTime;
                x = dt .* reshape([0:npts-1], [], 1);
            elseif size(obj.rawTime, 1) == npts
                % time pts
                x = obj.rawTime;
            else
                % should NOT happen
                x = [];
            end
            if ~isempty(x) && obj.sumEveryNFrames > 1
                n = obj.sumEveryNFrames;
                npts = floor(double(length(x)) / n) * n;
                x = x(1:n:npts);
            end
        end
        
        function y = get.data(obj)
            y = obj.rawData;
            if isempty(y)
                return
            end
            % offset raw
            if obj.offsetData && (numel(obj.offsetData) == 1 || size(obj.offsetData, 1) == size(y, 1))
                y = y + obj.offsetData;
            end
            % scale raw
            if obj.scaleData ~= 1 && (numel(obj.scaleData) == 1 || size(obj.scaleData, 1) == size(y, 1))
                y = y .* obj.scaleData;
            end
            % sum frame blocks?
            if obj.sumEveryNFrames > 1
                n = obj.sumEveryNFrames;
                npts = floor(double(length(y)) / n) * n;
                y0 = y;
                y = y0(1:n:npts);
                for k = 2:n
                    y = y + y0(k:n:npts);
                end
            end
            % offset summed frames
            if obj.offsetData && size(obj.offsetData, 1) == size(y, 1)
                y = y + obj.offsetData;
            end
            % scale summed frames
            if obj.scaleData ~= 1 && size(obj.scaleData, 1) == size(y, 1)
                y = y .* obj.scaleData;
            end
            % filter
            % ...
        end
        
        function tf = get.mask(obj)
            % true = masked
            if isempty(obj.isMasked)
                % no mask
                tf = [];
                return
            elseif numel(obj.isMasked) == 1
                % uniform mask
                tf = reshape(repmat(obj.isMasked, size(obj.data)), [], 1);
                return
            end
            nraw = size(obj.rawData, 1);
            nadj = size(obj.data, 1);
            nmask = size(obj.isMasked, 1);
            if nmask == nadj
                % mask data
                tf = obj.isMasked;
            elseif nmask == nraw
                % convert raw data mask to summed frames data mask
                n = obj.sumEveryNFrames;
                tf = false(nadj, n);
                for k = 1:n
                    tf(:,k) = obj.isMasked(k:n:n*nadj);
                end
                tf = any(tf, 2);
            else
                % should NOT happen
                tf = [];
            end
        end
        
        function idealize(obj, method, params)
            if ~exist('method', 'var')
                method = obj.idealizationMethod;
            end
            if ~exist('params', 'var')
                params = obj.idealizationParams;
            end
            if method == "DISC"
                try
                    disc_input = initDISC();
                    if isfield(params, 'alpha')
                        disc_input.input_type = 'alpha_value';
                        disc_input.input_value = params.alpha;
                    end
                    if isfield(params, 'informationCriterion')
                        disc_input.divisive = params.informationCriterion;
                        disc_input.agglomerative = params.informationCriterion;
                    end
                    disc_fit = runDISC(obj.data, disc_input);
                    obj.ideal = disc_fit.ideal;
                catch
                    errordlg('Requires DISC (https://github.com/ChandaLab/DISC)', 'DISC');
                    return
                end
            else
                % unkown method
                return
            end
            obj.idealizationMethod = string(method);
            obj.idealizationParams = params;
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(SpotProjection(), s);
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

