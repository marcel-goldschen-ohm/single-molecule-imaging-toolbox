classdef ImageRegistration < handle
    %IMAGEREGISTRATION Image registration 2D transformation.
    %   Transformation computed either by image intensity registration or
    %   via spot registration. Intensity registration utilizes MATLAB's
    %   builtin registrationEstimator app.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        movingImage = []; % (2d image) (for channel at column index)
        fixedImage = []; % (2d image) (for channel at row index)
        
        movingSpots = []; % ([x y] spot locations for channel at column index)
        fixedSpots = []; % ([x y] spot locations for channel at row index)
        
        transformation = []; % (2d transform, e.g. affine2d)
    end
    
    methods
        function obj = ImageRegistration()
            %IMAGEREGISTRATION Construct an instance of this class
        end
        
        function registeredImage = getRegisteredImage(obj, movingImage)
            if ~exist('movingImage', 'var') || isempty(movingImage)
                movingImage = obj.movingImage;
            end
            registeredImage = imwarp(movingImage, obj.transformation, 'OutputView', imref2d(size(obj.fixedImage)));
        end
        
        function registeredSpots = getRegisteredSpots(obj, movingSpots)
            if ~exist('movingSpots', 'var') || isempty(movingSpots)
                movingSpots = obj.movingSpots;
            end
            registeredSpots = transformPointsForward(obj.transformation, movingSpots);
        end
        
        function registerImages(obj, moving, fixed)
            if exist('moving', 'var') && ~isempty(moving)
                obj.movingImage = moving;
            end
            if exist('fixed', 'var') && ~isempty(fixed)
                obj.fixedImage = fixed;
            end
            movingReg = registrationEstimatorAppWrapper(imadjust(obj.movingImage), imadjust(obj.fixedImage));
            if ~isempty(movingReg)
                obj.transformation = movingReg.Transformation;
            end
        end
        
%         function registerSpots(obj, moving, fixed)
%             if exist('moving', 'var') && ~isempty(moving)
%                 obj.movingSpots = moving;
%             end
%             if exist('fixed', 'var') && ~isempty(fixed)
%                 obj.fixedSpots = fixed;
%             end
%             ... % TODO
%         end
    end
    
    methods (Static)
        function movingReg = registrationEstimatorAppWrapper(moving, fixed)
            % This is a wrapper for programatically launching MATLAB's
            % registrationEstimator app and returning the last image registration
            % struct exported from the app to the base workspace upon closing the app
            % window.
            %
            % Hint: Inputting imadjust(moving), imadjust(fixed) may be helpful.
            
            movingReg = [];

            % launch MATLAB's registrationEstimator app
            registrationEstimator(moving, fixed);

            % get handle to registrationEstimator uifigure
            appFigureHandle = gobjects(0);
            hfigs = findall(groot, 'type', 'Figure');
            for i = 1:numel(hfigs)
                if hfigs(i).Name == "moving (Moving Image)  &  fixed (Fixed Image)"
                    appFigureHandle = hfigs(i);
                    break
                end
            end
            if isempty(appFigureHandle)
                return
            end

            % inform user that they need to export the alignment
            msgbox({ ...
                '1. Align images', ...
                '2. Export to workspace (name whatever)', ...
                '3. Close registration estimator window', ...
                '4. Last exported alignment will be returned' ...
                });

            % get list of base workspace variables
            vars = evalin('base', 'who()');
            % block until registrationEstimator uifigure is closed
            waitfor(appFigureHandle);
            % get list of base workspace variables
            newvars = evalin('base', 'who()');
            % find new base workspace variables (i.e. those exported from
            % registrationEstimator app)
            newvars = newvars(~ismember(newvars, vars));
            if ~isempty(newvars)
                % return registrationEstimator app export
                movingReg = evalin('base', newvars{end});
            end
        end
        
        function obj = loadobj(s)
            obj = Utilities.loadobj(ImageRegistration(), s);
        end
    end
end

