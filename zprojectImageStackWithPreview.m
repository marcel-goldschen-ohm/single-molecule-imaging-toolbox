function [zprojectedImage, method, frames] = zprojectImageStackWithPreview(imageStack, method, frames, uiImagePreviewHandle)

% If method and frames are specified, simply return the z-projected image.
% No UI dialogs or images are shown.
%
% If method or frames are empty or do not exist, popup a dialog for editing
% them and update uiImageHandle live to show the z-projected image for the
% current values of method and frames. If uiImageHandle does not exist,
% create a new figure for the live update of the z-projected image.
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
    
    % dialog with parameter settings
    methods = {'Mean', 'Min', 'Max'};
    ok = true;
    if ~exist('method', 'var') || ~exist('frames', 'var') ...
            || isempty(method) || isempty(frames)
        if ~exist('frames', 'var') || isempty(frames)
            frames = 1:nframes;
        end
        if ~exist('method', 'var') || isempty(method)
            method = 'Mean';
        end
        d = dialog('Name', 'Z-Project');
        d.Position(3) = 200;
        d.Position(4) = 70;
        uicontrol(d, 'Style', 'text', 'String', 'Method', ...
            'Units', 'normalized', 'Position', [0, 0.7, 0.5, 0.3]);
        uicontrol(d, 'Style', 'popupmenu', 'String', methods, ...
            'Units', 'normalized', 'Position', [0.5, 0.7, 0.5, 0.3], ...
            'Callback', @setMethod_);
        uicontrol(d, 'Style', 'text', 'String', 'Frames', ...
            'Units', 'normalized', 'Position', [0, 0.4, 0.5, 0.3]);
        uicontrol(d, 'Style', 'edit', 'String', [ num2str(frames(1)) '-' num2str(frames(end))], ...
            'Units', 'normalized', 'Position', [0.5, 0.4, 0.5, 0.3], ...
            'Callback', @setFrames_);
        uicontrol(d, 'Style', 'pushbutton', 'String', 'OK', ...
            'Units', 'normalized', 'Position', [0.1, 0, 0.4, 0.4], ...
            'Callback', @ok_);
        uicontrol(d, 'Style', 'pushbutton', 'String', 'Cancel', ...
            'Units', 'normalized', 'Position', [0.5, 0, 0.4, 0.4], ...
            'Callback', 'delete(gcf)');
        ok = false; % OK dialog button will set back to true
        showZProjection_();
        uiwait(d);
    end

    % dialog OK callback
    function ok_(varargin)
        ok = true;
        delete(d);
    end

    % dialog parameter callbacks
    function setMethod_(popupmenu, varargin)
        method = methods{popupmenu.Value};
        showZProjection_();
    end
    function setFrames_(edit, varargin)
        firstlast = split(edit.String, '-');
        first = str2num(firstlast{1});
        last = str2num(firstlast{2});
        frames = max(1, first):min(last, nframes);
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
        if ~exist('uiImageHandle', 'var')
            f = figure('Name', 'Z-Project', ...
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
        im = getZProjection_();
        if ~isempty(im)
            I = imadjust(uint16(im));
            rgb = cat(3,I,I,I);
            uiImageHandle.CData = rgb;
            uiImageHandle.XData = [1 size(rgb,2)];
            uiImageHandle.YData = [1 size(rgb,1)];
        end
    end

    if ok % else cancel button was pressed in dialog
        zprojectedImage = getZProjection_();
    end
end
