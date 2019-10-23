function xy = findImageMaxima(im, minPeakProminence, minPeakSeparation, fastButApproxMergeOfNearbyMaxima)

% xy: [x y] coords of local maxima in image im.
% minPeakProminence: size of local peak to be considered as a maxima
% minPeakSeparation: min separation between maxima
% fastButApproxMergeOfNearbyMaxima: set to true to skip the final slow but
%   sure merge of nearby maxima. Useful during a live update when searching
%   for optimal parameters as a bad choice can result in many maxima and a
%   very slow final merge. Once the optimal parameters are found, the slow
%   but sure merge should be used.
%
% Hint: Might want to smooth image first to reduce maxima due to noise.
% e.g. im = imgaussfilt(im, ...)
%
% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

    xy = [];

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
