classdef ImageStack < handle
    %IMAGESTACK Handle to image stack data.
    %   Pass this handle object around to avoid copying large image stack
    %   data arrays. Stores info (e.g. filepath, frames, viewport) for
    %   convenient reloading of data from file.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % string label
        label = "";
        
        % [rows x cols x channels x frames] image pixel data
        data = [];
        
        % 'path/to/image/file'
        % !!! only stored in case data needs to be reloaded from file
        filepath = '';
        
        % select frames loaded from filepath. [] => all frames
        % !!! only stored in case data needs to be reloaded from file
        frames = [];
        
        % [x y w h] sub-image bounding box (normalized or pixels) loaded
        % from filepath. [] => entire image
        % !!! only stored in case data needs to be reloaded from file
        viewport = [];
    end
    
    methods
        function obj = ImageStack()
            %IMAGESTACK Construct an instance of this class
        end
        
        function width = width(obj)
            %WIDTH Return image column width
            width = size(obj.data,2);
        end
        
        function height = height(obj)
            %HEIGHT Return image row height
            height = size(obj.data,1);
        end
        
        function nchannels = numChannels(obj)
            %NUMCHANNELS Return number of channels in image
            nchannels = size(obj.data,3);
        end
        
        function nframes = numFrames(obj)
            %NUMFRAMES Return number of frames in image stack
            nframes = size(obj.data,4);
        end
        
        function frame = frame(obj, t)
            %FRAME Return the pixel data for a single image frame
            frame = obj.data(:,:,:,t);
        end
        
        function label = getLabelWithSizeInfo(obj)
            %GETLABELWITHSIZEINFO Return the image label with size info
            if isempty(obj.data)
                label = obj.label;
                return
            end
            w = obj.width();
            h = obj.height();
            c = obj.numChannels();
            t = obj.numFrames();
            if c == 1 && t == 1
                label = sprintf('%s (%dx%d)', obj.label, w, h);
            elseif c == 1
                label = sprintf('%s (%dx%d)x%d', obj.label, w, h, t);
            elseif t == 1
                label = sprintf('%s (%dx%dx%d)', obj.label, w, h, c);
            else
                label = sprintf('%s (%dx%dx%d)x%d', obj.label, w, h, c, t);
            end
        end
        
        function load(obj, filepath, prompt, frames, viewport, showOptionsDialog)
            %LOAD Load image stack from file
            %   Should handle both grayscale and color images.
            %   !!! Only tested for grayscale TIFF images.
            %	showOptionsDialog: true => show frames and viewport dialog
            
            % get path/to/file
            if ~exist('filepath', 'var') || isempty(filepath)
                filepath = '';
                defaultFilepath = obj.filepath;
            else
                defaultFilepath = filepath;
            end
            if isempty(filepath) || contains(filepath, '*')
                if ~exist('prompt', 'var') || isempty(prompt)
                    prompt = 'Load image stack...';
                end
                [file, path] = uigetfile('*.tif', prompt, defaultFilepath);
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            % make sure filepath is valid
            if ~exist(filepath, 'file')
                errordlg(['ERROR: File not found: ' filepath]);
                return
            end
            [path, file, ext] = fileparts(filepath);
            filelabel = file;
            filelabel(strfind(filelabel, '_')) = ' ';
            
            % start timer
            tic

            % get image info
            info = imfinfo(filepath);
            nframes = numel(info);
            if nframes == 0
                errordlg(['ERROR: Zero image frames detected in ' file ext]);
                return
            end
            width = info(1).Width;
            height = info(1).Height;
            bpp = info(1).BitDepth;
            color = info(1).ColorType;
            fprintf('Loading %dx%dx%d@%d %s image %s...\n', width, height, nframes, bpp, color, [file ext]);
            
            % options UI
            if exist('showOptionsDialog', 'var') && showOptionsDialog
                labels = {};
                defaults = {};
                if nframes > 1
                    labels{end+1} = ['Frames 1:' num2str(nframes) ' (first:last, first:stride:last, empty=all)'];
                    defaults{end+1} = ['1:' num2str(nframes)];
                end
                labels{end+1} = 'Viewport (x, y, w, h) normalized or pixels, empty=full';
                defaults{end+1} = '';
                answer = inputdlg(labels, 'Load Image Stack Options', 1, defaults);
                if ~isempty(answer)
                    if nframes > 1
                        framesAnswer = answer{1};
                        viewportAnswer = answer{2};
                    else
                        framesAnswer = '';
                        viewportAnswer = answer{1};
                    end
                    if isempty(framesAnswer)
                        frames = 1:nframes;
                    else
                        fields = strsplit(framesAnswer, ':');
                        if numel(fields) == 1
                            frames = str2num(fields{1});
                        elseif numel(fields) == 2
                            frames = str2num(fields{1}):str2num(fields{2});
                        elseif numel(fields) == 3
                            frames = str2num(fields{1}):str2num(fields{2}):str2num(fields{3});
                        else
                            errordlg(['ERROR: Invalid frames range: ' framesAnswer]);
                            return
                        end
                    end
                    if isempty(viewportAnswer)
                        viewport = [];
                    else
                        fields = strsplit(viewportAnswer, ',');
                        if numel(fields) == 4
                            viewport = [str2num(fields{1}), str2num(fields{2}), str2num(fields{3}), str2num(fields{4})];
                        else
                            errordlg(['ERROR: Invalid viewport: ' viewportAnswer]);
                            return
                        end
                    end
                end
            end
            
            % frames to load
            if ~exist('frames', 'var') || isempty(frames)
                frames = 1:nframes;
            end
            
            % find pixels in viewport
            rows = 1:height;
            cols = 1:width;
            nrows = height;
            ncols = width;
            if ~exist('viewport', 'var')
                viewport = [];
            end
            if numel(viewport) == 4
                vx = viewport(1);
                vy = viewport(2);
                vw = viewport(3);
                vh = viewport(4);
                if vx <= 1 && vy <= 1 && vw <= 1 && vh <= 1
                    % viewport = normalized fraction of frame
                    nrows = int32(round(vh * nrows));
                    ncols = int32(round(vw * ncols));
                    row0 = 1 + int32(round(vy * nrows));
                    col0 = 1 + int32(round(vx * ncols));
                    rows = row0:row0+nrows-1;
                    cols = col0:col0+ncols-1;
                else
                    % viewport = pixels bbox
                    nrows = int32(round(vh));
                    ncols = int32(round(vw));
                    row0 = int32(round(vy));
                    col0 = int32(round(vx));
                    rows = row0:row0+nrows-1;
                    cols = col0:col0+ncols-1;
                end
                if ~isempty(find(rows < 1, 1)) || ~isempty(find(rows > height, 1)) ...
                        || ~isempty(find(cols < 1, 1)) || ~isempty(find(cols > width, 1))
                    errordlg('ERROR: Viewport outside of image dimensions.');
                    return
                end
            end
            
            % allocate memory for entire image stack
            % determine image type (grayscale vs RGB) based on first frame
            frame = imread(filepath, frames(1), 'Info', info);
            fmt = class(frame);
            nchannels = size(frame,3);
            fprintf('- Allocating memory for %dx%dx%dx%d %s...\n', nrows, ncols, nchannels, numel(frames), fmt);
            obj.data = zeros([nrows ncols nchannels numel(frames)], fmt);
            obj.data(:,:,:,1) = frame(rows,cols,:);
            
            % load image stack one frame at a time
            disp('- Loading image frames...');
            str = sprintf('%s (%dx%dx%d@%d %s)', filelabel, width, height, nframes, bpp, color);
            wb = waitbar(0, str);
            framesPerWaitbarUpdate = floor(double(numel(frames)) / 20);
            for t = 2:numel(frames)
                frame = imread(filepath, frames(t), 'Info', info);
                obj.data(:,:,:,t) = frame(rows,cols,:);
                % updating waitbar is expensive, so do it sparingly
                if mod(t, framesPerWaitbarUpdate) == 0
                    waitbar(double(t) / numel(frames), wb);
                end
            end
            close(wb);
            
            % set properties
            obj.filepath = filepath;
            if isequal(frames, 1:nframes)
                obj.frames = [];
            else
                obj.frames = frames;
            end
            obj.viewport = viewport;

            % stop timer
            toc
            disp('... Done.');
        end
        
        function reload(obj)
            %RELOAD Reload image data from obj.filepath
            %   Only load subimage slices as defined by obj.frames and
            %   obj.viewport
            if isempty(obj.filepath)
                return
            end
            if isfile(obj.filepath)
                obj.load(obj.filepath, '', obj.frames, obj.viewport, false);
            else
                errordlg(['Invalid filepath: ' obj.filepath], 'Image Stack File Not Found');
            end
        end
        
        function imstack = duplicate(obj, frames)
            %DUPLICATE Return a copy of the specified frames
            imstack = ImageStack;
            if isempty(obj.data)
                errordlg('Requires an image.', 'Duplicate');
                return
            end
            nframes = obj.numFrames();
            if nframes == 1
                frames = 1;
            elseif ~exist('frames', 'var') || isempty(frames)
                % parameter dialog
                frames = 1:nframes;
                dlg = dialog('Name', 'Duplicate');
                dlg.Position(3) = 200;
                dlg.Position(4) = 50;
                uicontrol(dlg, 'Style', 'text', 'String', 'Frames', ...
                    'Units', 'normalized', 'Position', [0, 0.6, 0.5, 0.4]);
                uicontrol(dlg, 'Style', 'edit', 'String', [ num2str(frames(1)) '-' num2str(frames(end))], ...
                    'Units', 'normalized', 'Position', [0.5, 0.6, 0.5, 0.4], ...
                    'Callback', @setFrames_);
                uicontrol(dlg, 'Style', 'pushbutton', 'String', 'OK', ...
                    'Units', 'normalized', 'Position', [0.1, 0, 0.4, 0.6], ...
                    'Callback', @ok_);
                uicontrol(dlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
                    'Units', 'normalized', 'Position', [0.5, 0, 0.4, 0.6], ...
                    'Callback', 'delete(gcf)');
                ok = false; % OK button will set to true
                uiwait(dlg); % block until dialog closed
                if ~ok
                    return
                end
            end
            % dialog callbacks
            function setFrames_(edit, varargin)
                firstlast = split(edit.String, '-');
                first = str2num(firstlast{1});
                if numel(firstlast) == 2
                    last = str2num(firstlast{2});
                    frames = max(1, first):min(last, nframes);
                else
                    frames = first;
                end
            end
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            % duplicate
            try
                imstack.data = obj.data(:,:,:,frames);
                if numel(frames) > 1
                    imstack.label = string(sprintf('%s %d-%d', obj.label, frames(1), frames(end)));
                else
                    imstack.label = string(sprintf('%s %d', obj.label, frames));
                end
            catch
            end
        end
        
        function imstack = zproject(obj, frames, method, previewImage)
            imstack = ImageStack;
            nframes = obj.numFrames();
            if nframes <= 1
                errordlg('Requires an image stack.', 'Z-Project');
                return
            end
            if (exist('previewImage', 'var') && isgraphics(previewImage)) ...
                    || ~exist('method', 'var') || isempty(method) ... 
                    || ~exist('frames', 'var') || isempty(frames)
                % parameter dialog
                if ~exist('method', 'var') || isempty(method)
                    method = 'Mean';
                end
                if ~exist('frames', 'var') || isempty(frames)
                    frames = 1:nframes;
                end
                methods = {'Mean', 'Min', 'Max'};
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
                ok = false; % OK dialog button will set back to true
                showPreview_();
                uiwait(dlg); % block until dialog closed
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setMethod_(popupmenu, varargin)
                method = methods{popupmenu.Value};
                showPreview_();
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
                showPreview_();
            end
            function frame = getZProjectedFrame_()
                frame = [];
                if isempty(frames)
                    return
                end
                try
                    if method == "Mean"
                        frame = mean(obj.data(:,:,:,frames), 4);
                    elseif method == "Min"
                        frame = min(obj.data(:,:,:,frames), [], 4);
                    elseif method == "Max"
                        frame = max(obj.data(:,:,:,frames), [], 4);
                    end
                catch
                    frame = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                frame = getZProjectedFrame_();
                if isempty(frame)
                    return
                end
                if size(frame,3) == 1
                    I = imadjust(frame);
                    rgb = cat(3,I,I,I);
                elseif size(frame,3) == 3
                    rgb = imadjust(frame);
                else
                    return
                end
                previewImage.CData = rgb;
                previewImage.XData = [1 size(rgb,2)];
                previewImage.YData = [1 size(rgb,1)];
            end
            if ~ok % dialog canceled
                return
            end
            imstack.data = getZProjectedFrame_();
            imstack.label = string(sprintf('%s %s %d-%d', obj.label, method, frames(1), frames(end)));
        end
        
        function applyGaussianFilter(obj, sigma, previewFrame, previewImage)
            if isempty(obj.data)
                errordlg('Requires an image.', 'Gaussian Filter');
                return
            end
            nchannels = obj.numChannels();
            if nchannels > 1
                errordlg('Requires a grayscale image.', 'Gaussian Filter');
                return
            end
            if ~exist('sigma', 'var')
                sigma = [];
            end
            if ~exist('previewFrame', 'var') || isempty(previewFrame)
                previewFrame = 1;
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            nframes = obj.numFrames();
            previewFrame = max(1, min(previewFrame, nframes));
            im = obj.frame(previewFrame);
            [im, sigma] = ImageStack.gaussianFilterImage(im, sigma, previewImage);
            if isempty(im)
                return
            end
            for c = 1:nchannels
                obj.data(:,:,c,previewFrame) = imgaussfilt(obj.data(:,:,c,previewFrame), sigma);
            end
            if nframes > 1
                if questdlg('Apply Gaussian filter to all frames in stack?', ...
                        'Filter entire image stack?', ...
                        'OK', 'Cancel', 'Cancel') == "Cancel"
                    return
                end
                wb = waitbar(0, 'Filtering stack...');
                framesPerWaitbarUpdate = floor(double(nframes) / 20);
                for t = 1:nframes
                    if t ~= previewFrame
                        for c = 1:nchannels
                            obj.data(:,:,c,t) = imgaussfilt(obj.data(:,:,c,t), sigma);
                        end
                        % updating waitbar is expensive, so do it sparingly
                        if mod(t, framesPerWaitbarUpdate) == 0
                            waitbar(double(t) / nframes, wb);
                        end
                    end
                end
                close(wb);
            end
        end
        
        function applyTophatFilter(obj, diskRadius, previewFrame, previewImage)
            if isempty(obj.data)
                errordlg('Requires an image.', 'Tophat Filter');
                return
            end
            nchannels = obj.numChannels();
            if nchannels > 1
                errordlg('Requires a grayscale image.', 'Tophat Filter');
                return
            end
            if ~exist('diskRadius', 'var')
                diskRadius = [];
            end
            if ~exist('previewFrame', 'var') || isempty(previewFrame)
                previewFrame = 1;
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            nframes = obj.numFrames();
            previewFrame = max(1, min(previewFrame, nframes));
            im = obj.frame(previewFrame);
            [im, diskRadius] = ImageStack.tophatFilterImage(im, diskRadius, previewImage);
            if isempty(im)
                return
            end
            disk = strel('disk', diskRadius);
            for c = 1:nchannels
                obj.data(:,:,c,previewFrame) = imtophat(obj.data(:,:,c,previewFrame), disk);
            end
            if nframes > 1
                if questdlg('Apply tophat filter to all frames in stack?', ...
                        'Filter entire image stack?', ...
                        'OK', 'Cancel', 'Cancel') == "Cancel"
                    return
                end
                wb = waitbar(0, 'Filtering stack...');
                framesPerWaitbarUpdate = floor(double(nframes) / 20);
                for t = 1:nframes
                    if t ~= previewFrame
                        for c = 1:nchannels
                            obj.data(:,:,c,t) = imtophat(obj.data(:,:,c,t), disk);
                        end
                        % updating waitbar is expensive, so do it sparingly
                        if mod(t, framesPerWaitbarUpdate) == 0
                            waitbar(double(t) / nframes, wb);
                        end
                    end
                end
                close(wb);
            end
        end
        
        function imstack = getThresholdMask(obj, frame, threshold, previewImage)
            imstack = ImageStack;
            if isempty(obj.data)
                errordlg('Requires an image.', 'Threshold');
                return
            end
            nchannels = obj.numChannels();
            if nchannels > 1
                errordlg('Requires a grayscale image.', 'Threshold');
                return
            end
            if ~exist('frame', 'var') || isempty(frame)
                frame = 1;
            end
            if ~exist('threshold', 'var')
                threshold = [];
            end
            if ~exist('previewImage', 'var')
                previewImage = gobjects(0);
            end
            nframes = obj.numFrames();
            frame = max(1, min(frame, nframes));
            im = obj.frame(frame);
            [mask, threshold] = ImageStack.thresholdImage(im, threshold, previewImage);
            if isempty(mask)
                return
            end
            imstack.data = mask;
            imstack.label = string(sprintf('%s Threshold %f', obj.label, threshold));
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            if isstruct(s)
                obj = ImageStack();
                for prop = fieldnames(obj)
                    if isfield(s, prop)
                        try
                            obj.(prop) = s.(prop);
                        catch
                            disp(['!!! ERROR: ' class(obj) ': Failed to load property ' prop]);
                        end
                    end
                end
                unloadedProps = setdiff(fieldnames(s), fieldnames(obj));
                if ~isempty(unloadedProps)
                    disp(['!!! WARNING: ' class(obj) ': Did NOT load invalid properties: ' strjoin(unloadedProps, ',')]);
                end
            else
                obj = s;
            end
        end
        
        function [filteredim, sigma] = gaussianFilterImage(im, sigma, previewImage)
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
                    sigma = 1;
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
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setSigma_(edit, varargin)
                sigma = str2num(edit.String);
                showPreview_();
            end
            function fim = getFilteredImage_()
                try
                    fim = imgaussfilt(im, sigma);
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
                I = imadjust(fim);
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(rgb,2)];
                previewImage.YData = [1 size(rgb,1)];
            end
            if ~ok % dialog canceled
                return
            end
            filteredim = getFilteredImage_();
        end
        
        function [filteredim, diskRadius] = tophatFilterImage(im, diskRadius, previewImage)
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
            end
            % dialog callbacks
            function ok_(varargin)
                ok = true;
                delete(dlg);
            end
            function setDiskRadius_(edit, varargin)
                diskRadius = str2num(edit.String);
                showPreview_();
            end
            function fim = getFilteredImage_()
                try
                    fim = imtophat(im, strel('disk', diskRadius));
                catch
                    fim = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                fim = getFilteredFrame_();
                if isempty(fim)
                    return
                end
                I = imadjust(fim);
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(rgb,2)];
                previewImage.YData = [1 size(rgb,1)];
            end
            if ~ok % dialog canceled
                return
            end
            filteredim = getFilteredImage_();
        end
        
        function [maskim, threshold] = thresholdImage(im, threshold, previewImage)
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
                    counts = imhist(im, 100);
                    threshold = otsuthresh(counts);
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
            function mask = getThresholdedMask_()
                try
                    mask = imbinarize(im, threshold);
                catch
                    mask = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                mask = getThresholdedMask_();
                if isempty(mask)
                    return
                end
                I = imadjust(mask);
                rgb = cat(3,I,I,I);
                previewImage.CData = rgb;
                previewImage.XData = [1 size(mask,2)];
                previewImage.YData = [1 size(mask,1)];
            end
            if ~ok % dialog canceled
                return
            end
            maskim = getThresholdedMask_();
        end
        
        function xy = findImageMaxima(im, minPeakProminence, minPeakSeparation, fastButApproxMergeOfNearbyMaxima)
            % xy: [x y] coords of local maxima in image im.
            % minPeakProminence: size of local peak to be considered as a maxima
            % minPeakSeparation: min separation between maxima
            % fastButApproxMergeOfNearbyMaxima: set to true to skip the final slow but
            %   sure merge of nearby maxima. Useful during a live update when searching
            %   for optimal parameters as a bad choice can result in many maxima and a
            %   very slow final merge. Once the optimal parameters are found, the slow
            %   but sure merge should be used.
            % Hint: Might want to smooth image first to reduce maxima due to noise.
            % e.g. im = imgaussfilt(im, ...)
            
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
    end
end

