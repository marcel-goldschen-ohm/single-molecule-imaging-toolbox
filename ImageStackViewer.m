classdef ImageStackViewer < handle
    %IMAGESTACKVIEWER Image viewer with frame slider similar to ImageJ.
    %   Auto-resizes to Parent container. Optionally specify Position
    %   bounding box within Parent container.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % ImageStack handle ref to image stack data.
        imageStack = ImageStack;
        
        % Bounding box in which to arrange items within Parent.
        % [] => fill Parent container.
        Position = [];
        
        % Image axes. Created in constructor.
        imageAxes = gobjects(0);
        
        % Image graphics object for displaying a frame of the image stsack
        % in imageAxes. Created in constructor.
        imageFrame = gobjects(0);
        
        % Slider for changing the displayed image frame. Created in
        % constructor.
        frameSlider = gobjects(0);
        
        % Text for displaying info about the image stack or cursor
        % locaiton, etc. Created in constructor.
        infoText = gobjects(0);
        
        % Optional list of buttons displayed to the left of infoText.
        leftHeaderButtons = gobjects(0);
        
        % Optional list of buttons displayed to the right of infoText.
        rightHeaderButtons = gobjects(0);
        
        % Optional toolbar panel displayed above infoText.
        toolbarPanel = gobjects(0);
    end
    
    properties (Access = private)
        % Calls resize() upon ancestor figure's SizeChanged events.
        % Access via updateResizeListener() and removeResizeListener().
        resizeListener = event.listener.empty;
        
        labelChangedListener = event.listener.empty;
        dataChangedListener = event.listener.empty;
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
        
        % Visibility of all graphics objects.
        Visible
    end
    
    events
        % Notify when setting imageStack property.
        ImageStackChanged
        
        % Notify after showFrame().
        FrameChanged
    end
    
    methods
        function obj = ImageStackViewer(parent)
            %IMAGESTACKVIEWER Constructor
            
            % Requires a parent graphics object. Will resize itself to its
            % parent when the containing figure is resized. If parent is
            % not given, attach this object to a newly created figure.
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
            % image axes and image
            obj.imageAxes = axes(parent, ...
                'Units', 'pixels', ...
                'XTick', [], 'YTick', [], ...
                'YDir', 'reverse');
            obj.imageAxes.Toolbar.Visible = 'off';
            box(obj.imageAxes, 'on');
            hold(obj.imageAxes, 'on');
            obj.imageFrame = image(obj.imageAxes, [], ...
                'HitTest', 'off', ...
                'PickableParts', 'none');
            axis(obj.imageAxes, 'image');
            set(obj.imageAxes, 'ButtonDownFcn', @obj.imageAxesButtonDown);
            colormap(obj.imageAxes, gray(2^16));
            
            % frame slider
            obj.frameSlider = uicontrol(parent, 'Style', 'slider', ...
                'Min', 1, 'Max', 1, 'Value', 1, ...
                'SliderStep', [1 1], ... % [1/nframes 1/nframes]
                'Units', 'pixels');
            addlistener(obj.frameSlider, 'Value', 'PostSet', @(varargin) obj.frameSliderMoved());
            
            % info text
            obj.infoText = uicontrol(parent, 'Style', 'text', ...
                'HorizontalAlignment', 'left');
            
            obj.resize();
            obj.updateResizeListener();
        end
        
        function delete(obj)
            %DELETE Delete all graphics object properties and listeners.
            obj.deleteListeners();
            obj.removeResizeListener();
            h = [ ...
                obj.imageAxes ...
                obj.frameSlider ...
                obj.infoText ...
                obj.leftHeaderButtons ...
                obj.rightHeaderButtons ...
                obj.toolbarPanel ...
                ];
            delete(h(isgraphics(h)));
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
            if ~isempty(obj.imageStack)
                obj.labelChangedListener = ...
                    addlistener(obj.imageStack, 'LabelChanged', @(varargin) obj.updateInfoText());
                obj.dataChangedListener = ...
                    addlistener(obj.imageStack, 'DataChanged', @(varargin) obj.showFrame());
            end
        end
        
        function parent = get.Parent(obj)
            % Get parent of graphics object properties.
            parent = obj.imageAxes.Parent;
        end
        
        function set.Parent(obj, parent)
            % Set parent of graphics object properties and resize to fit.
            obj.imageAxes.Parent = parent;
            obj.frameSlider.Parent = parent;
            obj.infoText.Parent = parent;
            if ~isempty(obj.leftHeaderButtons)
                [obj.leftHeaderButtons.Parent] = deal(parent);
            end
            if ~isempty(obj.rightHeaderButtons)
                [obj.rightHeaderButtons.Parent] = deal(parent);
            end
            if isgraphics(obj.toolbarPanel)
                obj.toolbarPanel.Parent = parent;
            end
            obj.resize();
            obj.updateResizeListener();
        end
        
        function visible = get.Visible(obj)
            % Get visibility of all graphics obejct properties.
            visible = obj.imageAxes.Visible;
        end
        
        function set.Visible(obj, visible)
            % Set visibility of all graphics obejct properties.
            obj.imageAxes.Visible = visible;
            if ~isempty(obj.imageAxes.Children)
                [obj.imageAxes.Children.Visible] = deal(visible);
            end
            if isempty(obj.imageStack) || obj.imageStack.numFrames() <= 1
                obj.frameSlider.Visible = 'off';
            else
                obj.frameSlider.Visible = visible;
            end
            obj.infoText.Visible = visible;
            if ~isempty(obj.leftHeaderButtons)
                [obj.leftHeaderButtons.Visible] = deal(visible);
            end
            if ~isempty(obj.rightHeaderButtons)
                [obj.rightHeaderButtons.Visible] = deal(visible);
            end
            if isgraphics(obj.toolbarPanel)
                obj.toolbarPanel.Visible = visible;
            end
        end
        
        function set.Position(obj, position)
            % Set position within Parent container and resize to fit.
            obj.Position = position;
            obj.resize();
        end
        
        function set.imageStack(obj, imageStack)
            % Set handle to the displayed image stack. This updates
            % everything including the displayed image and frame slider.
            if isequal(obj.imageStack, imageStack)
                return
            end
            zoomOut = isempty(obj.imageStack.data) || ~obj.isZoomed();
            obj.imageStack = imageStack;
            nframes = obj.imageStack.numFrames;
            if nframes > 1
                obj.frameSlider.Visible = 'on';
                obj.frameSlider.Min = 1;
                obj.frameSlider.Max = nframes;
                obj.frameSlider.Value = max(1, min(obj.imageStack.selectedFrameIndex, nframes));
                obj.frameSlider.SliderStep = [1./nframes 1./nframes];
            else
                obj.frameSlider.Visible = 'off';
            end
            obj.showFrame();
            if zoomOut
                obj.zoomOutFullImage();
            end
            obj.resize(); % reposition slider and info text relative to image
            obj.updateListeners();
            notify(obj, 'ImageStackChanged');
        end
        
        function refresh(obj)
            %REFRESH Update everything by resetting the image stack handle.
            obj.imageStack = obj.imageStack;
        end
        
        function resize(obj)
            %RESIZE Reposition all graphics objects within Parent.
            
            % Get bounding box [x y w h] within Parent in which to display
            % all graphics objects.
            margin = 2;
            parentUnits = obj.Parent.Units;
            obj.Parent.Units = 'pixels';
            try
                % use Position as bounding box within Parent container
                x = obj.Position(1);
                y = obj.Position(2);
                w = obj.Position(3);
                h = obj.Position(4);
                if w <= 1 && x <= 1
                    % normalized in horizontal
                    pw = obj.Parent.Position(3);
                    x = max(margin, min(x * pw, pw - 2 * margin));
                    w = max(margin, min(w * pw, pw - x - margin));
                end
                if h <= 1 && y <= 1
                    % normalized in vertical
                    ph = obj.Parent.Position(4);
                    y = max(margin, min(y * ph, ph - 2 * margin));
                    h = max(margin, min(h * ph, ph - y - margin));
                end
            catch
                % fill Parent container
                x = margin;
                y = margin;
                w = obj.Parent.Position(3) - 2 * margin;
                h = obj.Parent.Position(4) - 2 * margin;
            end
            obj.Parent.Units = parentUnits;
            
            % Position image axes.
            obj.imageAxes.Position = [x y+15+margin w max(1,h-30-2*margin)];
            if isgraphics(obj.toolbarPanel)
                obj.imageAxes.Position(4) = obj.imageAxes.Position(4) - 15 - margin;
            end
            if ~isempty(obj.imageAxes.YLabel.String)
                obj.imageAxes.Position(1) = obj.imageAxes.Position(1) + 15 + margin;
                obj.imageAxes.Position(3) = obj.imageAxes.Position(3) - 15 - margin;
            end
            
            % Get actual displayed image axes position.
            pos = ImageStackViewer.plotboxpos(obj.imageAxes);
            
            % Position all other graphics objects around the image axes.
            obj.frameSlider.Position = [pos(1) pos(2)-margin-15 pos(3) 15];
            wl = 0;
            wr = 0;
            if ~isempty(obj.leftHeaderButtons)
                wl = margin + sum(horzcat(obj.leftHeaderButtons.Position(3)));
            end
            if ~isempty(obj.rightHeaderButtons)
                wr = margin;
                for button = obj.rightHeaderButtons
                    wr = wr + button.Position(3);
                end
            end
            obj.infoText.Position = [pos(1)+wl pos(2)+pos(4)+margin pos(3)-wl-wr 15];
            if wl
                bx = pos(1);
                by = pos(2) + pos(4) + margin;
                for btn = obj.leftHeaderButtons
                    btn.Position = [bx by btn.Position(3) 15];
                    bx = bx + btn.Position(3);
                end
            end
            if wr
                bx = pos(1) + pos(3) - wr + margin;
                for btn = obj.rightHeaderButtons
                    btn.Position = [bx by btn.Position(3) 15];
                    bx = bx + btn.Position(3);
                end
            end
            if isgraphics(obj.toolbarPanel)
                obj.toolbarPanel.Position = [pos(1) pos(2)+pos(4)+margin+15 pos(3) 15];
            end
        end
        
        function updateResizeListener(obj)
            %UPDATERESIZELISTENER Automatically resize to Parent.
            %   Call resize() on ancestor figure's SizeChanged events.
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = ...
                addlistener(ancestor(obj.Parent, 'Figure'), ...
                'SizeChanged', @(varargin) obj.resize());
        end
        
        function removeResizeListener(obj)
            %REMOVERESIZELISTENER Do NOT automatically resize to Parent.
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = event.listener.empty;
        end
        
        function frameSliderMoved(obj)
            %FRAMESLIDERMOVED Handle frame slider move event.
            %   Update displayed image frame and frame info text.
            t = uint32(round(obj.frameSlider.Value));
            t = max(obj.frameSlider.Min, min(t, obj.frameSlider.Max));
            obj.showFrame(t);
        end
        
        function showFrame(obj, t)
            %SHOWFRAME Display frame t.
            if ~exist('t', 'var') || isempty(t)
                t = obj.imageStack.selectedFrameIndex;
            end
            frame = obj.imageStack.getFrame(t);
            if isempty(frame)
                obj.imageFrame.CData = [];
                obj.imageFrame.XData = [];
                obj.imageFrame.YData = [];
            else
                obj.imageFrame.CData = imadjust(uint16(frame));
                obj.imageFrame.XData = [1 size(frame, 2)];
                obj.imageFrame.YData = [1 size(frame, 1)];
                if obj.imageStack.numFrames > 1
                    obj.frameSlider.Value = t;
                    if obj.imageStack.selectedFrameIndex ~= t
                        obj.imageStack.selectedFrameIndex = t;
                    end
                end
            end
            obj.updateInfoText();
        end
        
        function updateInfoText(obj)
            %UPDATEINFOTEXT Show image stack and frame info above image.
            if isempty(obj.imageFrame.CData)
                obj.infoText.String = '';
            else
                w = size(obj.imageFrame.CData,2);
                h = size(obj.imageFrame.CData,1);
                nframes = obj.imageStack.numFrames();
                if nframes > 1
                    t = obj.frameSlider.Value;
                    obj.infoText.String = sprintf('%d/%d (%dx%d)', t, nframes, w, h);
                else
                    obj.infoText.String = sprintf('(%dx%d)', w, h);
                end
                if ~isempty(obj.imageStack.label)
                    obj.infoText.String = [obj.infoText.String ' ' char(obj.imageStack.label)];
                end
            end
        end
        
        function tf = isZoomed(obj)
            %ISZOOMED Return zoom status for image axes.
            tf = ImageStackViewer.isAxesZoomed(obj.imageAxes);
        end
        
        function zoomOutFullImage(obj)
            %ZOOMOUTFULLIMAGE Autoscale to show full image.
            if ~isempty(obj.imageFrame.CData)
                obj.imageFrame.XData = [1 size(obj.imageFrame.CData,2)];
                obj.imageFrame.YData = [1 size(obj.imageFrame.CData,1)];
                obj.imageAxes.XLim = [0.5, obj.imageFrame.XData(end)+0.5];
                obj.imageAxes.YLim = [0.5, obj.imageFrame.YData(end)+0.5];
            end
        end
        
        function imageAxesButtonDown(obj, src, event)
            %IMAGEAXESBUTTONDOWN Handle button press in image axes.
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            if event.Button == 1 % lefts
            elseif event.Button == 2 % middle
            elseif event.Button == 3 % right
            end
        end
    end
    
    methods (Static)
        % https://github.com/kakearney/plotboxpos-pkg
        % copied here for convenience, otherwise install via Add-On Explorer
        function pos = plotboxpos(h)
            %PLOTBOXPOS Returns the position of the plotted axis region
            %
            % pos = plotboxpos(h)
            %
            % This function returns the position of the plotted region of an axis,
            % which may differ from the actual axis position, depending on the axis
            % limits, data aspect ratio, and plot box aspect ratio.  The position is
            % returned in the same units as the those used to define the axis itself.
            % This function can only be used for a 2D plot.  
            %
            % Input variables:
            %
            %   h:      axis handle of a 2D axis (if ommitted, current axis is used).
            %
            % Output variables:
            %
            %   pos:    four-element position vector, in same units as h

            % Copyright 2010 Kelly Kearney

            % Check input

            if nargin < 1
                h = gca;
            end

            if ~ishandle(h) || ~strcmp(get(h,'type'), 'axes')
                error('Input must be an axis handle');
            end

            % Get position of axis in pixels

            currunit = get(h, 'units');
            set(h, 'units', 'pixels');
            axisPos = get(h, 'Position');
            set(h, 'Units', currunit);

            % Calculate box position based axis limits and aspect ratios

            darismanual  = strcmpi(get(h, 'DataAspectRatioMode'),    'manual');
            pbarismanual = strcmpi(get(h, 'PlotBoxAspectRatioMode'), 'manual');

            if ~darismanual && ~pbarismanual

                pos = axisPos;

            else

                xlim = get(h, 'XLim');
                ylim = get(h, 'YLim');

                % Deal with axis limits auto-set via Inf/-Inf use

                if any(isinf([xlim ylim]))
                    hc = get(h, 'Children');
                    hc(~arrayfun( @(h) isprop(h, 'XData' ) & isprop(h, 'YData' ), hc)) = [];
                    xdata = get(hc, 'XData');
                    if iscell(xdata)
                        xdata = cellfun(@(x) x(:), xdata, 'uni', 0);
                        xdata = cat(1, xdata{:});
                    end
                    ydata = get(hc, 'YData');
                    if iscell(ydata)
                        ydata = cellfun(@(x) x(:), ydata, 'uni', 0);
                        ydata = cat(1, ydata{:});
                    end
                    isplotted = ~isinf(xdata) & ~isnan(xdata) & ...
                                ~isinf(ydata) & ~isnan(ydata);
                    xdata = xdata(isplotted);
                    ydata = ydata(isplotted);
                    if isempty(xdata)
                        xdata = [0 1];
                    end
                    if isempty(ydata)
                        ydata = [0 1];
                    end
                    if isinf(xlim(1))
                        xlim(1) = min(xdata);
                    end
                    if isinf(xlim(2))
                        xlim(2) = max(xdata);
                    end
                    if isinf(ylim(1))
                        ylim(1) = min(ydata);
                    end
                    if isinf(ylim(2))
                        ylim(2) = max(ydata);
                    end
                end

                dx = diff(xlim);
                dy = diff(ylim);
                dar = get(h, 'DataAspectRatio');
                pbar = get(h, 'PlotBoxAspectRatio');

                limDarRatio = (dx/dar(1))/(dy/dar(2));
                pbarRatio = pbar(1)/pbar(2);
                axisRatio = axisPos(3)/axisPos(4);

                if darismanual
                    if limDarRatio > axisRatio
                        pos(1) = axisPos(1);
                        pos(3) = axisPos(3);
                        pos(4) = axisPos(3)/limDarRatio;
                        pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
                    else
                        pos(2) = axisPos(2);
                        pos(4) = axisPos(4);
                        pos(3) = axisPos(4) * limDarRatio;
                        pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
                    end
                elseif pbarismanual
                    if pbarRatio > axisRatio
                        pos(1) = axisPos(1);
                        pos(3) = axisPos(3);
                        pos(4) = axisPos(3)/pbarRatio;
                        pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
                    else
                        pos(2) = axisPos(2);
                        pos(4) = axisPos(4);
                        pos(3) = axisPos(4) * pbarRatio;
                        pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
                    end
                end
            end

            % Convert plot box position to the units used by the axis

            hparent = get(h, 'parent');
            hfig = ancestor(hparent, 'figure'); % in case in panel or similar
            currax = get(hfig, 'currentaxes');

            temp = axes('Units', 'Pixels', 'Position', pos, 'Visible', 'off', 'parent', hparent);
            set(temp, 'Units', currunit);
            pos = get(temp, 'position');
            delete(temp);

            set(hfig, 'currentaxes', currax);
        end
        
        function tf = isAxesZoomed(ax)
            %ISAXESZOOMED Return zoom status for axes ax.
            unzoomed = getappdata(ax, 'matlab_graphics_resetplotview');
            if isempty(unzoomed) ...
                    || (isequal(ax.XLim, unzoomed.XLim) && isequal(ax.YLim, unzoomed.YLim))
               tf = false;
            else
               tf = true;
            end
        end
    end
end

