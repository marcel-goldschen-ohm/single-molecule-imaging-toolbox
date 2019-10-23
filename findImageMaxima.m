function [xy, minPeakProminence, minPeakSeparation, tophatFilterRadius, gaussFilterSigma] = ...
    findImageMaxima(im, minPeakProminence, minPeakSeparation, tophatFilterRadius, gaussFilterSigma, uiImageHandle)

% xy: [x y] coords of local maxima in image im.
% minPeakProminence: size of local peak to be considered as a maxima
% minPeakSeparation: min separation between maxima
% tophatFilterRadius: disk radius of image's tophat pre-filter
% gaussFilterSigma: sigma of image's gaussian pre-filter
% uiImageHandle: handle to image graphics object used for live preview
%                If NOT specified, a temporary figure will be created for
%                the preview.
%
% Hint: Might want to smooth image first to reduce maxima due to noise.
% e.g. im = imgaussfilt(im, ...)
% Options for pre-filtering are available in the dialog too.
%
% If minPeakProminence and minPeakSeparation are specified, simply return
% the located maxima. No UI dialogs or images are shown. In this case, it
% is assumed that all desired pre-filtering has already been applied to im.
%
% If minPeakProminence or minPeakSeparation are empty or do not exist,
% popup a dialog for editing all parameters and update uiImageHandle live
% to show the filtered image overlaid with the located maxima for the
% current parameter values. If uiImageHandle does not exist, create a new
% figure for the live update of the pre-filtering and maxima locations.
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
    
    % default filter values -> no filtering
    if ~exist('tophatFilterRadius', 'var') || isempty(tophatFilterRadius)
        tophatFilterRadius = 0;
    end
    if ~exist('gaussFilterSigma', 'var') || isempty(gaussFilterSigma)
        gaussFilterSigma = 0;
    end
    
    % dialog with parameter settings
    ok = true;
    if ~exist('minPeakProminence', 'var') || ~exist('minPeakSeparation', 'var') ...
            || isempty(minPeakProminence) || isempty(minPeakSeparation)
        
        % default parameters
        if ~exist('minPeakProminence', 'var') || isempty(minPeakProminence)
            minPeakProminence = 1000;
        end
        if ~exist('minPeakSeparation', 'var') || isempty(minPeakSeparation)
            minPeakSeparation = 3;
        end
        
        % image and parent axes on which to show maxima
        if ~exist('uiImageHandle', 'var')
            tempFig = figure('Name', 'Find Image Maxima', 'numbertitle', 'off');
            uiImageAxes = axes(tempFig, ...
                'XTick', [], ...
                'YTick', [], ...
                'YDir', 'reverse');
            uiImageHandle = image(uiImageAxes, [], ...
                'HitTest', 'off', ...
                'PickableParts', 'none');
            axis(uiImageAxes, 'image');
        else
            uiImageAxes = uiImageHandle.Parent;
        end
        uiMaximaHandle = scatter(uiImageAxes, nan, nan, 'r+', ...
            'HitTest', 'off', ...
            'PickableParts', 'none');
        
        % dialog
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
            'Callback', 'delete(dlg)');
        
        ok = false; % OK dialog button will set back to true
        showMaxima_();
        uiwait(dlg);
        
        % run this after dialog is closed
        delete(uiMaximaHandle);
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
    function [xy_, im_] = findMaxima_(slowButSureMergeOfNearbyMaxima)
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
            
            % find maxima along each row of image
            im_ = double(im_);
            nrows = size(im_,1);
            ncols = size(im_,2);
            for row = 1:nrows
                [~,x] = findpeaks(im_(row,:), ...
                    'MinPeakProminence', minPeakProminence, 'MinPeakDistance', minPeakSeparation);
                if ~isempty(x)
                    x = reshape(x,[],1);
                    y = repmat(row, size(x));
                    xy_ = [xy_; [x y]];
                end
            end
            if isempty(xy_)
                return
            end
            
            % fast merge nearby maxima (could miss a few)
            % Two repeats usually merges most if not all nearby maxima.
            % Afterwards we'll use a more computationally expensive algorithm to make
            % sure all nearby maxima are merged.
            for repeat = 1:2
                newxy = [];
                didMergeMaxima = false;
                while ~isempty(xy_)
                    dists = sqrt(sum((xy_ - repmat(xy_(1,:), [size(xy_,1), 1])).^2, 2));
                    near = find(dists < minPeakSeparation);
                    if numel(near) == 1
                        newxy = [newxy; xy_(1,:)];
                        xy_(1,:) = [];
                    else
                        peaks = zeros([1, numel(near)]);
                        for j = 1:numel(near)
                            peaks(j) = im(xy_(near(j),2), xy_(near(j),1));
                        end
                        [~,idx] = max(peaks);
                        idx = near(idx(1));
                        newxy = [newxy; xy_(idx,:)];
                        xy_(near,:) = [];
                        didMergeMaxima = true;
                    end
                end
                xy_ = newxy;
                if ~didMergeMaxima
                    break
                end
            end
            
            % make sure all nearby maxima get merged
            % This is slow, so helps to limit the number of maxima before doing this.
            if exist('slowButSureMergeOfNearbyMaxima', 'var') && ~slowButSureMergeOfNearbyMaxima
                % return now if we specified NOT to do the slow merge
                return
            end
            pd = squareform(pdist(xy_));
            pd(logical(eye(size(pd,1)))) = inf; % to keep min() from returning diag elements
            [mind, ind] = min(pd(:));
            while mind < minPeakSeparation
                [i,j] = ind2sub(size(pd), ind);
                rowi = xy_(i,2);
                coli = xy_(i,1);
                rowj = xy_(j,2);
                colj = xy_(j,1);
                % remove maxima with smallest pixel intensity
                % this isn't a perfect logic, but it works pretty well in practice
                if im(rowi,coli) >= im(rowj,colj)
                    k = j;
                else
                    k = i;
                end
                xy_(k,:) = [];
                pd(:,k) = [];
                pd(k,:) = [];
                [mind, ind] = min(pd(:));
            end
        catch
            xy_ = [];
        end
    end

    % live update of maxima as dialog parameters are changed
    function showMaxima_()
        [xy_, im_] = findMaxima_(false); % approx but fast merging of nearby maxima for live update
        if ~isempty(im_)
            I = imadjust(uint16(im_));
            rgb = cat(3,I,I,I);
            uiImageHandle.CData = rgb;
            uiImageHandle.XData = [1 size(rgb,2)];
            uiImageHandle.YData = [1 size(rgb,1)];
        end
        if ~isempty(xy_)
            uiMaximaHandle.XData = xy_(:,1);
            uiMaximaHandle.YData = xy_(:,2);
        else
            uiMaximaHandle.XData = nan;
            uiMaximaHandle.YData = nan;
        end
    end

    if ok % else cancel button was pressed in dialog
        xy = findMaxima_(true); % slow but sure merging of all nearby maxima
    end
end
