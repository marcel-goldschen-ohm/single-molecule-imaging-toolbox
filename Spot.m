classdef Spot < handle
    %SPOT Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % spot image location [x,y]
        % scalar x,y --> fixed location for all image frames
        % vector x,y --> per frame locations (i.e. for drift correction)
        xy = [];
        
        % e.g. from regionprops()
        props = struct();
        
        % labels can be used ot group spots
        label = "";
        
        % spot image intensity z-projection
        zproj = [];
        
        % idealization of z-projection
        ideal = [];
    end
    
    methods
        function obj = Spot()
            %SPOT Construct an instance of this class
            %   Detailed explanation goes here
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            if isstruct(s)
                obj = Spot();
                for prop = fieldnames(obj)
                    if isfield(s, prop)
                        try
                            obj.(prop) = s.(prop);
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
    end
end

