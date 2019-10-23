function [filteredImage, diskRadius] = tophatFilterImageWithPreview(originalImage, diskRadius, uiImagePreviewHandle)

% filteredImage = imtophat(originalImage, strel('disk', diskRadius));
%
% uiImagePreviewHandle: Optional handle to image graphics object for live preview.
%                       If not specified, a temporary figure will be created for the preview.
%
% Pops up a dialog to edit parameters and shows a live preview of the
% filtered image.
%
% !!! The fitlered image is only returned if the dialog's OK button is
% pressed, the cancel button will return an empty image.
%
% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    filteredImage = [];
    if isempty(originalImage)
        errordlg('Requires an image.', 'Tophat Filter');
        return
    end
    
    % default parameters
    if ~exist('diskRadius', 'var') || isempty(diskRadius)
        diskRadius = 2;
    end

    % preview image filter
    if ~exist('uiImagePreviewHandle', 'var')
        tempFig = figure('Name', 'Tophat Filter', ...
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
    dlg = dialog('Name', 'Tophat Filter');
    w = 200;
    lh = 20;
    h = lh + 30;
    dlg.Position(3) = w;
    dlg.Position(4) = h;
    y = h - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Disk Radius', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'edit', 'String', num2str(diskRadius), ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setDiskRadius_);
    y = 0;
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
        'Units', 'pixels', 'Position', [w/2-55, y, 50, 30], ...
        'Callback', @ok_);
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Units', 'pixels', 'Position', [w/2+5, y, 50, 30], ...
        'Callback', 'delete(gcf)');
    
    % block until dialog closed
    ok = false; % OK dialog button will set back to true
    showFilteredImage_();
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
    function setDiskRadius_(edit, varargin)
        diskRadius = str2num(edit.String);
        showFilteredImage_();
    end
    
    % apply the filter
    function im = getFilteredImage_()
        im = [];
        try
            im = imtophat(originalImage, strel('disk', diskRadius));
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
