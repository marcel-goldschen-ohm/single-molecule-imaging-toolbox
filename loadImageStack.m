function [im, filepath, frames, viewport] = loadImageStack(filepath, frames, viewport, prompt, showOptionsUi)

% Load image stack from file. !!! Only tested for TIFF images.

% - Should handle both grayscale intensity and RGB color images. !!! Only tested for grayscale.
% - Optionally load only specified frames.
% - Optionally load subimage viewport [x y w h] (normalized or pixels).
% - All inputs are optional. Defaults to loading entire user selected image file.

% im: grayscale: [rows x columns x frames] image stack
%     color:     [rows x columns x colors x frames] image stack
% filepath: 'path/to/file', '' => select with file dialog
% frames: [frame indices], [] => all frames
% viewport: [x y w h] bounding box (normalized or pixels), [] => entire image
% prompt: 'file dialog prompt', '' => use default prompt
% showOptionsUi: true => show input dialog for frames and viewport

% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

%% init

im = [];
if ~exist('filepath', 'var'); filepath = ''; end
if ~exist('frames', 'var'); frames = []; end
if ~exist('viewport', 'var'); viewport = []; end
if ~exist('prompt', 'var') || isempty(prompt); prompt = 'Load image (stack)...'; end
if ~exist('showOptionsUi', 'var'); showOptionsUi = false; end

%% get path/to/file

if isempty(filepath) || contains(filepath, '*')
    [file, path] = uigetfile('*.tif', prompt, filepath);
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

%% start timer

tic

%% get image info

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

%% options UI

if showOptionsUi
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

%% frames to load

if isempty(frames)
    frames = 1:nframes;
end

%% find pixels in viewport

rows = 1:height;
cols = 1:width;
nrows = height;
ncols = width;
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
end
if ~isempty(find(rows < 1)) || ~isempty(find(rows > height)) ...
        || ~isempty(find(cols < 1)) || ~isempty(find(cols > width))
    errordlg('ERROR: Viewport outside of image dimensions.');
    return
end

%% allocate memory for entire image stack

% determine image type (grayscale intensity vs RGB) based on first frame
frame = imread(filepath, frames(1), 'Info', info);
fmt = class(frame);
ndim = numel(size(frame));
if ndim == 2 % monochrome
    fprintf('- Allocating memory for %dx%dx%d %s...\n', nrows, ncols, numel(frames), fmt);
    im = zeros([nrows, ncols, numel(frames)], fmt);
    im(:,:,1) = frame(rows,cols);
elseif ndim == 3 % color
    ncolors = size(frame,3);
    fprintf('- Allocating memory for %dx%dx%dx%d %s...\n', nrows, ncols, ncolors, numel(frames), fmt);
    im = zeros([nrows, ncols, ncolors, numel(frames)], fmt);
    im(:,:,:,1) = frame(rows,cols,:);
else
    errordlg(['ERROR: Unsupported image format: ' fmt]);
    return
end

%% load image stack one frame at a time

disp('- Loading image frames...');
str = sprintf('%s (%dx%dx%d@%d %s)', filelabel, width, height, nframes, bpp, color);
wb = waitbar(0, str);
framesPerWaitbarUpdate = floor(double(numel(frames)) / 20);
for t = 2:numel(frames)
    frame = imread(filepath, frames(t), 'Info', info);
    if ndim == 2 % monochrome
        im(:,:,t) = frame(rows,cols);
    elseif ndim == 3 % color
        im(:,:,:,t) = frame(rows,cols,:);
    end
    % updating waitbar is expensive, so do it sparingly
    if mod(t, framesPerWaitbarUpdate) == 0
        waitbar(double(t) / numel(frames), wb);
    end
end
close(wb);

%% stop timer

toc
disp('... Done.');

end
