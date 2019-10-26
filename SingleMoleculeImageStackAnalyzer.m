classdef SingleMoleculeImageStackAnalyzer < handle
    %SINGLEMOLECULEIMAGESTACKANALYZER Summary of this class goes here
    %   Detailed explanation goes here
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % data (struct)
        % |
        % | -- notes (char array)
        % |
        % | -- channels (struct array)
        % |    |
        % |    | -- label (string)
        % |    | -- color ([r g b])
        % |    | -- images (ImageStack array)
        % |
        % | -- channelAlignments ([#channels x #channels] ImageRegistration matrix)
        % |
        % | -- spots ([#spots x #channels] struct matrix)
        % |    |
        % |    | -- xy ([x y] location)
        % |    | -- label (string)
        % |    | -- zproj (z-projection across frames)
        % |    | -- ideal (idealization of z-projection)
        % |    | -- ...
        % |    | -- e.g. Area, Eccentricity, Circularity, Pixels, PixelIndexList
        data
    end
    
    properties (Access = private)
        % struct with all graphics objects
        ui
        
        % struct with struct templates
        templates
        
        % working dir
        wd = pwd();
    end
    
    methods
        function obj = SingleMoleculeImageStackAnalyzer()
            %SINGLEMOLECULEIMAGEVIEWER Construct an instance of this class
            %   Detailed explanation goes here
            
            % template definitions
            obj.templates.spot.xy = [];
            obj.templates.spot.label = "";
            obj.templates.spot.zproj = [];
            obj.templates.spot.ideal = [];
            
            obj.templates.channel.label = "";
            obj.templates.channel.color = [0 1 0]; % [r g b] color
            obj.templates.channel.images = repmat(ImageStack, 0);
            
            obj.templates.data.notes = '';
            obj.templates.data.channels = repmat(obj.templates.channel, 0);
            obj.templates.data.channelAlignments = repmat(ImageRegistration, 0);
            obj.templates.data.spots = repmat(obj.templates.spot, 0);
            
            % init ui
            obj.ui.mainWindow = figure( ...
                'Name', 'Single-Molecule Image Stack ROI Viewer', ...
                'Units', 'normalized', ...
                'Position', [0 0 .5 .5], ...
                'numbertitle', 'off');
            obj.ui.mainWindow.Units = 'pixels';
            addToolbarExplorationButtons(obj.ui.mainWindow); % old style
        end
        
        function saveData(obj, filepath, maxImageStackFrames)
            %SAVEDATA Save all data.
            %   Save data struct to file. !!! Do NOT save image stacks with
            %   frame count exceeding maxImageStackFrames.
            if ~exist('maxImageStackFrames', 'var')
                answer = inputdlg({'Only save image stack data when frame count <='}, 'Save Large Image Stacks?', 1, {'inf'});
                if isempty(answer)
                    return
                end
                maxImageStackFrames = str2num(answer{1});
            end
            
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uiputfile(fullfile(obj.wd, '*.mat'), 'Save data to file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            
            wb = waitbar(0, 'Saving data to file...');
            if ~isinf(maxImageStackFrames)
                % move image data to temporary cell array
                tmpImageStackData = {};
                for c = 1:numel(obj.data.channels)
                    tmpImageStackData{c} = {};
                    for i = 1:numel(obj.data.channels(c).imageStacks)
                        if obj.data.channels(c).imageStacks(i).numFrames() > maxImageStackFrames
                            tmpImageStackData{c}{i} = obj.data.channels(c).imageStacks(i).data;
                            obj.data.channels(c).imageStacks(i).data = [];
                        else
                            tmpImageStackData{c}{i} = [];
                        end
                    end
                end
            end
            tmpdata = obj.data;
            save(filepath, '-struct', 'tmpdata', '-v7.3');
            clear tmpdata;
            if ~isinf(maxImageStackFrames)
                % move image data back from temporary cell array
                for c = 1:numel(obj.data.channels)
                    for i = 1:numel(obj.data.channels(c).imageStacks)
                        if ~isempty(tmpImageStackData{c}{i})
                            obj.data.channels(c).imageStacks(i).data = tmpImageStackData{c}{i};
                        end
                    end
                end
                clear tmpImageStackData;
            end
            close(wb);
            [obj.wd, file, ext] = fileparts(filepath);
            obj.ui.mainWindow.Name = strrep(file, '_', ' ');
        end
        
        function loadData(obj, filepath)
            %LOADDATA Load all data.
            %   Load data struct from file.
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uigetfile(fullfile(obj.wd, '*.mat'), 'Open data file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            wb = waitbar(0, 'Loading data from file...');
            obj.data = load(filepath);
            % make sure data at least has all of its template fields
            for property = fieldnames(obj.templates.data)
                if ~isfield(obj.data, property)
                    obj.data.(property) = obj.templates.data.(property);
                end
            end
            % make sure data.channels at least have all of their template fields
            obj.data.channels = makeStructArraysCompatible(obj.data.channels, obj.templates.channel);
            % make sure data.spots at least have all of their template fields
            obj.data.spots = makeStructArraysCompatible(obj.data.spots, obj.templates.spot);
            close(wb);
            [obj.wd, file, ext] = fileparts(filepath);
            obj.ui.mainWindow.Name = strrep(file, '_', ' ');
        end
        
        function loadAllMissingImageStacks(obj)
            for c = 1:numel(obj.data.channels)
                for i = 1:numel(obj.data.channels(c).imageStacks)
                    if isempty(obj.data.channels(c).imageStacks(i).data)
                        obj.data.channels(c).imageStacks(i).reload();
                    end
                end
            end
        end
    end
    
    methods (Static)
    end
end

