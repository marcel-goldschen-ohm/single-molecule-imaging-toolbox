function [thresholdedMask, threshold] = thresholdImage(originalImage, threshold, uiImageHandle)

% thresholdedMask = originalImage > threshold;
%
% If threshold is specified, simply return the thresholded mask as above.
% No UI dialogs or images are shown.
%
% If threshold = [] or does not exist, popup a dialog for editing threshold
% and update uiImageHandle live to show the thresholded mask for the
% current value of threshold. If uiImageHandle does not exist, create a new
% figure for the live update of the thresholded mask.
%
% !!! The thresholded mask is only returned if the dialog's OK button is
% pressed, the cancel button will return an empty mask.
%
% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    thresholdedMask = [];
    if isempty(originalImage)
        errordlg('Requires an image.', 'Threshold');
        return
    end
    
    % dialog with parameter settings
    ok = true;
    if ~exist('threshold', 'var') || isempty(threshold)
        threshold = mean(originalImage(:));
        d = dialog('Name', 'Threshold');
        d.Position(3) = 500;
        d.Position(4) = 70;
        uicontrol(d, 'Style', 'text', 'String', 'Threshold', ...
            'Units', 'normalized', 'Position', [0, 0.7, 0.5, 0.3]);
        thresholdEdit = uicontrol(d, 'Style', 'edit', 'String', num2str(threshold), ...
            'Units', 'normalized', 'Position', [0.5, 0.7, 0.5, 0.3], ...
            'Callback', @(s,e) setThreshold_());
        mini = quantile(originalImage(:), 0.01);
        maxi = quantile(originalImage(:), 0.99);
        nsteps = 5000;
        thresholdSlider = uicontrol(d, 'Style', 'slider', ...
            'Min', mini, 'Max', maxi, 'Value', threshold, ...
            'SliderStep', [1.0/nsteps 1.0/nsteps], ...
            'Units', 'normalized', 'Position', [0, 0.4, 1, 0.3], ...
            'Callback', @(s,e) thresholdMoved_());
        addlistener(thresholdSlider, 'Value', 'PostSet', @(s,e) thresholdMoved_());
        uicontrol(d, 'Style', 'pushbutton', 'String', 'OK', ...
            'Units', 'normalized', 'Position', [0.1, 0, 0.4, 0.4], ...
            'Callback', @ok_);
        uicontrol(d, 'Style', 'pushbutton', 'String', 'Cancel', ...
            'Units', 'normalized', 'Position', [0.5, 0, 0.4, 0.4], ...
            'Callback', 'delete(gcf)');
        ok = false; % OK dialog button will set back to true
        showThresholdedMask_();
        uiwait(d);
    end
    
    % dialog OK callback
    function ok_(varargin)
        ok = true;
        delete(d);
    end
    
    % dialog parameter callbacks
    function setThreshold_()
        threshold = str2num(thresholdEdit.String);
        threshold = max(thresholdSlider.Min, min(threshold, thresholdSlider.Max));
        edit.String = num2str(threshold);
        thresholdEdit.Value = threshold;
        showThresholdedMask_();
    end
    function thresholdMoved_()
        threshold = thresholdSlider.Value;
        thresholdEdit.String = num2str(threshold);
        showThresholdedMask_();
    end
    
    % apply the threshold
    function mask = getThresholdedMask_()
        mask = [];
        try
            mask = originalImage > threshold;
        catch
            mask = [];
        end
    end

    % live update of thresholded mask as dialog parameters are changed
    function showThresholdedMask_()
        if ~exist('uiImageHandle', 'var')
            f = figure('Name', 'Threshold', ...
                'numbertitle', 'off');
            ax = axes(f, ...
                'XTick', [], ...
                'YTick', [], ...
                'YDir', 'reverse');
            uiImageHandle = image(ax, [], ...
                'HitTest', 'off', ...
                'PickableParts', 'none');
            axis(ax, 'image');
        end
        mask = getThresholdedMask_();
        if ~isempty(mask)
            I = imadjust(uint16(mask));
            rgb = cat(3,I,I,I);
            uiImageHandle.CData = rgb;
            uiImageHandle.XData = [1 size(rgb,2)];
            uiImageHandle.YData = [1 size(rgb,1)];
        end
    end

    if ok % else cancel button was pressed in dialog
        thresholdedMask = getThresholdedMask_();
    end
end
