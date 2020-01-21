classdef ImageStack < handle
    %IMAGESTACK 2D image or 3D image stack.
    %   Images MUST be grayscale intensity 8-bit, 16-bit or floating point.
    %   Pass this handle object around to avoid copying large image stack
    %   data arrays. It is also possible to just load the file info, and
    %   then to grab frames from the file as needed.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % string label
        label = "";
        
        % [rows x cols x frames] image pixel data
        data = [];
        
        % frame <--> time
        frameIntervalSec = [];
        
        % file* properties are for referencing data in an image file.
        
        % struct array of file info for each frame as returned by imfinfo.
        % Note: Array may include only a subset of the frames in the file
        % as specified by fileFrames.
        fileInfo = struct.empty;
        
        % Stack frames loaded from file. [] => all frames
        fileFrames = [];
        
        % Pixel region loaded from file. {} => full image
        filePixelRegion = {}; % {[rowstart rowend], [colstart colend]}
        
        % Data modified as compared to file?
        fileDataModified = false;
    end
    
    properties (Dependent)
        width
        height
        numFrames
        totalDuration
    end
    
    events
        LabelChanged
        DataChanged
        FrameIntervalChanged
    end
    
    methods
        function obj = ImageStack()
            %IMAGESTACK Constructor.
        end
        
        function set.label(obj, s)
            obj.label = string(s);
            notify(obj, 'LabelChanged');
        end
        function label = getLabelWithInfo(obj)
            %GETLABELWITHINFO Return the image label with size/rate info
            w = obj.width;
            h = obj.height;
            t = obj.numFrames;
            if t == 1
                label = sprintf('%s (%dx%d)', obj.label, w, h);
            elseif t > 1
                label = sprintf('%s (%dx%d)x%d', obj.label, w, h, t);
            else
                label = obj.label;
            end
            if ~isempty(obj.frameIntervalSec)
                Hz = 1.0 / obj.frameIntervalSec;
                label = sprintf('%s@%.1fHz', label, Hz);
            end
        end
        function editLabel(obj)
            answer = inputdlg({'Label'}, 'Image Label', 1, {char(obj.label)});
            if isempty(answer)
                return
            end
            obj.label = string(answer{1});
        end
        
        function w = get.width(obj)
            w = 0;
            if ~isempty(obj.data)
                w = size(obj.data, 2);
            elseif ~isempty(obj.fileInfo)
                try
                    if ~isempty(obj.filePixelRegion)
                        cols = obj.filePixelRegion{2};
                        if numel(cols) == 2
                            w = 1 + diff(cols);
                            return
                        end
                    end
                catch
                end
                w = obj.fileInfo(1).Width;
            end
        end
        function h = get.height(obj)
            h = 0;
            if ~isempty(obj.data)
                h = size(obj.data, 1);
            elseif ~isempty(obj.fileInfo)
                try
                    if ~isempty(obj.filePixelRegion)
                        rows = obj.filePixelRegion{1};
                        if numel(rows) == 2
                            h = 1 + diff(rows);
                            return
                        end
                    end
                catch
                end
                h = obj.fileInfo(1).Height;
            end
        end
        function n = get.numFrames(obj)
            n = 0;
            if ~isempty(obj.data)
                n = size(obj.data, 3);
            elseif ~isempty(obj.fileInfo)
                n = numel(obj.fileInfo);
            end
        end
        function dur = get.totalDuration(obj)
            if isempty(obj.frameIntervalSec)
                dur = obj.numFrames;
            else
                dur = obj.numFrames * obj.frameIntervalSec;
            end
        end
        
        function set.frameIntervalSec(obj, dt)
            obj.frameIntervalSec = dt;
            notify(obj, 'FrameIntervalChanged');
            notify(obj, 'LabelChanged'); % interval could alter getLabelWithInfo() 
        end
        function editFrameInterval(obj)
            answer = inputdlg({'Frame Interval (sec)'}, char(obj.label), 1, {num2str(obj.frameIntervalSec)});
            if isempty(answer)
                return
            end
            obj.frameIntervalSec = str2num(answer{1});
        end
        
        function frame = getFrame(obj, t)
            %GETFRAME Return the pixel data for the specified frame.
