function [xy, minPeakProminence, minPeakSeparation, tophatFilterRadius, gaussFilterSigma] = ...
    findImageMaximaWithPreview(im, minPeakProminence, minPeakSeparation, tophatFilterRadius, gaussFilterSigma, uiImagePreviewHandle)

% xy: [x y] coords of local maxima in image im.
% minPeakProminence: size of local peak to be considered as a maxima
% minPeakSeparation: min separation between maxima
% tophatFilterRadius: disk radius of image's tophat pre-filter
% gaussFilterSigma: sigma of image's gaussian pre-filter
% uiImagePreviewHandle: handle to image graphics object used for live preview
%                If NOT specified, a temporary figure will be created for
%                the preview.
%
% Pops up a dialog to edit parameters and shows a live preview with maxima
% locations marked.
%
% !!! The maxima locations are only returned if the dialog's OK button is
% pressed, the cancel button will return an empty list.
%
% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    xy = [];
    if isempty(im)
        errordlg('Requires an image.', 'Find Image Maxima');
        return
    end
    
    % default parameters
    if ~exist('minPeakProminence', 'var') || isempty(minPeakProminence)
        minPeakProminence = 1000;
    end
    if ~exist('minPeakSeparation', 'var') || isempty(minPeakSeparation)
        minPeakSeparation = 3;
    end
    if ~exist('tophatFilterRadius', 'var') || isempty(tophatFilterRadius)
        tophatFilterRadius = 0; % no filtering
    end
    if ~exist('gaussFilterSigma', 'var') || isempty(gaussFilterSigma)
        gaussFilterSigma = 0; % no filtering
    end
    
    % image and parent axes on which to show maxima
    if ~exist('uiImagePreviewHandle', 'var')
        tempFig = figure('Name', 'Find Image Maxima', 'numbertitle', 'off');
        uiImageAxes = axes(tempFig, ...
            'XTick', [], ...
            'YTick', [], ...
            'YDir', 'reverse');
        uiImagePreviewHandle = image(uiImageAxes, [], ...
            'HitTest', 'off', ...
            'PickableParts', 'none');
        axis(uiImageAxes, 'image');
    else
        uiImageAxes = uiImagePreviewHandle.Parent;
    end
    uiMaximaPreviewHandle = scatter(uiImageAxes, nan, nan, 'r+', ...
        'HitTest', 'off', ...
        'PickableParts', 'none');
    
    % parameter dialog
    dlg = dialog('Name', 'Find Image Maxima');
    w = 200;
    lh = 20;
    h = 4 * lh + 30;
    dlg.Position(3) = w;
    dlg.Position(4) = h;
    y = h - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Tophat Filter Radius', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'edit', 'String', num2str(tophatFilterRadius), ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setTophatFilterRadius_);
    y = y - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Gaussian Filter Sigma', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'edit', 'String', num2str(gaussFilterSigma), ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setGaussFilterSigma_);
    y = y - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Min Peak Prominence', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'edit', 'String', num2str(minPeakProminence), ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setMinPeakProminence_);
    y = y - lh;
    uicontrol(dlg, 'Style', 'text', 'String', 'Min Peak Separation', ...
        'Units', 'pixels', 'Position', [0, y, w/2, lh]);
    uicontrol(dlg, 'Style', 'edit', 'String', num2str(minPeakSeparation), ...
        'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
        'Callback', @setMinPeakSeparation_);
    y = 0;
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
        'Units', 'pixels', 'Position', [w/2-55, y, 50, 30], ...
        'Callback', @ok_);
    uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Units', 'normalized', 'Position', [w/2+5, y, 50, 30], ...
        'Callback', 'delete(gcf)');

    % block until dialog closed
    ok = false; % OK dialog button will set back to true
    showMaxima_();
    uiwait(dlg);

    % run this after dialog is closed
    delete(uiMaximaPreviewHandle);
    if exist('tempFig', 'var')
        delete(tempFig);
    end
    
    % dialog OK callback
    function ok_(varargin)
        ok = true;
        delete(dlg);
    end

    % dialog parameter callbacks
    function setTophatFilterRadius_(edit, varargin)
        tophatFilterRadius = str2num(edit.String);
        showMaxima_();
    end
    function setGaussFilterSigma_(edit, varargin)
        gaussFilterSigma = str2num(edit.String);
        showMaxima_();
    end
    function setMinPeakProminence_(edit, varargin)
        minPeakProminence = str2num(edit.String);
        showMaxima_();
    end
    function setMinPeakSeparation_(edit, varargin)
        minPeakSeparation = str2num(edit.String);
        showMaxima_();
    end
    
    % find maxima
    function [xy_, im_] = findMaxima_(fastButApproxMergeOfNearbyMaxima)
        xy_ = [];
        im_ = im;
        try
            % pre-filter image?
            if tophatFilterRadius
                im_ = imtophat(im_, strel('disk', tophatFilterRadius));
            end
            if gaussFilterSigma
                im_ = imgaussfilt(im_, gaussFilterSigma);
            end
            
            % find maxima
            xy_ = findImageMaxima(im_, minPeakProminence, minPeakSeparation, fastButApproxMergeOfNearbyMaxima);
        catch
            xy_ = [];
        end
    end

    % live update of maxima as dialog parameters are changed
    function showMaxima_()
        [xy_, im_] = findMaxima_(true); % approx but fast merging of nearby maxima for live update
        if ~isempty(im_)
            I = imadjust(uint16(im_));
            rgb = cat(3,I,I,I);
            uiImagePreviewHandle.CData = rgb;
            uiImagePreviewHandle.XData = [1 size(rgb,2)];
            uiImagePreviewHandle.YData = [1 size(rgb,1)];
        end
        if ~isempty(xy_)
            uiMaximaPreviewHandle.XData = xy_(:,1);
            uiMaximaPreviewHandle.YData = xy_(:,2);
        else
            uiMaximaPreviewHandle.XData = nan;
            uiMaximaPreviewHandle.YData = nan;
        end
    end

    if ok % else cancel button was pressed in dialog
        xy = findMaxima_(false); % slow but sure merging of all nearby maxima
    end
end