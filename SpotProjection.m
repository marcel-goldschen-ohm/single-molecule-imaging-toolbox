classdef SpotProjection < handle
    %SPOTPROJECTION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        time = []; % Tx1 time array OR 1x1 sample interval (sec)
        data = []; % Tx1 data array
        
        % sum blocks of frames
        sumEveryNFrames = 1;
        
        % idealization of data
        idealizedData = [];
        
        % simulation
        perfectData = []; % e.g. from simulations
    end
    
    methods
        function obj = SpotProjection()
            %SPOTPROJECTION Constructor.
        end
        
        function x = get.time(obj)
            ny = size(obj.data, 1);
            if ny == 0
                x = [];
                return
            end
            nx = size(obj.time, 1);
            if nx == 0
                % frames
                x = reshape([1:ny], [], 1);
            elseif nx == 1
                % sample interval
                dt = obj.time;
                x = dt .* reshape([0:ny-1], [], 1);
            elseif nx == ny
                % time pts
                x = obj.time;
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
        function set.time(obj, x)
            obj.time = reshape(x, [], 1);
        end
        
        function y = get.data(obj)
            y = obj.data;
            if isempty(y)
                return
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
        end
        function set.data(obj, y)
            obj.data = reshape(y, [], 1);
        end
        
        function y = get.idealizedData(obj)
            if ~isequal(size(obj.idealizedData), size(obj.data))
            	y = [];
                return
            end
            y = obj.idealizedData;
        end
        function set.idealizedData(obj, y)
            obj.idealizedData = reshape(y, [], 1);
        end
        
        
        
        function set.trueData(obj, y)
            obj.trueData = reshape(y, [], 1);
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
        
        function dt = get.sampleInterval(obj)
            if isempty(obj.rawTime)
                dt = [];
            elseif numel(obj.rawTime) == 1
                dt = obj.rawTime;
            else
                dt = obj.rawTime(2) - obj.rawTime(1);
            end
        end
        
        function clear(obj)
            obj.rawData = [];
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
                    obj.idealizedData = disc_fit.ideal;
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

