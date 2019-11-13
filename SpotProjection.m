classdef SpotProjection < timeseries
    %SPOTPROJECTION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        sampleInterval = [];
        
        % basic adjustments: offset and scale
        offset = 0; % 1x1 (uniform) OR Tx1 (nonuniform) baseline offset
        scale = 1; % 1x1 (uniform) OR Tx1 (nonuniform) scale factor
        
        % optional masking
        isMasked = false; % 1x1 (uniform) OR Tx1 (nonuniform), F=ok, T=masked
        
        idealizedData = [];
    end
    
    properties (Dependent)
        timeSamples
        rawData
        adjustedData
    end
    
    methods
        function obj = SpotProjection()
            %SPOTPROJECTION Construct an instance of this class
            %   Detailed explanation goes here
        end
        
        function x = get.timeSamples(obj)
            if isequal(size(obj.Time), size(obj.Data))
                x = obj.Time;
            elseif ~isempty(obj.Data) && ~isempty(obj.sampleInterval)
                x = obj.sampleInterval .* [0:size(obj.Data,1)-1]';
            else
                x = [];
            end
        end
        
        function y = get.rawData(obj)
            y = obj.Data;
        end
        
        function set.rawData(obj, y)
            obj.Data = reshape(y, [], 1);
        end
        
        function y = get.adjustedData(obj)
            y = obj.Data;
            if isempty(y)
                return
            end
            % offset
            if obj.offset
                y = y + obj.offset;
            end
            % scale
            if obj.scale ~= 1
                y = y .* obj.scale;
            end
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

