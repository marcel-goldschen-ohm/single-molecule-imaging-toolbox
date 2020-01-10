classdef Utilities < handle
    %UTILITIES Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static)
        function obj = loadobj(obj, s)
            if isstruct(s)
                props = fieldnames(obj);
                for k = 1:numel(props)
                    prop = char(props{k});
                    metaprop = findprop(obj, prop);
                    if isfield(s, prop) && ~metaprop.Dependent
                        try
                            if isstruct(obj.(prop))
                                obj.(prop) = Utilities.makeStructArraysCompatible(s.(prop), obj.(prop));
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
        
        function tf = isAxesZoomed(ax)
            unzoomed = getappdata(ax, 'matlab_graphics_resetplotview');
            if isempty(unzoomed) ...
                    || (isequal(ax.XLim, unzoomed.XLim) && isequal(ax.YLim, unzoomed.YLim))
               tf = false;
            else
               tf = true;
            end
        end
        
        function answer = questdlgInFig(fig, question, title)
            dlg = uipanel(fig, ...
                'Title', title, ...
                'Position', [.25 .25 .5 .5], ...
                'BackgroundColor', [.8 .9 1], ...
                'FontSize', 12);
            quest = uicontrol(dlg, 'style', 'text', ...
                'String', question, ...
                'BackgroundColor', [.8 .9 1], ...
                'FontSize', 12, ...
                'Units', 'normalized', 'Position', [0 .25 1 .75]);
            yesBtn = uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Yes', ...
                'BackgroundColor', [.6 .9 .6], ...
                'FontSize', 12, ...
                'Units', 'normalized', 'Position', [.2 .05 .25 .2], ...
                'Callback', @(varargin) yes_());
            noBtn = uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'No', ...
                'BackgroundColor', [1 .6 .6], ...
                'FontSize', 12, ...
                'Units', 'normalized', 'Position', [.55 .05 .25 .2], ...
                'Callback', @(varargin) no_());
            uiwait();
            delete(dlg);
            function yes_()
                uiresume();
                answer = "Yes";
            end
            function no_()
                uiresume();
                answer = "No";
            end
        end
    end
end

