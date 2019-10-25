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
        label
        
        % [rows x cols x channels x frames]
        data
        
        % 'path/to/file'
        % !!! only stored in case data needs to be reloaded from file
        filepath
        
        % select frames loaded from filepath. [] => all frames
        % !!! only stored in case data needs to be reloaded from file
        frames
        
        % [x y w h] sub-image bounding box (normalized or pixels) loaded
        % from filepath. [] => entire image
        % !!! only stored in case data needs to be reloaded from file
        viewport
    end
    
    methods
        function obj = ImageStack()
            %IMAGESTACK Construct an instance of this class
            %   Detailed explanation goes here
            obj.label = "";
            obj.data = [];
            obj.filepath = '';
            obj.frames = [];
            obj.viewport = [];
        end
        
        function width = width(obj)
            width = size(obj.data,2);
        end
        
        function height = height(obj)
            height = size(obj.data,1);
        end
        
        function nchannels = numChannels(obj)
            nchannels = size(obj.data,3);
        end
        
        function nframes = numFrames(obj)
            nframes = size(obj.data,4);
        end
        
        function frame = getFrame(obj, t)
            try
                frame = obj.data(:,:,:,t);
            catch
                frame = [];
            end
        end
        
        function load(obj, filepath, prompt, frames, viewport, showOptionsDialog)
            %LOAD Load image stack from file.
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
                if ~isempty(find(rows < 1)) || ~isempty(find(rows > height)) ...
                        || ~isempty(find(cols < 1)) || ~isempty(find(cols > width))
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
    end
end

