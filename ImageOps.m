classdef ImageOps < handle
    %IMAGEOPS Collection of image operations
    
    methods(Static)
        function [filteredim, sigma] = gaussFilterPreview(im, sigma, previewImage)
            % GAUSSIANFILTERPREVIEW Apply gaussian filter with live preview
            %   Popup dialog to adjust sigma with live preview in
            %   previewImage (image graphics object).
            filteredim = [];
            if isempty(im)
                errordlg('Requires an image.', 'Gaussian Filter');
                return
            end
            if size(im,3) > 1
                errordlg('Requires a grayscale image.', 'Gaussian Filter');
                return
            end
            if (exist('previewImage', 'var') && isgraphics(previewImage)) ...
                    || ~exist('sigma', 'var') || isempty(sigma)
                % parameter dialog
                if ~exist('sigma', 'var') || isempty(sigma)
                    sigma = 0.5;
                end
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
                showPreview_();
                uiwait(dlg); % block until dialog closed
                if ~ok % dialog canceled
                    return
                end
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setSigma_(edit, varargin)
                sigma = str2num(edit.String);
                sigma = max(0, sigma);
                edit.String = num2str(sigma);
                showPreview_();
            end
            function fim = getFilteredImage_()
                try
                    if sigma > 0
                        fim = imgaussfilt(im, sigma);
                    else
                        fim = im;
                    end
                catch
                    fim = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                fim = getFilteredImage_();
                if isempty(fim)
                    return
                end
                I = imadjust(uint16(fim));
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(rgb,2)];
                previewImage.YData = [1 size(rgb,1)];
            end
            % get filtered image
            filteredim = getFilteredImage_();
        end
        
        function [filteredim, diskRadius] = tophatFilterPreview(im, diskRadius, previewImage)
            % TOPHATFILTERPREVIEW Apply tophat filter with live preview
            %   Popup dialog to adjust diskRadius with live preview in
            %   previewImage (image graphics object).
            filteredim = [];
            if isempty(im)
                errordlg('Requires an image.', 'Tophat Filter');
                return
            end
            if size(im,3) > 1
                errordlg('Requires a grayscale image.', 'Gaussian Filter');
                return
            end
            if (exist('previewImage', 'var') && isgraphics(previewImage)) ...
                    || ~exist('diskRadius', 'var') || isempty(diskRadius)
                % parameter dialog
                if ~exist('diskRadius', 'var') || isempty(diskRadius)
                    diskRadius = 2;
                end
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
                ok = false; % OK dialog button will set back to true
                showPreview_();
                uiwait(dlg); % block until dialog closed
                if ~ok % dialog canceled
                    return
                end
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setDiskRadius_(edit, varargin)
                diskRadius = str2num(edit.String);
                diskRadius = max(0, diskRadius);
                edit.String = num2str(diskRadius);
                showPreview_();
            end
            function fim = getFilteredImage_()
                try
                    if diskRadius > 0
                        fim = imtophat(im, strel('disk', diskRadius));
                    else
                        fim = im;
                    end
                catch
                    fim = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                fim = getFilteredImage_();
                if isempty(fim)
                    return
                end
                I = imadjust(uint16(fim));
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(rgb,2)];
                previewImage.YData = [1 size(rgb,1)];
            end
            % get filtered image
            filteredim = getFilteredImage_();
        end
        
        function [maskim, threshold] = thresholdPreview(im, threshold, previewImage)
            % THRESHOLDPREVIEW Apply threshold with live preview
            %   Popup dialog to adjust threshold with live preview in
            %   previewImage (image graphics object).
            maskim = [];
            if isempty(im)
                errordlg('Requires an image.', 'Threshold');
                return
            end
            if size(im,3) > 1
                errordlg('Requires a grayscale image.', 'Gaussian Filter');
                return
            end
            if (exist('previewImage', 'var') && isgraphics(previewImage)) ...
                    || ~exist('threshold', 'var') || isempty(threshold)
                % parameter dialog
                if ~exist('threshold', 'var') || isempty(threshold)
                    %counts = imhist(im, 100);
                    %threshold = otsuthresh(counts);
                    threshold = mean(im(:));
                end
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
                mini = quantile(im(:), 0.01);
                maxi = quantile(im(:), 0.99);
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
                ok = false; % OK dialog button will set back to true
                showPreview_();
                uiwait(dlg); % block until dialog closed
                if ~ok % dialog canceled
                    return
                end
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setThreshold_()
                threshold = str2num(thresholdEdit.String);
                threshold = max(thresholdSlider.Min, min(threshold, thresholdSlider.Max));
                thresholdEdit.String = num2str(threshold);
                thresholdSlider.Value = threshold;
                showPreview_();
            end
            function thresholdMoved_()
                threshold = thresholdSlider.Value;
                thresholdEdit.String = num2str(threshold);
                showPreview_();
            end
            function mask = getThresholdMask_()
                try
                    %mask = imbinarize(im, threshold);
                    mask = im > threshold;
                catch
                    mask = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                mask = getThresholdMask_();
                if isempty(mask)
                    return
                end
                I = imadjust(uint8(mask));
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(mask,2)];
                previewImage.YData = [1 size(mask,1)];
            end
            % get threshold mask
            maskim = getThresholdMask_();
        end
        
        function xy = findMaxima(im, minPeakProminence, minPeakSeparation, fastButApproxMergeOfNearbyMaxima)
            % FINDMAXIMA Find (x,y) coordinates of local maxima in image
            %   xy: [x y] coords of local maxima in image im.
            %	minPeakProminence: size of local peak to be considered as a
            %	maxima minPeakSeparation: min separation between maxima
            %	fastButApproxMergeOfNearbyMaxima: set to true to skip the
            %       final slow but sure merge of nearby maxima. Useful
            %       during a live update when searching for optimal
            %       parameters as a bad choice can result in many maxima
            %       and a very slow final merge. Once the optimal
            %       parameters are found, the slow but sure merge should be
            %       used.
            %	Hint: Might want to smooth image first to reduce maxima due
            %	to noise. e.g. im = imgaussfilt(im, ...)
            xy = [];
            if isempty(im)
                errordlg('Requires an image.', 'Find Maxima');
                return
            end
            if size(im,3) > 1
                errordlg('Requires a grayscale image.', 'Find Maxima');
                return
            end
            % find maxima along each row of image
            im = double(im);
            nrows = size(im,1);
            ncols = size(im,2);
            for row = 1:nrows
                [~,x] = findpeaks(im(row,:), ...
                    'MinPeakProminence', minPeakProminence, 'MinPeakDistance', minPeakSeparation);
                if ~isempty(x)
                    x = reshape(x,[],1);
                    y = repmat(row, size(x));
                    xy = [xy; [x y]];
                end
            end
            if isempty(xy)
                return
            end
            % fast merge nearby maxima (could miss a few)
            % Two repeats usually merges most if not all nearby maxima.
            % Afterwards we'll use a more computationally expensive algorithm to make
            % sure all nearby maxima are merged.
            for repeat = 1:2
                newxy = [];
                didMergeMaxima = false;
                while ~isempty(xy)
                    dists = sqrt(sum((xy - repmat(xy(1,:), [size(xy,1), 1])).^2, 2));
                    near = find(dists < minPeakSeparation);
                    if numel(near) == 1
                        newxy = [newxy; xy(1,:)];
                        xy(1,:) = [];
                    else
                        peaks = zeros([1, numel(near)]);
                        for j = 1:numel(near)
                            peaks(j) = im(xy(near(j),2), xy(near(j),1));
                        end
                        [~,idx] = max(peaks);
                        idx = near(idx(1));
                        newxy = [newxy; xy(idx,:)];
                        xy(near,:) = [];
                        didMergeMaxima = true;
                    end
                end
                xy = newxy;
                if ~didMergeMaxima
                    break
                end
            end
            % return now if we specified NOT to do the slow but sure merge     
            if exist('fastButApproxMergeOfNearbyMaxima', 'var') && fastButApproxMergeOfNearbyMaxima
                return
            end
            % make sure all nearby maxima get merged
            % This is slow, so helps to limit the number of maxima before doing this.
            pd = squareform(pdist(xy));
            pd(logical(eye(size(pd,1)))) = inf; % to keep min() from returning diag elements
            [mind, ind] = min(pd(:));
            while mind < minPeakSeparation
                [i,j] = ind2sub(size(pd), ind);
                rowi = xy(i,2);
                coli = xy(i,1);
                rowj = xy(j,2);
                colj = xy(j,1);
                % remove maxima with smallest pixel intensity
                % this isn't a perfect logic, but it works pretty well in practice
                if im(rowi,coli) >= im(rowj,colj)
                    k = j;
                else
                    k = i;
                end
                xy(k,:) = [];
                pd(:,k) = [];
                pd(k,:) = [];
                [mind, ind] = min(pd(:));
            end
        end
        
        function [xy, minPeakProminence, minPeakSeparation, tophatFilterDiskRadius, gaussFilterSigma] = ...
            findMaximaPreview(im, minPeakProminence, minPeakSeparation, tophatFilterDiskRadius, gaussFilterSigma, previewImage)
            % FINDMAXIMAPREVIEW Find local maxima with live preview
            %   Popup dialog to adjust parameters with live preview in
            %   previewImage (image graphics object).
            xy = [];
            if isempty(im)
                errordlg('Requires an image.', 'Find Maxima');
                return
            end
            if size(im,3) > 1
                errordlg('Requires a grayscale image.', 'Find Maxima');
                return
            end
            if ~exist('tophatFilterDiskRadius', 'var') || isempty(tophatFilterDiskRadius)
                tophatFilterDiskRadius = 0; % no filtering
            end
            if ~exist('gaussFilterSigma', 'var') || isempty(gaussFilterSigma)
                gaussFilterSigma = 0; % no filtering
            end
            if (exist('previewImage', 'var') && isgraphics(previewImage)) ...
                    || ~exist('minPeakProminence', 'var') || isempty(minPeakProminence) ...
                    || ~exist('minPeakSeparation', 'var') || isempty(minPeakSeparation)
                % parameter dialog
                if ~exist('minPeakProminence', 'var') || isempty(minPeakProminence)
                    minPeakProminence = (max(im(:)) - min(im(:))) / 2;
                end
                if ~exist('minPeakSeparation', 'var') || isempty(minPeakSeparation)
                    minPeakSeparation = 3;
                end
                dlg = dialog('Name', 'Find Image Maxima');
                w = 200;
                lh = 20;
                h = 4 * lh + 30;
                dlg.Position(3) = w;
                dlg.Position(4) = h;
                y = h - lh;
                uicontrol(dlg, 'Style', 'text', 'String', 'Tophat Filter Disk Radius', ...
                    'Units', 'pixels', 'Position', [0, y, w/2, lh]);
                uicontrol(dlg, 'Style', 'edit', 'String', num2str(tophatFilterDiskRadius), ...
                    'Units', 'pixels', 'Position', [w/2, y, w/2, lh], ...
                    'Callback', @setTophatFilterDiskRadius_);
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
                    'Units', 'pixels', 'Position', [w/2+5, y, 50, 30], ...
                    'Callback', 'delete(gcf)');
                if exist('previewImage', 'var') && isgraphics(previewImage)
                    ax = previewImage.Parent;
                    hold(ax, 'on');
                    previewMaxima = scatter(ax, nan, nan, 'r+', ...
                        'HitTest', 'off', ...
                        'PickableParts', 'none');
                end
                ok = false; % OK dialog button will set back to true
                showPreview_();
                uiwait(dlg); % block until dialog closed
                if exist('previewMaxima', 'var') && isgraphics(previewMaxima)
                    delete(previewMaxima);
                end
                if ~ok % dialog canceled
                    return
                end
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setTophatFilterDiskRadius_(edit, varargin)
                tophatFilterDiskRadius = str2num(edit.String);
                tophatFilterDiskRadius = max(0, tophatFilterDiskRadius);
                edit.String = num2str(tophatFilterDiskRadius);
                showPreview_();
            end
            function setGaussFilterSigma_(edit, varargin)
                gaussFilterSigma = str2num(edit.String);
                gaussFilterSigma = max(0, gaussFilterSigma);
                edit.String = num2str(gaussFilterSigma);
                showPreview_();
            end
            function setMinPeakProminence_(edit, varargin)
                minPeakProminence = str2num(edit.String);
                showPreview_();
            end
            function setMinPeakSeparation_(edit, varargin)
                minPeakSeparation = str2num(edit.String);
                minPeakSeparation = max(0, minPeakSeparation);
                edit.String = num2str(minPeakSeparation);
                showPreview_();
            end
            function [xy_, im_] = findMaxima_(fastButApproxMergeOfNearbyMaxima)
                xy_ = [];
                im_ = im;
                try
                    % pre-filter image?
                    if tophatFilterDiskRadius
                        im_ = imtophat(im_, strel('disk', tophatFilterDiskRadius));
                    end
                    if gaussFilterSigma
                        im_ = imgaussfilt(im_, gaussFilterSigma);
                    end
                    % find maxima
                    xy_ = ImageOps.findMaxima(im_, minPeakProminence, minPeakSeparation, fastButApproxMergeOfNearbyMaxima);
                catch
                    xy_ = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                [xy_, im_] = findMaxima_(true); % approx but fast merging of nearby maxima for live update
                I = imadjust(uint16(im_));
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(rgb,2)];
                previewImage.YData = [1 size(rgb,1)];
                if ~exist('previewMaxima', 'var') || ~isgraphics(previewMaxima)
                    return
                end
                if isempty(xy_)
                    previewMaxima.XData = nan;
                    previewMaxima.YData = nan;
                else
                    previewMaxima.XData = xy_(:,1);
                    previewMaxima.YData = xy_(:,2);
                end
            end
            % find maxima
            xy = findMaxima_(false); % slow but sure merging of all nearby maxima
        end
    end
end