%             if ~exist('t', 'var') || isempty(t)
%                 t = obj.selectedFrameIndex;
%             end
            frame = [];
            if ~t
                return
            end
            if ~isempty(obj.data)
                try
                    frame = obj.data(:,:,t);
                catch
                    frame = [];
                end
            end
            if ~isempty(obj.fileInfo)
                try
                    frame = obj.getFrameFromFile(t);
                catch
                    frame = [];
                end
            end
        end
        function frame = getFrameFromFile(obj, t)
            %GETFRAMEFROMFILE Return the file pixel data for the specified frame.
            frame = [];
            if isempty(obj.fileInfo)
                return
            end
            try
                if ~isempty(obj.filePixelRegion)
                    frame = imread(obj.fileInfo(t).Filename, 'Info', obj.fileInfo(t), ...
                        'PixelRegion', obj.filePixelRegion);
                else
                    frame = imread(obj.fileInfo(t).Filename, 'Info', obj.fileInfo(t));
                end
            catch
                frame = [];
            end
        end
        
        function clear(obj)
            %obj.label = "";
            obj.data = [];
            obj.frameIntervalSec = [];
            obj.fileInfo = struct.empty;
            obj.fileFrames = [];
            obj.filePixelRegion = {};
            obj.fileDataModified = false;
        end
        function load(obj, filepath, prompt, frames, pixelRegion, showOptionsDialog, loadFileInfoOnly)
            %LOAD Load image stack file
            %	showOptionsDialog: true => show frames and pixelRegion dialog
            %   loadFileInfoOnly: true => do NOT load stack data
            
            % get path/to/file
            if ~exist('filepath', 'var') || isempty(filepath)
                filepath = '';
            end
            if isempty(filepath) || contains(filepath, '*')
                if ~exist('prompt', 'var') || isempty(prompt)
                    prompt = 'Load image (stack) file...';
                end
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
            
            % label based on filename
            filelabel = file;
            filelabel(strfind(filelabel, '_')) = ' ';
            
            % start timer
            tic

            % get image info
            info = imfinfo(filepath);
            nframes = numel(info);
            if nframes == 0
                errordlg(['Zero image frames detected in ' file ext]);
                return
            end
            w = info(1).Width;
            h = info(1).Height;
            bpp = info(1).BitDepth;
            color = info(1).ColorType;
            if color ~= "grayscale"
                errordlg({['Invalid color type ' color ' for ' file ext], ...
                    'Only grayscale intensity images are supported.'});
                return
            end
            fprintf('Loading %dx%dx%d@%d %s image %s...\n', w, h, nframes, bpp, color, [file ext]);
            
            % options UI
            if exist('showOptionsDialog', 'var') && showOptionsDialog
                labels = {};
                defaults = {};
                if nframes > 1
                    labels{end+1} = ['Frames 1:' num2str(nframes) ' (first:last, first:stride:last, empty=all)'];
                    if ~exist('frames', 'var') || isempty(frames)
                        defaults{end+1} = sprintf('1:%d', nframes);
                    else
                        stride = unique(diff(frames));
                        if numel(stride) == 1
                            if stride == 1
                                defaults{end+1} = sprintf('%d:%d', frames(1), frames(end));
                            else
                                defaults{end+1} = sprintf('%d:%d:%d', frames(1), stride, frames(end));
                            end
                        else
                            defaults{end+1} = 'use currently specified frames';
                        end
                    end
                end
                labels{end+1} = 'Pixel Region (rows first:last, columns first:last), empty=full';
                if ~exist('pixelRegion', 'var') || isempty(pixelRegion)
                    defaults{end+1} = sprintf('1:%d, 1:%d', h, w);
                else
                    try
                        rowlim = pixelRegion{1};
                        collim = pixelRegion{2};
                        defaults{end+1} = sprintf('%d:%d, %d:%d', rowlim(1), rowlim(2), collim(1), collim(2));
                    catch
                        defaults{end+1} = sprintf('1:%d, 1:%d', h, w);
                    end
                end
                answer = inputdlg(labels, 'Load Image Stack Options', 1, defaults);
                if isempty(answer)
                    return
                else
                    if nframes > 1
                        framesAnswer = answer{1};
                        pixelRegionAnswer = answer{2};
                    else
                        framesAnswer = '';
                        pixelRegionAnswer = answer{1};
                    end
                    if isempty(framesAnswer)
                        frames = [];
                    elseif framesAnswer == "use currently specified frames"
                        % leave frames as is
                    else
                        fields = strsplit(framesAnswer, ':');
                        if numel(fields) == 1
                            frames = str2num(fields{1});
                        elseif numel(fields) == 2
                            frames = str2num(fields{1}):str2num(fields{2});
                        elseif numel(fields) == 3
                            frames = str2num(fields{1}):str2num(fields{2}):str2num(fields{3});
                        else
                            errordlg(['Invalid frames range: ' framesAnswer]);
                            return
                        end
                    end
                    if isempty(pixelRegionAnswer)
                        pixelRegion = {};
                    else
                        ok = false;
                        fields = strsplit(pixelRegionAnswer, ',');
                        if numel(fields) == 2
                            rows = strsplit(fields{1}, ':');
                            cols = strsplit(fields{2}, ':');
                            if numel(rows) == 2 && numel(cols) == 2
                                rowstart = str2num(rows{1});
                                rowend = str2num(rows{2});
                                colstart = str2num(cols{1});
                                colend = str2num(cols{2});
                                pixelRegion = {[rowstart rowend], [colstart colend]};
                                ok = true;
                            end
                        end
                        if ~ok
                            errordlg(['Invalid pixel region: ' pixelRegionAnswer]);
                            return
                        end
                    end
                end
            end
            
            % frames to load
            if exist('frames', 'var') && ~isempty(frames)
                if isequal(frames, 1:nframes)
                    frames = []; % all frames
                else
                    frames(frames < 1) = [];
                    frames(frames > nframes) = [];
                    if isempty(frames)
                        errordlg('Invalid frames.');
                        return
                    end
                    % keep info for selected frames only
                    info = info(frames);
                end
            else
                frames = []; % all frames
            end
            
            % pixel region to load
            if exist('pixelRegion', 'var') && ~isempty(pixelRegion)
                if isequal(pixelRegion, {[1 w], [1 h]})
                    pixelRegion = {}; % full frame
                else
                    ... % check validity of pixelRegion
                end
            else
                pixelRegion = {}; % full frame
            end
            
            % set file properties
            oldFileInfo = obj.fileInfo;
            oldFileFrames = obj.fileFrames;
            oldFilePixelRegion = obj.filePixelRegion;
            obj.fileInfo = info;
            [obj.fileInfo.Filename] = deal(filepath);
            obj.fileFrames = frames;
            obj.filePixelRegion = pixelRegion;
            
            % determine image params from first frame
            frame = obj.getFrameFromFile(1);
            if size(frame, 3) > 1
                errordlg({'Multiple channels detected.', ...
                    'Only grayscale intensity images are supported.'});
                obj.fileInfo = oldFileInfo;
                obj.fileFrames = oldFileFrames;
                obj.filePixelRegion = oldFilePixelRegion;
                return
            end
            fmt = class(frame);
            nrows = size(frame, 1);
            ncols = size(frame, 2);
            nframes = numel(obj.fileInfo);
            
            if ~exist('loadFileInfoOnly', 'var') || ~loadFileInfoOnly
                % allocate memory for entire image stack
                fprintf('- Allocating memory for (%dx%d)x%d %s...\n', nrows, ncols, nframes, fmt);
                obj.data = zeros([nrows ncols nframes], fmt);
                obj.data(:,:,1) = frame;

                % load image stack one frame at a time
                disp('- Loading frames...');
                str = sprintf('%s (%dx%d)x%d', filelabel, ncols, nrows, nframes);
                wb = waitbar(0, str);
                framesPerWaitbarUpdate = floor(double(nframes) / 20);
                for t = 2:nframes
                    obj.data(:,:,t) = obj.getFrameFromFile(t);
                    % updating waitbar is expensive, so do it sparingly
                    if mod(t, framesPerWaitbarUpdate) == 0
                        waitbar(double(t) / nframes, wb);
                    end
                end
                close(wb);
            else
                obj.data = [];
            end

            % stop timer
            toc
            
            obj.fileDataModified = false; % matches file at this point
            notify(obj, 'DataChanged');
