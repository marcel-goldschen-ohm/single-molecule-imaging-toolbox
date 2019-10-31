classdef Channel < handle
    %CHANNEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        label = "";
        color = [0 1 0]; % [r g b]
        notes = '';
        
        % a collection of images or image stacks for this channel
        % e.g. main image stack, spot mask image, alignment image, etc.
        images = repmat(ImageStack, 0);
        
        % map this channel onto another channel
        alignedTo = struct( ...
            'channel', [], ... % [] or handle to another Channel instance
            'alignment', ImageRegistration ... % maps this channel onto another channel
            );
        
        % array of spots
        spots = repmat(Spot, 0);
        
        % parent experiment, [] or Experiment handle
        parentExperiment = [];
    end
    
    methods
        function obj = Channel()
            %CHANNEL Construct an instance of this class
            %   Detailed explanation goes here
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            if isstruct(s)
                obj = Channel();
                for prop = fieldnames(obj)
                    if isfield(s, prop)
                        try
                            if isstruct(obj.(prop))
                                obj.(prop) = Channel.makeStructArraysCompatible(s.(prop), obj.(prop));
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

