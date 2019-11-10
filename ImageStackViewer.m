classdef ImageStackViewer < handle
    %IMAGESTACKVIEWER Image viewer with frame slider similar to ImageJ.
    %   Auto-resizes to Parent container. Optionally specify Position
    %   bounding box within Parent container.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % ImageStack handle ref to image stack data.
        imageStack = ImageStack();
        
        % Bounding box in which to arrange items within Parent.
        % [] => fill Parent container.
        Position = [];
        
        % Image axes.
        imageAxes = gobjects(0);
        
        % Image graphics object for displaying a frame of the image stsack
        % in imageAxes.
        imageFrame = gobjects(0);
        
        % Slider for changing the displayed image frame.
        frameSlider = gobjects(0);
        
        % Text for displaying info about the image stack or cursor
        % locaiton, etc.
        infoText = gobjects(0);
        
        % Optional toolbar panel.
        toolbarPanel = gobjects(0);
    end
    
    properties (Access = private)
        resizeListener = [];
    end
    
    properties (Dependent)
        % Parent graphics object.
        Parent
        
        % Visibility of all graphics objects besides toolbarPanel
        Visible
    end
    
    methods
        function obj = ImageStackViewer(parent)
            %IMAGESTACKVIEWER Construct an instance of this class
            %   Detailed explanation goes here
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
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
            
            % frame slider
            obj.frameSlider = uicontrol(parent, 'Style', 'slider', ...
                'Min', 1, 'Max', 1, 'Value', 1, ...
                'SliderStep', [1 1], ... % [1/nframes 1/nframes]
                'Units', 'pixels');
            addlistener(obj.frameSlider, 'Value', 'PostSet', @obj.frameSliderMoved);
            
            % info text
            obj.infoText = uicontrol(parent, 'Style', 'text', ...
                'HorizontalAlignment', 'left');
            
            obj.resize();
            obj.updateResizeListener();
        end
        
        function tf = hasToolbar(obj)
            tf = ~isempty(obj.toolbarPanel) && isgraphics(obj.toolbarPanel);
        end
        
        function parent = get.Parent(obj)
            parent = obj.imageAxes.Parent;
        end
        
        function set.Parent(obj, parent)
            % reparent and reposition all graphics objects
            obj.imageAxes.Parent = parent;
            obj.frameSlider.Parent = parent;
            obj.infoText.Parent = parent;
            if obj.hasToolbar()
                obj.toolbarPanel.Parent = parent;
            end
            obj.resize();
            obj.updateResizeListener();
        end
        
        function visible = get.Visible(obj)
            visible = obj.imageAxes.Visible;
        end
        
        function set.Visible(obj, visible)
            % reparent and reposition all graphics objects
            obj.imageAxes.Visible = visible;
            obj.frameSlider.Visible = visible;
            obj.infoText.Visible = visible;
            if obj.hasToolbar()
                obj.toolbarPanel.Visible = visible;
            end
        end
        
        function set.Position(obj, position)
            % set position within Parent container and call resize() to
            % reposition items within updated Position
            obj.Position = position;
            obj.resize();
        end
        
        function set.imageStack(obj, imageStack)
            % set handle to image stack data and update displayed image
            obj.imageStack = imageStack;
            nframes = obj.imageStack.numFrames();
            if nframes > 1
                obj.frameSlider.Visible = 'on';
                obj.frameSlider.Min = 1;
                obj.frameSlider.Max = nframes;
                obj.frameSlider.Value = max(1, min(obj.frameSlider.Value, nframes));
                obj.frameSlider.SliderStep = [1./nframes 1./nframes];
            else
                obj.frameSlider.Visible = 'off';
            end
            obj.showFrame(obj.getCurrentFrameIndex());
            obj.zoomOutFullImage();
            obj.resize(); % reposition slider and info text relative to image
        end
        
        function resize(obj, src, event)
            %RESIZE Reposition objects within Parent.
            
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
            
            if obj.hasToolbar()
                obj.imageAxes.Position = [x y+15+margin w max(1,h-45-2*margin)];
            else
                obj.imageAxes.Position = [x y+15+margin w max(1,h-30-2*margin)];
            end
            pos = ImageStackViewer.plotboxpos(obj.imageAxes);
            obj.frameSlider.Position = [pos(1) pos(2)-margin-15 pos(3) 15];
            obj.infoText.Position = [pos(1) pos(2)+pos(4)+margin pos(3) 15];
            if obj.hasToolbar()
                obj.toolbarPanel.Position = [pos(1) pos(2)+pos(4)+margin+15 pos(3) 15];
            end
        end
        
        function updateResizeListener(obj)
            if ~isempty(obj.resizeListener) && isvalid(obj.resizeListener)
                delete(obj.resizeListener);
            end
            obj.resizeListener = addlistener(ancestor(obj.Parent, 'Figure'), 'SizeChanged', @obj.resize);
        end
        
        function frameSliderMoved(obj, src, event)
            %FRAMESLIDERMOVED Handle frame slider move event.
            %   Update displayed image frame and frame info text.
            t = uint32(round(obj.frameSlider.Value));
            t = max(obj.frameSlider.Min, min(t, obj.frameSlider.Max));
            obj.showFrame(t);
        end
        
        function t = getCurrentFrameIndex(obj)
            t = 0;
            nframes = obj.imageStack.numFrames();
            if nframes == 1
                t = 1;
            elseif nframes > 1
                t = max(1, min(obj.frameSlider.Value, nframes));
            end
        end
        
        function showFrame(obj, t)
            if ~exist('t', 'var')
                t = max(1, min(obj.frameSlider.Value, obj.imageStack.numFrames()));
            end
            frame = obj.imageStack.getFrame(t);
            if isempty(frame)
                obj.imageFrame.CData = [];
            elseif size(frame,3) == 1 % monochrome
                I = imadjust(uint16(frame));
                obj.imageFrame.CData = cat(3,I,I,I);
            elseif size(frame,3) == 3 % assume RGB
                obj.imageFrame.CData = imadjust(uint16(frame));
            else
                errordlg('Currently only handles grayscale or RGB images.', 'Image Format Error');
            end
            if isempty(obj.imageFrame.CData)
                obj.imageFrame.XData = [];
                obj.imageFrame.YData = [];
            else
                w = size(obj.imageFrame.CData,2);
                h = size(obj.imageFrame.CData,1);
                obj.imageFrame.XData = [1 w];
                obj.imageFrame.YData = [1 h];
                obj.frameSlider.Value = t;
            end
            obj.updateInfoText();
        end
        
        function updateInfoText(obj)
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
        
        function zoomOutFullImage(obj)
            if ~isempty(obj.imageFrame.CData)
                obj.imageFrame.XData = [1 size(obj.imageFrame.CData,2)];
                obj.imageFrame.YData = [1 size(obj.imageFrame.CData,1)];
                obj.imageAxes.XLim = [0.5, obj.imageFrame.XData(end)+0.5];
                obj.imageAxes.YLim = [0.5, obj.imageFrame.YData(end)+0.5];
            end
        end
        
        function imageAxesButtonDown(obj, src, event)
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            if event.Button == 1 % left
                obj.leftClickInImage(x, y);
            elseif event.Button == 2 % middle
                obj.middleClickInImage(x, y);
            elseif event.Button == 3 % right
                obj.rightClickInImage(x, y);
            end
        end
        
        function leftClickInImage(obj, x, y)
        end
        
        function middleClickInImage(obj, x, y)
        end
        
        function rightClickInImage(obj, x, y)
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
    end
end

