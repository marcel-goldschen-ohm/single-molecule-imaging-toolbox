function [zprojectedImage, method, frames] = zprojectImageStackWithPreview(imageStack, method, frames, uiImagePreviewHandle)

% zprojectedImage: z-projection of image stack frames according to method.
%
% uiImagePreviewHandle: Optional handle to image graphics object for live preview.
%                       If not specified, a temporary figure will be created for the preview.
%
% Pops up a dialog to edit parameters and shows a live preview of the
% z-projected image.
%
% !!! The z-projected image is only returned if the dialog's OK button is
% pressed, the cancel button will return an empty image.
%
% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    zprojectedImage = [];
    nframes = size(imageStack,3);
    if nframes <= 1
        errordlg('Requires an image stack.', 'Z-Project');
        return
    end
    
    methods = {'Mean', 'Min', 'Max'};
    
    % default parameters
    if ~exist('method', 'var') || isempty(method)
        method = 'Mean';
    end
    if ~exist('frames', 'var') || isempty(frames)
        frames = 1:nframes;
    end
    
    % preview
    if ~exist('uiImagePreviewHandle', 'var')
        tempFig = figure('Name', 'Z-Project', ...
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
    dlg = dialog('Name', 'Z-Project');
    w = 200;
    lh = 20;
    h = 2*lh + 30;
    dlg.Position(3) = w;
    dlg.Position(4) = h;
    y = h - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Method', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'popupmenu', 'String', methods, ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setMethod_);
    y = y - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Frames', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'edit', 'String', [num2str(frames(1)) '-' num2str(frames(end))], ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setFrames_);
    y = 0;
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
        'Units', 'pixels', 'Position', [w/2-55, y, 50, 30], ...
        'Callback', @ok_);
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Units', 'pixels', 'Position', [w/2+5, y, 50, 30], ...
        'Callback', 'delete(gcf)');
    
    % block until dialog closed
    ok = false; % OK dialog button will set back to true
    showZProjection_();
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
    function setMethod_(popupmenu, varargin)
        method = methods{popupmenu.Value};
        showZProjection_();
    end
    function setFrames_(edit, varargin)
        str = strtrim(edit.String);
        if isempty(str)
            frames = 1:nframes;
            edit.String = [num2str(frames(1)) '-' num2str(frames(end))];
        else
            firstlast = split(str, '-');
            first = str2num(firstlast{1});
            last = str2num(firstlast{2});
            frames = max(1, first):min(last, nframes);
        end
        showZProjection_();
    end
    
    % apply the z-projection
    function im = getZProjection_()
        im = [];
        if isempty(frames)
            return
        end
        try
            if method == "Mean"
                im = mean(imageStack(:,:,frames), 3);
            elseif method == "Min"
                im = min(imageStack(:,:,frames), [], 3);
            elseif method == "Max"
                im = max(imageStack(:,:,frames), [], 3);
            end
        catch
            im = [];
        end
    end

    % live update of z-projected image as dialog parameters are changed
    function showZProjection_()
        im = getZProjection_();
        if ~isempty(im)
            I = imadjust(uint16(im));
            rgb = cat(3,I,I,I);
            uiImagePreviewHandle.CData = rgb;
            uiImagePreviewHandle.XData = [1 size(rgb,2)];
            uiImagePreviewHandle.YData = [1 size(rgb,1)];
        end
    end

    if ok % else cancel button was pressed in dialog
        zprojectedImage = getZProjection_();
    end
end
