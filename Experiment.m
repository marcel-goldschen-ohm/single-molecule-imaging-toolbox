classdef (ConstructOnLoad) Experiment < handle
    %EXPERIMENT Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        notes = '';
        
        % array of channel data
        channels = repmat(Channel, 0);
        
        % [#spots x #channels] struct matrix of spot z-projections
        alignedSpots = repmat(Spot, 0);
    end
    
    properties (Access = private)
        % working dir
        wd = pwd();
    end
    
    methods
        function obj = Experiment()
            %EXPERIMENT Construct an instance of this class
            %   Detailed explanation goes here
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            if isstruct(s)
                obj = Experiment();
                for prop = fieldnames(obj)
                    if isfield(s, prop)
                        try
                            if isstruct(obj.(prop))
                                obj.(prop) = Experiment.makeStructArraysCompatible(s.(prop), obj.(prop));
                            else
                                obj.(prop) = s.(prop);
                            end
                        catch
                            disp(['!!! ERROR: ' class(obj) ': Failed to load property ' prop]);
                        end
                    end
                end
                unloadedProps = setdiff(fieldnames(s), fieldnames(obj));
                if ~isempty(unloadedProps)
                    disp(['!!! WARNING: ' class(obj) ': Did NOT load invalid properties: ' strjoin(unloadedProps, ',')]);
                end
            else
                obj = s;
            end
        end
        
        function [A, B] = makeStructArraysCompatible(A, B)
            % Adds default empty fields to struct arrays A and B as needed so that they
            % have identical fieldnames.
            fa = fieldnames(A);
            fb = fieldnames(B);
            fab = union(fa, fb);
            for k = 1:numel(fab)
                if ~isfield(A, fab{k})
                    bk = B(1).(fab{k});
                    if isobject(bk)
                        [A.(fab{k})] = deal(eval(class(bk)));
                    else
                        [A.(fab{k})] = deal([]);
                    end
                elseif ~isfield(B, fab{k})
                    ak = A(1).(fab{k});
                    if isobject(ak)
                        [B.(fab{k})] = deal(eval(class(ak)));
                    else
                        [B.(fab{k})] = deal([]);
                    end
                end
            end
        end
    end
end

