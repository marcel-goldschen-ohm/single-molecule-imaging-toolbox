function movingReg = imagesRegistrationAppWrapper(moving, fixed)

% This is a wrapper for programatically launching MATLAB's
% registrationEstimator app and returning the last image registration
% struct exported from the app to the base workspace upon closing the app
% window.

% Hint: Inputting imadjust(moving), imadjust(fixed) may be helpful.

% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    % init
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
        '4. Last exported alignment will be returned.' ...
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
