classdef SpotProjection < handle
    %SPOTPROJECTION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        time = [];
        data = [];
        ideal = [];
        known = []; % e.g. for simulations
        
        timeUnits = 'frames';
        dataUnits = 'au';
        
        % Optionally specify time only by a sample interval.
        sampleInterval = [];
        
        % adjustments to raw data
        offsetData = 0; % 1x1 (uniform) OR Tx1 (nonuniform) baseline offset
        scaleData = 1; % 1x1 (uniform) OR Tx1 (nonuniform) scale factor
        
        % optional masking of raw data points
        isMasked = false; % 1x1 (uniform) OR Tx1 (nonuniform), F=ok, T=masked
    end
    
    methods
        function obj = SpotProjection()
            %SPOTPROJECTION Constructor.
        end
        
        function x = get.time(obj)
            if isequal(size(obj.time), size(obj.data))
                x = obj.time;
            elseif ~isempty(obj.data) && ~isempty(obj.sampleInterval)
                x = obj.sampleInterval .* reshape([0:size(obj.data,1)-1], [], 1);
            elseif ~isempty(obj.data)
                x = reshape([1:size(obj.data,1)], [], 1);
            else
                x = [];
            end
        end
        
        function set.time(obj, x)
            if isempty(x)
                obj.time = [];
                obj.sampleInterval = [];
            elseif numel(x) == 1
                obj.time = [];
                obj.sampleInterval = x;
            else
                obj.time = reshape(x, [], 1);
            end
        end
        
        function y = get.data(obj)
            y = obj.data;
            if isempty(y)
                return
            end
            % offset
            if obj.offsetData
                y = y + obj.offsetData;
            end
            % scale
            if obj.scaleData ~= 1
                y = y .* obj.scaleData;
            end
        end
        
        function set.data(obj, y)
            obj.data = reshape(y, [], 1);
        end
        
%         function y = get.ideal(obj)
%             if isequal(size(obj.ideal), size(obj.data))
%                 y = obj.ideal;
%             else
%                 y = [];
%             end
%         end
        
        function set.ideal(obj, y)
            obj.ideal = reshape(y, [], 1);
        end
        
%         function y = get.known(obj)
%             if isequal(size(obj.known), size(obj.data))
%                 y = obj.known;
%             else
%                 y = [];
%             end
%         end
        
        function set.known(obj, y)
            obj.known = reshape(y, [], 1);
        end
        
        function isMasked = getIsMasked(obj)
            if numel(obj.isMasked) == 1
                isMasked = repmat(obj.isMasked, size(obj.Data));
            else
                isMasked = obj.isMasked;
            end
        end
        
        function idealize(obj, method, options)
%             p = inputParser;
%             p.addOptional('options', struct());
%             p.parse(options);
%             options = p.Results.options;
            if ~exist('options', 'var')
                options = struct();
            end
            if method == "DISC"
                obj.idealizeDISC(options);
            end
        end
        
        function idealizeDISC(obj, options)
%             p = inputParser;
%             p.addOptional('options', struct());
%             p.parse(options);
%             options = p.Results.options;
            if ~exist('options', 'var')
                options = struct();
            end
            y = obj.adjustedData;
            isMasked = obj.getIsMasked();
            idx = ~isMasked;
            try
                disc_input = initDISC(options);
                disc_fit = runDISC(y(idx), disc_input);
                obj.idealizedData = nan(size(y));
                obj.idealizedData(idx) = disc_fit.ideal;
            catch
                errordlg('Requires DISC (https://github.com/ChandaLab/DISC)', 'DISC');
            end
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

