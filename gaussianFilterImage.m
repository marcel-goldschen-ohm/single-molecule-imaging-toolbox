function [filteredImage, sigma] = gaussianFilterImage(originalImage, sigma, uiImagePreviewHandle)

% filteredImage = imgaussfilt(originalImage, sigma);
%
% uiImagePreviewHandle: handle to image graphics object for live preview
%
% If sigma is specified, simply return the filtered image as above. No UI
% dialogs or images are shown.
%
% If sigma = [] or does not exist, popup a dialog for editing sigma and
% update uiImagePreviewHandle live to show the filtered image for the current
% value of sigma. If uiImagePreviewHandle does not exist, create a new figure for
% the live update of the filtered image.
%
% !!! The fitlered image is only returned if the dialog's OK button is
% pressed, the cancel button will return an empty image.
%
% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    filteredImage = [];
    if isempty(originalImage)
        errordlg('Requires an image.', 'Gaussian Filter');
        return
    end
    
    % dialog with parameter settings
    ok = true;
    if ~exist('sigma', 'var') || isempty(sigma)
        % default parameters
        sigma = 1.5;
        
        % preview image filter
        if ~exist('uiImagePreviewHandle', 'var')
            tempFig = figure('Name', 'Gaussian Filter', 'numbertitle', 'off');
            ax = axes(tempFig, ...
                'XTick', [], ...
                'YTick', [], ...
                'YDir', 'reverse');
            uiImagePreviewHandle = image(ax, [], ...
                'HitTest', 'off', ...
                'PickableParts', 'none');
            axis(ax, 'image');
        end
        
        % dialog
        dlg = dialog('Name', 'Gaussian Filter');
        w = 200;
        lh = 20;
        h = lh + 30;
        dlg.Position(3) = w;
        dlg.Position(4) = h;
        y = h - lh;
        uicontrol(dlg, 'Style', 'text', 'String', 'Sigma', ...
            'Units', 'pixels', 'Position', [0, y, w/2, lh]);
        uicontrol(dlg, 'Style', 'edit', 'String', num2str(sigma), ...
            'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
            'Callback', @setSigma_);
        y = 0;
        uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
            'Units', 'pixels', 'Position', [w/2-55, y, 50, 30], ...
            'Callback', @ok_);
        uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
            'Units', 'pixels', 'Position', [w/2+5, y, 50, 30], ...
            'Callback', 'delete(gcf)');
        ok = false; % OK dialog button will set back to true
        showFilteredImage_();
        uiwait(dlg);
        
        % run this after dialog is closed
        if exist('tempFig', 'var')
            delete(tempFig);
        end
    end

    % dialog OK callback
    function ok_(varargin)
        ok = true;
        delete(dlg);
    end

    % dialog parameter callbacks
    function setSigma_(edit, varargin)
        sigma = str2num(edit.String);
        showFilteredImage_();
    end
    
    % apply the filter
    function im = getFilteredImage_()
        im = [];
        try
            im = imgaussfilt(originalImage, sigma);
        catch
            im = [];
        end
    end

    % live update of filtered image as dialog parameters are changed
    function showFilteredImage_()
        im = getFilteredImage_();
        if ~isempty(im)
            I = imadjust(uint16(im));
            rgb = cat(3,I,I,I);
            uiImagePreviewHandle.CData = rgb;
            uiImagePreviewHandle.XData = [1 size(rgb,2)];
            uiImagePreviewHandle.YData = [1 size(rgb,1)];
        end
    end

    if ok % else cancel button was pressed in dialog
        filteredImage = getFilteredImage_();
    end
end