%             obj.selectedFrameIndex = 1;
            disp('... Done.');
        end
        function reload(obj, showOptionsDialog, loadFileInfoOnly)
            if ~exist('showOptionsDialog', 'var') || isempty(showOptionsDialog)
                showOptionsDialog = false;
            end
            if ~exist('loadFileInfoOnly', 'var') || isempty(loadFileInfoOnly)
                loadFileInfoOnly = false;
            end
            if isempty(obj.fileInfo)
                obj.load('', '', [], {}, showOptionsDialog, loadFileInfoOnly);
                return
            end
            
            if obj.fileDataModified
                if questdlg( ...
                        {'Data has been modified from original file.', ...
                        'Reloading will discard any modifications.', ...
                        'Continue anyways?'}, ...
                        'WARNING') ~= "Yes"
                    return
                end
            end
            
            if isfile(obj.fileInfo(1).Filename)
                obj.load(obj.fileInfo(1).Filename, '', obj.fileFrames, obj.filePixelRegion, showOptionsDialog, loadFileInfoOnly);
                return
            end
            
            % see if we can locate the file elsewhere...
            [path, file, ext] = fileparts(obj.fileInfo(1).Filename);
            filepath = which([file ext]);
            if endsWith(filepath, ' not found.')
                filepath = '';
            end
            [newfile, newpath] = uigetfile('*.tif', ['Find ' file ext], filepath);
            if isequal(newfile, 0)
                return
            end
            if string(newfile) ~= string([file ext])
                if questdlg( ...
                        {['Selected filename ' newfile ' does not match stored filename ' file ext], ...
                        'Continue anyways?'}, ...
                        'WARNING') ~= "Yes"
                    return
                end
            end
            obj.load(fullfile(newpath, newfile), '', obj.fileFrames, obj.filePixelRegion, showOptionsDialog, loadFileInfoOnly);
        end
        function save(obj, filepath, prompt)
            %SAVE Save image stack to file
            
            % get path/to/file
            if ~exist('filepath', 'var') || isempty(filepath)
                if ~exist('prompt', 'var') || isempty(prompt)
                    prompt = 'Save image (stack) to file...';
                end
                [file, path] = uiputfile('*.tif', prompt);
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            
            % label based on filename
            filelabel = file;
            filelabel(strfind(filelabel, '_')) = ' ';
            
            % write data to file
            fprintf('Saving image data to file %s...\n', filelabel);
            imwrite(obj.getFrame(1), filepath);
            nframes = obj.numFrames;
            if nframes > 1
                wb = waitbar(0, sprintf('- Writing frames for %s', filelabel));
                framesPerWaitbarUpdate = floor(double(nframes) / 20);
                for t = 2:nframes
                    imwrite(obj.getFrame(t), filepath, 'WriteMode', 'append');
                    % updating waitbar is expensive, so do it sparingly
                    if mod(t, framesPerWaitbarUpdate) == 0
                        waitbar(double(t) / nframes, wb);
                    end
                end
                close(wb);
            end
            
            % update file properties
            obj.fileInfo = imfinfo(filepath);
            [obj.fileInfo.Filename] = deal(filepath);
            obj.fileFrames = []; % all frames of new file
            obj.filePixelRegion = {}; % full frame for new file
            obj.dataModified = false; % matches new file
            
            disp('... Done.');
        end
        
        function newobj = duplicate(obj, frames)
            %DUPLICATE Return a copy of the specified frames
            newobj = ImageStack;
            if isempty(obj.data)
                errordlg('Requires image data to be loaded.', 'Duplicate');
                return
            end
            nframes = obj.numFrames;
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
                newobj.data = obj.data(:,:,frames);
                newobj.frameIntervalSec = obj.frameIntervalSec;
                if ~isempty(obj.fileInfo)
                    newobj.fileInfo = obj.fileInfo(frames);
                    if ~isempty(obj.fileFrames)
                        newobj.fileFrames = obj.fileFrames(frames);
                    elseif ~isequal(frames, 1:nframes)
                        newobj.fileFrames = frames;
                    end
                    newobj.filePixelRegion = obj.filePixelRegion;
                    newobj.fileDataModified = obj.fileDataModified;
                end
                if numel(frames) > 1
                    newobj.label = string(sprintf('%s %d-%d', obj.label, frames(1), frames(end)));
                else
                    newobj.label = string(sprintf('%s %d', obj.label, frames));
                end
            catch
            end
        end
        function newobj = zproject(obj, frames, method, previewImage)
            newobj = ImageStack;
            nframes = obj.numFrames;
            if nframes <= 1
                errordlg('Requires an image stack.', 'Z-Project');
                return
            end
            if isempty(obj.data)
                errordlg('Requires image stack data to be loaded.', 'Z-Project');
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
                % preview settings
                if exist('previewImage', 'var') && isgraphics(previewImage)
                    cdata = previewImage.CData;
                    previewAxes = previewImage.Parent;
                    cmap = colormap(previewAxes);
                    colormap(previewAxes, gray(2^16));
                end
                % run
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
            function im = getZProjectedImage_()
                im = [];
                if isempty(obj.data)
                    return
                end
                try
                    if method == "Mean"
                        im = mean(obj.data(:,:,frames), 3);
                    elseif method == "Min"
                        im = min(obj.data(:,:,frames), [], 3);
                    elseif method == "Max"
                        im = max(obj.data(:,:,frames), [], 3);
                    end
                catch
                    im = [];
                end
            end
            function showPreview_()
                if ~exist('previewImage', 'var') || ~isgraphics(previewImage)
                    return
                end
                im = getZProjectedImage_();
                if isempty(im)
                    return
                end
                previewImage.CData = imadjust(uint16(im));
                previewImage.XData = [1 size(im, 2)];
                previewImage.YData = [1 size(im, 1)];
            end
            % z-project
            newobj.data = getZProjectedImage_();
            newobj.label = string(sprintf('%s %s %d-%d', obj.label, method, frames(1), frames(end)));
            % restore previous image
            if exist('previewImage', 'var') && isgraphics(previewImage) && exist('cdata', 'var')
                previewImage.CData = cdata;
                previewImage.XData = [1 size(cdata, 2)];
                previewImage.YData = [1 size(cdata, 1)];
                colormap(previewAxes, cmap);
            end
        end
        function gaussFilter(obj, t, sigma, hPreviewImage, applyToAllFrames)
            if isempty(obj.data)
                errordlg('Requires image data to be loaded.', 'Gaussian Filter');
                return
            end
            if ~exist('t', 'var') || isempty(t)
                t = 1;
            end
            nframes = obj.numFrames;
            t = max(1, min(t, nframes));
            if ~exist('sigma', 'var')
                sigma = [];
            end
            if ~exist('hPreviewImage', 'var')
                hPreviewImage = gobjects(0);
            end
            frame = obj.getFrame(t);
            [filteredFrame, sigma] = ImageOps.gaussFilterPreview(frame, sigma, hPreviewImage);
            if isempty(filteredFrame)
                return
            end
            % filter frame
            obj.data(:,:,t) = filteredFrame;
            % filter all other frames?
            if nframes > 1
                if ~exist('applyToAllFrames', 'var') || isempty(applyToAllFrames)
                    applyToAllFrames = questdlg('Apply Gaussian filter to all frames in stack?', ...
                        'Filter entire image stack?') == "Yes";
                end
                if applyToAllFrames
                    wb = waitbar(0, 'Filtering stack...');
                    framesPerWaitbarUpdate = floor(double(nframes) / 20);
                    t0 = t;
                    for t = 1:nframes
                        if t ~= t0
                            obj.data(:,:,t) = imgaussfilt(obj.data(:,:,t), sigma);
                        end
                        % updating waitbar is expensive, so do it sparingly
                        if mod(t, framesPerWaitbarUpdate) == 0
                            waitbar(double(t) / nframes, wb);
                        end
                    end
                    close(wb);
                end
            end
            obj.fileDataModified = true;
            notify(obj, 'DataChanged');
        end
        function tophatFilter(obj, t, diskRadius, hPreviewImage, applyToAllFrames)
            if isempty(obj.data)
                errordlg('Requires image data to be loaded.', 'Tophat Filter');
                return
            end
            if ~exist('t', 'var') || isempty(t)
                t = 1;
            end
            nframes = obj.numFrames;
            t = max(1, min(t, nframes));
            if ~exist('diskRadius', 'var')
                diskRadius = [];
            end
            if ~exist('hPreviewImage', 'var')
                hPreviewImage = gobjects(0);
            end
            frame = obj.getFrame(t);
            if isempty(frame)
                return
            end
            [filteredFrame, diskRadius] = ImageOps.tophatFilterPreview(frame, diskRadius, hPreviewImage);
            if isempty(filteredFrame)
                return
            end
            % filter frame
            obj.data(:,:,t) = filteredFrame;
            % filter all other frames?
            if nframes > 1
                if ~exist('applyToAllFrames', 'var') || isempty(applyToAllFrames)
                    applyToAllFrames = questdlg('Apply tophat filter to all frames in stack?', ...
                        'Filter entire image stack?', ...
                        'OK', 'Cancel', 'Cancel') == "OK";
                end
                if applyToAllFrames
                    wb = waitbar(0, 'Filtering stack...');
                    framesPerWaitbarUpdate = floor(double(nframes) / 20);
                    disk = strel('disk', diskRadius);
                    t0 = t;
                    for t = 1:nframes
                        if t ~= t0
                            obj.data(:,:,t) = imtophat(obj.data(:,:,t), disk);
                        end
                        % updating waitbar is expensive, so do it sparingly
                        if mod(t, framesPerWaitbarUpdate) == 0
                            waitbar(double(t) / nframes, wb);
                        end
                    end
                    close(wb);
                end
            end
            obj.fileDataModified = true;
            notify(obj, 'DataChanged');
        end
        function newobj = threshold(obj, t, threshold, hPreviewImage)
            newobj = ImageStack;
            if isempty(obj.data)
                errordlg('Requires image data to be loaded.', 'Threshold');
                return
            end
            if ~exist('t', 'var') || isempty(t)
                t = 1;
            end
            nframes = obj.numFrames;
            t = max(1, min(t, nframes));
            if ~exist('threshold', 'var')
                threshold = [];
            end
            if ~exist('hPreviewImage', 'var')
                hPreviewImage = gobjects(0);
            end
            frame = obj.getFrame(t);
            [mask, threshold] = ImageOps.thresholdPreview(frame, threshold, hPreviewImage);
            if isempty(mask)
                return
            end
            newobj.data = mask;
            newobj.label = string(sprintf('%s Threshold %.1f', obj.label, threshold));
        end
        
        function s = saveobj(obj)
            props = fieldnames(obj);
            for k = 1:numel(props)
                prop = char(props{k});
                if prop == "data" && ~isempty(obj.fileInfo) && ~obj.fileDataModified && obj.numFrames > 1
                    % do NOT duplicate storage of image stack files
                    s.data = [];
                else
                    s.(prop) = obj.(prop);
                end
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = Utilities.loadobj(ImageStack, s);
        end
        
        function pixelRegion = viewport2PixelRegion(viewport, imageSize)
            % find pixels in viewport
            pixelRegion = {}; % {[row lims], [col lims]}
            vx = viewport(1);
            vy = viewport(2);
            vw = viewport(3);
            vh = viewport(4);
            imrows = imageSize(1);
            imcols = imageSize(2);
            if vx <= 1 && vy <= 1 && vw <= 1 && vh <= 1
                % viewport = normalized fraction of frame
                nrows = int32(round(vh * imrows));
                ncols = int32(round(vw * imcols));
                row0 = 1 + int32(round(vy * imrows));
                col0 = 1 + int32(round(vx * imcols));
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
            if ~isempty(find(rows < 1, 1)) || ~isempty(find(rows > imrows, 1)) ...
                    || ~isempty(find(cols < 1, 1)) || ~isempty(find(cols > imcols, 1))
                errordlg('ERROR: Viewport outside of image dimensions.');
                return
            end
            pixelRegion = {[rows(1) rows(end)], [cols(1) cols(end)]};
        end
    end
end

