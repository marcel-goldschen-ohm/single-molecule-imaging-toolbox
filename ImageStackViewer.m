classdef ImageStackViewer < handle
    %IMAGESTACKVIEWER Image viewer with frame slider similar to ImageJ.
    %   Expects image stack data to be provided via the ImageStack class.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % image stack data
        hImageStack = ImageStack.empty;
        
        % UI elements
        hPanel
        hAxes
        hImage
        hSlider
        hTopText
        hTopBtnsLeft
        hTopBtnsRight
        hZoomOutBtn
        hContrastBtn
        
        % other
        isAutoContrast = true
    end
    
    properties (Access = private)
        % listeners
        labelChangedListener = event.listener.empty;
        dataChangedListener = event.listener.empty;
    end
    
    properties (Dependent)
        Parent % hPanel.Parent
        Position % hPanel.Position
        Visible % hPanel.Visible
        currentFrameIndex % from frame slider
        currentFrameData
    end
    
    events
        ImageStackChanged
        FrameChanged
    end
    
    methods
        function obj = ImageStackViewer(parent)
            %IMAGESTACKVIEWER Constructor
            
            % main panel will hold all other UI elements
            obj.hPanel = uipanel( ...
                'BorderType', 'none', ...
                'AutoResizeChildren', 'off', ... % will be handeld by resize()
                'UserData', obj ... % ref this object
                );
            if exist('parent', 'var') && ~isempty(parent) && isvalid(parent) && isgraphics(parent)
                obj.hPanel.Parent = parent;
            end
            
            % image axes and image
            obj.hAxes = axes(obj.hPanel, ...
                'Units', 'pixels', ...
                'XTick', [], 'YTick', [], ...
                'YDir', 'reverse');
            obj.hAxes.Toolbar.Visible = 'off';
            obj.hAxes.Interactions = []; %[regionZoomInteraction('Dimensions', 'xy') panInteraction('Dimensions', 'xy')];
            box(obj.hAxes, 'on');
            hold(obj.hAxes, 'on');
            obj.hImage = imagesc(obj.hAxes, [], ...
                'HitTest', 'off', ...
                'PickableParts', 'none');
            axis(obj.hAxes, 'image');
