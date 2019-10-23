function [thresholdedMask, threshold] = thresholdImageWithPreview(originalImage, threshold, uiImagePreviewHandle)

% thresholdedMask = originalImage > threshold;
%
% uiImagePreviewHandle: Optional handle to image graphics object for live preview.
%                       If not specified, a temporary figure will be created for the preview.
%
% Pops up a dialog for editing parameters (slider for threshold) and shows
% a live preview of the thresholded mask.
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
    
    % default parameters
    if ~exist('threshold', 'var') || isempty(threshold)
        threshold = mean(originalImage(:));
    end
    
    % preview
    if ~exist('uiImagePreviewHandle', 'var')
        tempFig = figure('Name', 'Threshold', ...
            'numbertitle', 'off', ...
            'Units', 'normalized', ...
            'Position', [0 0 1 1]);
        ax = axes(tempFig, ...
            'XTick', [], ...
            'YTick', [], ...
            'YDir', 'reverse');
        uiImagePreviewHandle = image(ax, [], ...
            'HitTest', 'off', ...
            'PickableParts', 'none');
        axis(ax, 'image');
    end
    
    % parameter dialog
    dlg = dialog('Name', 'Threshold');
    w = 500;
    lh = 20;
    h = 2 * lh + 30;
    dlg.Position(3) = w;
    dlg.Position(4) = h;
    y = h - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Threshold', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    thresholdEdit = uicontrol(dlg, 'Style', 'edit', 'String', num2str(threshold), ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @(s,e) setThreshold_());
    y = y - lh;
    mini = quantile(originalImage(:), 0.01);
    maxi = quantile(originalImage(:), 0.99);
    nsteps = 5000;
    thresholdSlider = uicontrol(dlg, 'Style', 'slider', ...
        'Min', mini, 'Max', maxi, 'Value', threshold, ...
        'SliderStep', [1.0/nsteps 1.0/nsteps], ...
        'Units', 'pixels', 'Position', [0, y, w, lh], ...
        'Callback', @(s,e) thresholdMoved_());
    addlistener(thresholdSlider, 'Value', 'PostSet', @(s,e) thresholdMoved_());
    y = 0;
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
        'Units', 'pixels', 'Position', [w/2-55, y, 50, 30], ...
        'Callback', @ok_);
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Units', 'pixels', 'Position', [w/2+5, y, 50, 30], ...
        'Callback', 'delete(gcf)');
    
    % block until dialog closed
    ok = false; % OK dialog button will set back to true
    showThresholdedMask_();
    uiwait(dlg);

    % run this after dialog is closed
    if exist('tempFig', 'var')
        delete(tempFig);
    end
    
    % dialog OK callback
    function ok_(varargin)
        ok = true;
        delete(dlg);
    end
    
    % dialog parameter callbacks
    function setThreshold_()
        threshold = str2num(thresholdEdit.String);
        threshold = max(thresholdSlider.Min, min(threshold, thresholdSlider.Max));
        thresholdEdit.String = num2str(threshold);
        thresholdSlider.Value = threshold;
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
        mask = getThresholdedMask_();
        if ~isempty(mask)
            I = imadjust(uint16(mask));
            rgb = cat(3,I,I,I);
            uiImagePreviewHandle.CData = rgb;
            uiImagePreviewHandle.XData = [1 size(rgb,2)];
            uiImagePreviewHandle.YData = [1 size(rgb,1)];
        end
    end

    if ok % else cancel button was pressed in dialog
        thresholdedMask = getThresholdedMask_();
    end
end