%             set(obj.hAxes, 'ButtonDownFcn', @obj.imageAxesButtonDown);
            colormap(obj.hAxes, gray(2^16));
            
            % frame slider
            obj.hSlider = uicontrol(obj.hPanel, 'Style', 'slider', ...
                'Min', 1, 'Max', 1, 'Value', 1, ...
                'SliderStep', [1 1], ... % [1/nframes 1/nframes]
                'Units', 'pixels', ...
                'Visible', 'off');
            addlistener(obj.hSlider, 'Value', 'PostSet', @(varargin) obj.sliderMoved());
            
            % top bar & buttons
            obj.hTopText = uicontrol(obj.hPanel, 'Style', 'text', ...
                'HorizontalAlignment', 'left');
            obj.hZoomOutBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), ...
                'Tooltip', 'Show Full Image', ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            obj.hContrastBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('25d0')), ...
                'Tooltip', 'Brightness/Contrast', ...
                'Callback', @(varargin) obj.contrastBtnDown());
            obj.hTopBtnsRight = [obj.hContrastBtn obj.hZoomOutBtn];
            
            % make sure we have a valid image stack
            obj.hImageStack = ImageStack();

            % layout
            obj.hPanel.SizeChangedFcn = @(varargin) obj.resize();
            %obj.resize(); % called when setting image stack
        end
        function delete(obj)
            %DELETE Delete all graphics objects and listeners.
            obj.deleteListeners();
            delete(obj.hPanel); % will delete all other child graphics objects
        end
        
        function deleteListeners(obj)
            if isvalid(obj.labelChangedListener)
                delete(obj.labelChangedListener);
                obj.labelChangedListener = event.listener.empty;
            end
            if isvalid(obj.dataChangedListener)
                delete(obj.dataChangedListener);
                obj.dataChangedListener = event.listener.empty;
            end
        end
        function updateListeners(obj)
            obj.deleteListeners();
            if isempty(obj.hImageStack)
                return
            end
            obj.labelChangedListener = ...
                addlistener(obj.hImageStack, 'LabelChanged', @(varargin) obj.updateTopText());
            obj.dataChangedListener = ...
                addlistener(obj.hImageStack, 'DataChanged', @(varargin) obj.showFrame());
        end
        
        function set.hImageStack(obj, h)
            % MUST always have a valid image stack handle
            if isempty(h) || ~isvalid(h)
                h = ImageStack();
            end
            % if we are currently zoomed, stay zoomed, otherwise show all
            % of new image
            showFullNewImage = isempty(obj.hImageStack) || ~obj.isZoomed();
            obj.hImageStack = h;
            obj.showFrame(1);
            if showFullNewImage
                obj.zoomOutFullImage();
            end
            % update slider
            nframes = obj.hImageStack.numFrames;
            if nframes > 1
                obj.hSlider.Visible = 'on';
                obj.hSlider.Min = 1;
                obj.hSlider.Max = nframes;
                obj.hSlider.Value = max(1, min(obj.hSlider.Value, nframes));
                obj.hSlider.SliderStep = [1./nframes 1./nframes];
            else
                obj.hSlider.Visible = 'off';
            end
            obj.resize(); % update layout for new image size
            obj.updateListeners();
            notify(obj, 'ImageStackChanged');
        end
        function setImageStack(obj, h)
            obj.hImageStack = h;
        end
        
        function h = get.Parent(obj)
            h = obj.hPanel.Parent;
        end
        function set.Parent(obj, h)
            obj.hPanel.Parent = h;
        end
        function bbox = get.Position(obj)
            bbox = obj.hPanel.Position;
        end
        function set.Position(obj, bbox)
            obj.hPanel.Position = bbox;
            obj.resize();
        end
        function vis = get.Visible(obj)
            vis = obj.hPanel.Visible;
        end
        function set.Visible(obj, vis)
            obj.hPanel.Visible = vis;
        end
        
        function idx = get.currentFrameIndex(obj)
            idx = max(0, min(obj.hSlider.Value, obj.hImageStack.numFrames));
        end
        function frame = get.currentFrameData(obj)
            try
                t = obj.currentFrameIndex;
                frame = obj.hImageStack.data(:,:,t);
            catch
                frame = [];
            end
        end
        
        function resize(obj)
            %RESIZE Reposition all graphics objects within hPanel.
            
            % reposition image axes within panel
            bbox = getpixelposition(obj.hPanel);
            margin = 2;
            lineh = 20;
            x = margin;
            y = margin + lineh + margin;
            w = bbox(3) - margin - x;
            h = bbox(4) - margin - lineh - margin - y;
            if ~isempty(obj.hAxes.YLabel.String)
                x = x + lineh;
                w = w - lineh;
            end
            obj.hAxes.Position = [x y w h];
            % get actual displayed image axes position.
            pos = Utilities.plotboxpos(obj.hAxes);
            x = pos(1); y = pos(2); w = pos(3); h = pos(4);
            
            % slider below image
            obj.hSlider.Position = [x y-margin-lineh w lineh];
            
            % top bar text & buttons above image
            by = y + h + margin;
            lx = x;
            for i = 1:numel(obj.hTopBtnsLeft)
                obj.hTopBtnsLeft(i).Position = [lx by lineh lineh];
                lx = lx + lineh;
            end
            rx = x + w;
            for i = numel(obj.hTopBtnsRight):-1:1
                rx = rx - lineh;
                obj.hTopBtnsRight(i).Position = [rx by lineh lineh];
            end
            obj.hTopText.Position = [lx by rx-lx lineh];
        end
        function refresh(obj)
            %REFRESH Update everything by resetting the image stack handle.
            obj.hImageStack = obj.hImageStack;
        end
        
        function showFrame(obj, t)
            %SHOWFRAME Display frame t.
            if ~exist('t', 'var')
                t = obj.currentFrameIndex;
            end
            try
                frame = obj.hImageStack.getFrame(t);
            catch
                frame = [];
            end
            if isempty(frame)
                obj.hImage.CData = [];
                obj.hImage.XData = [];
                obj.hImage.YData = [];
            else
                if obj.isAutoContrast
                    obj.hAxes.CLim = [0 2^16-1];
                    obj.hImage.CData = imadjust(uint16(frame));
                else
                    obj.hImage.CData = frame;
                end
                obj.hImage.XData = [1 size(frame, 2)];
                obj.hImage.YData = [1 size(frame, 1)];
                if obj.hImageStack.numFrames > 1
                    obj.hSlider.Value = t;
                end
            end
            obj.updateTopText();
            notify(obj, 'FrameChanged');
        end
        
        function sliderMoved(obj)
            %FRAMESLIDERMOVED Handle slider movement event.
            %   Update displayed image frame and frame info text.
            t = uint32(round(obj.hSlider.Value));
            t = max(obj.hSlider.Min, min(t, obj.hSlider.Max));
            obj.showFrame(t);
        end
        
        function updateTopText(obj)
            %UPDATEINFOTEXT Show image stack and frame info above image.
            if isempty(obj.hImage.CData)
                str = '';
            else
                w = size(obj.hImage.CData,2);
                h = size(obj.hImage.CData,1);
                nframes = obj.hImageStack.numFrames;
                if nframes > 1
                    t = obj.hSlider.Value;
                    str = sprintf('%d/%d (%dx%d)', t, nframes, w, h);
                else
                    str = sprintf('(%dx%d)', w, h);
                end
            end
            if ~isempty(obj.hImageStack.label)
                str = [str ' ' char(obj.hImageStack.label)];
            end
            obj.hTopText.String = str;
        end
        
        function zoomOutFullImage(obj)
            %ZOOMOUTFULLIMAGE Zoom out to show full image.
            if ~isempty(obj.hImage.CData)
                obj.hImage.XData = [1 size(obj.hImage.CData,2)];
                obj.hImage.YData = [1 size(obj.hImage.CData,1)];
                obj.hAxes.XLim = [0.5, obj.hImage.XData(end)+0.5];
                obj.hAxes.YLim = [0.5, obj.hImage.YData(end)+0.5];
            end
        end
        function tf = isZoomed(obj)
            %ISZOOMED Return zoom status for image axes.
            tf = Utilities.isAxesZoomed(obj.hAxes);
        end
        
        function set.isAutoContrast(obj, tf)
            obj.isAutoContrast = tf;
            obj.showFrame(obj.currentFrameIndex);
        end
        function contrastBtnDown(obj)
            menu = uicontextmenu;
            uimenu(menu, 'Label', 'Auto Contrast', ...
                'Checked', obj.isAutoContrast, ...
                'Callback', @(varargin) obj.toggleAutoContrast());
            uimenu(menu, 'Label', ['Set Window (' num2str(obj.hAxes.CLim) ')'], ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.editContrast());
            
            fig = ancestor(obj.hPanel, 'Figure');
            menu.Parent = fig;
            pos = Utilities.getPixelPositionInAncestor(obj.hContrastBtn, hFig);
            menu.Position(1:2) = pos(1:2);
            menu.Visible = 1;
        end
        function toggleAutoContrast(obj)
            obj.isAutoContrast = ~obj.isAutoContrast;
        end
        function editContrast(obj)
            obj.isAutoContrast = false;
            imcontrast(obj.hImage);
        end
        
%         function imageAxesButtonDown(obj, src, event)
%             %IMAGEAXESBUTTONDOWN Handle button press in image axes.
%             x = event.IntersectionPoint(1);
%             y = event.IntersectionPoint(2);
%             if event.Button == 1 % lefts
%             elseif event.Button == 2 % middle
%             elseif event.Button == 3 % right
%             end
%         end
    end
end

