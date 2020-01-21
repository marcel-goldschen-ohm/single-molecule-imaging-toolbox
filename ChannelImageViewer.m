classdef ChannelImageViewer < ImageStackViewer
    %CHANNELIMAGEVIEWER Image stack viewer for a channel.
    %   - I/O and selection for the channel's list of image stacks.
    %   - Apply various image operations, possibly adding new images to the
    %     channel's list of images.
    %   - Find spots and select spots by clicking on them.
    %
    %   For different default spot marker properties, edit the lines where
    %   these objects are created in the constructor.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % channel data
        hChannel = Channel.empty;
        
        % UI elements
        hMenuBtn
        hSpotMarkers
        hSelectedSpotMarker
    end
    
    properties (Access = private)
        % listeners
        channelLabelChangedListener = event.listener.empty;
        spotsChangedListener = event.listener.empty;
        selectedSpotChangedListener = event.listener.empty;
        alignmentChangedListener = event.listener.empty;
        overlayChangedListener = event.listener.empty;

        % related UIs
        hOverlayChannelViewer = ChannelImageViewer.empty;
        hSiblingViewers = ChannelImageViewer.empty(1,0); % !!! YOU NEED TO UPDATE THIS MANUALLY, e.g. obj.updateSiblingViewers()
    end
    
    properties (Dependent)
        showSpots
        showSelectedSpot
    end
    
    methods
        function obj = ChannelImageViewer(parent)
            %CHANNELIMAGEVIEWER Constructor.
            
            % ImageStackViewer constructor.
            if ~exist('parent', 'var')
                parent = gobjects(0);
            end
            obj@ImageStackViewer(parent);
            
            % change top text to a pushbutton
            obj.hTopText.Style = 'pushbutton';
            obj.hTopText.Callback = @(varargin) obj.topTextBtnDown();
            
            % buttons
            obj.hMenuBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), ...
                'Tooltip', 'Image Menu', ...
                'Callback', @(varargin) obj.menuBtnDown());
            obj.hTopBtnsLeft = obj.hMenuBtn;
            
            % spot markers
            obj.hSpotMarkers = scatter(obj.hAxes, nan, nan, 'mo', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hSelectedSpotMarker = scatter(obj.hAxes, nan, nan, 'co', ...
                'LineWidth', 2, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            % mouse interaction
            set(obj.hAxes, 'ButtonDownFcn', @obj.axesBtnDown);
            
            % make sure we have a valid channel
            obj.hChannel = Channel();
            
            obj.resize(); % update layout
        end
        
        function deleteListeners(obj)
            obj.deleteListeners@ImageStackViewer();
            if isvalid(obj.channelLabelChangedListener)
                delete(obj.channelLabelChangedListener);
                obj.channelLabelChangedListener = event.listener.empty;
            end
            if isvalid(obj.spotsChangedListener)
                delete(obj.spotsChangedListener);
                obj.spotsChangedListener = event.listener.empty;
            end
            if isvalid(obj.selectedSpotChangedListener)
                delete(obj.selectedSpotChangedListener);
                obj.selectedSpotChangedListener = event.listener.empty;
            end
            if isvalid(obj.alignmentChangedListener)
                delete(obj.alignmentChangedListener);
                obj.alignmentChangedListener = event.listener.empty;
            end
            if isvalid(obj.overlayChangedListener)
                delete(obj.overlayChangedListener);
                obj.overlayChangedListener = event.listener.empty;
            end
        end
        function updateListeners(obj)
            obj.deleteListeners();
            obj.updateListeners@ImageStackViewer();
            obj.channelLabelChangedListener = ...
                addlistener(obj.hChannel, 'LabelChanged', ...
                @(varargin) obj.onChannelLabelChanged());
            obj.spotsChangedListener = ...
                addlistener(obj.hChannel, 'SpotsChanged', ...
                @(varargin) obj.updateSpotMarkers());
            obj.selectedSpotChangedListener = ...
                addlistener(obj.hChannel, 'SelectedSpotChanged', ...
                @(varargin) obj.updateSelectedSpotMarker());
            obj.alignmentChangedListener = ...
                addlistener(obj.hChannel, 'AlignmentChanged', ...
                @(varargin) obj.showFrame());
            obj.overlayChangedListener = ...
                addlistener(obj.hChannel, 'OverlayChanged', ...
                @(varargin) obj.showFrame());
        end
        
        function set.hChannel(obj, h)
            % MUST always have a valid channel handle
            if isempty(h) || ~isvalid(h)
                h = Channel();
            end
            obj.hChannel = h;
            
            % show channel label on y axis
            obj.hAxes.YLabel.String = obj.hChannel.label;
            
            % show channel image
            if isempty(obj.hChannel.hImages)
                obj.hImageStack = ImageStack(); % no channel images to show
            elseif ~isempty(obj.hChannel.hImages) && ~any(obj.hChannel.hImages == obj.hImageStack)
                % show first image only if we aren't already showing one of
                % the channel's images
                obj.hImageStack = obj.hChannel.hImages(1);
            end
            
            % update stuff
            obj.updateSpotMarkers();
            obj.updateSelectedSpotMarker();
            obj.updateTopText();
            obj.updateListeners();
        end
        
        function loadNewImage(obj)
            hNewImage = obj.hChannel.loadNewImage();
            if ~isempty(hNewImage)
                obj.hImageStack = hNewImage;
            end
        end
        function removeImage(obj, hImage)
            obj.hChannel.removeImage(hImage, true);
            if ~isvalid(obj.hImageStack)
                if ~isempty(obj.hChannel.hImages)
                    obj.hImageStack = obj.hChannel.hImages(1);
                else
                    obj.hImageStack = ImageStack();
                end
            end
        end
        
        function onChannelLabelChanged(obj)
            obj.hAxes.YLabel.String = obj.hChannel.label;
            obj.resize();
        end
        
        function tf = get.showSpots(obj)
            tf = obj.hSpotMarkers.Visible == "on";
        end
        function tf = get.showSelectedSpot(obj)
            tf = obj.hSelectedSpotMarker.Visible == "on";
        end
        function set.showSpots(obj, tf)
            obj.hSpotMarkers.Visible = tf;
        end
        function set.showSelectedSpot(obj, tf)
            obj.hSelectedSpotMarker.Visible = tf;
        end
        function toggleShowSpots(obj)
            obj.showSpots = ~obj.showSpots;
        end
        function toggleShowSelectedSpot(obj)
            obj.showSelectedSpot = ~obj.showSelectedSpot;
        end
        function updateSpotMarkers(obj)
            %UPDATESPOTMARKERS Update spot location markers.
            xy = [];
            if ~isempty(obj.hChannel.hSpots)
                xy = vertcat(obj.hChannel.hSpots.xy);
            end
            if isempty(xy)
                obj.hSpotMarkers.XData = nan;
                obj.hSpotMarkers.YData = nan;
            else
                obj.hSpotMarkers.XData = xy(:,1);
                obj.hSpotMarkers.YData = xy(:,2);
            end
        end
        function updateSelectedSpotMarker(obj)
            %UPDATESELECTEDSPOTMARKER Update selected spot location marker.
            if isempty(obj.hChannel.hSelectedSpot) || isempty(obj.hChannel.hSelectedSpot.xy)
                obj.hSelectedSpotMarker.XData = nan;
                obj.hSelectedSpotMarker.YData = nan;
            else
                obj.hSelectedSpotMarker.XData = obj.hChannel.hSelectedSpot.xy(1);
                obj.hSelectedSpotMarker.YData = obj.hChannel.hSelectedSpot.xy(2);
            end
        end
        function editSpotMarkerProperties(obj)
            answer = inputdlg( ...
                {'Marker', 'Color (r g b)', 'Size', 'Linewidth'}, ...
                '', 1, ...
                {obj.hSpotMarkers.Marker, ...
                num2str(obj.hSpotMarkers.CData), ...
                num2str(obj.hSpotMarkers.SizeData), ...
                num2str(obj.hSpotMarkers.LineWidth)});
            if isempty(answer)
                return
            end
            if ~isempty(answer{1})
                [obj.hSpotMarkers.Marker] = answer{1};
            end
            if ~isempty(answer{2})
                [obj.hSpotMarkers.CData] = str2num(answer{2});
            end
            if ~isempty(answer{3})
                [obj.hSpotMarkers.SizeData] = str2num(answer{3});
            end
            if ~isempty(answer{4})
                [obj.hSpotMarkers.LineWidth] = str2num(answer{4});
            end
        end
        function editSelectedSpotMarkerProperties(obj)
            answer = inputdlg( ...
                {'Marker', 'Color (r g b)', 'Size', 'Linewidth'}, ...
                '', 1, ...
                {obj.hSelectedSpotMarker.Marker, ...
                num2str(obj.hSelectedSpotMarker.CData), ...
                num2str(obj.hSelectedSpotMarker.SizeData), ...
                num2str(obj.hSelectedSpotMarker.LineWidth)});
            if isempty(answer)
                return
            end
            if ~isempty(answer{1})
                [obj.hSelectedSpotMarker.Marker] = answer{1};
            end
            if ~isempty(answer{2})
                [obj.hSelectedSpotMarker.CData] = str2num(answer{2});
            end
            if ~isempty(answer{3})
                [obj.hSelectedSpotMarker.SizeData] = str2num(answer{3});
            end
            if ~isempty(answer{4})
                [obj.hSelectedSpotMarker.LineWidth] = str2num(answer{4});
            end
        end
        
        function updateTopText(obj)
            obj.updateTopText@ImageStackViewer();
            if ~isempty(obj.hChannel) && isempty(obj.hChannel.hImages)
                obj.hTopText.String = 'Load Image (Stack)';
            end
        end
        function topTextBtnDown(obj)
            %TOPTEXTBTNDOWN Handle button press in top text area.
            if isempty(obj.hChannel.hImages)
                obj.loadNewImage();
                return
            end
            
            menu = uicontextmenu;
            for hImage = obj.hChannel.hImages
                uimenu(menu, 'Label', hImage.getLabelWithInfo(), ...
                    'Checked', isequal(hImage, obj.hImageStack), ...
                    'Callback', @(varargin) obj.setImageStack(hImage));
            end
            uimenu(menu, 'Label', 'Load New Image (Stack)', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.loadNewImage());
            
            hFig = ancestor(obj.hPanel, 'Figure');
            menu.Parent = hFig;
            pos = Utilities.getPixelPositionInAncestor(obj.hTopText, hFig);
            menu.Position(1:2) = pos(1:2);
            menu.Visible = 1;
        end
        
        function axesBtnDown(obj, src, event)
            %IMAGEAXESBUTTONDOWN Handle button press in image axes.
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            if event.Button == 1 % left
                % select spot
                idx = obj.spotIndexAt(x, y);
                if idx
                    if ~isempty(obj.hChannel.hExperiment)
                        obj.hChannel.hExperiment.selectedSpotIndex = idx;
                    else
                        obj.hChannel.hSelectedSpot = obj.hChannel.hSpots(idx);
                    end
                else
                    clickSpot = Spot;
                    clickSpot.xy = [x y];
                    obj.hChannel.hSelectedSpot = clickSpot;
                    if ~isempty(obj.hChannel.hExperiment)
                        obj.hChannel.hExperiment.selectedSpotIndex = [];
                    end
                end
            elseif event.Button == 2 % middle
            elseif event.Button == 3 % right
                % popup menu
                menu = obj.getMenu();
                hFigure = ancestor(obj.Parent, 'Figure');
                menu.Parent = hFigure;
                menu.Position(1:2) = get(hFigure, 'CurrentPoint');
                idx = obj.spotIndexAt(x, y);
                if idx
                    uimenu(menu, 'Label', 'Remove Spot', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.hChannel.removeSpot(idx));
                else
                    uimenu(menu, 'Label', 'Add Spot', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.hChannel.addSpot([x y]));
                end
                menu.Visible = 1;
            end
        end
        function idx = spotIndexAt(obj, x, y)
            %SPOTINDEXAT Return index of spot at (x,y).
            idx = [];
            if isempty(obj.hChannel.hSpots)
                return
            end
            xy = vertcat(obj.hChannel.hSpots.xy);
            if isempty(xy)
                return
            end
            numSpots = numel(obj.hChannel.hSpots);
            d = sqrt(sum((xy - repmat([x y], [numSpots 1])).^2, 2));
            [d, idx] = min(d);
            pos = getpixelposition(obj.hAxes);
            dxdy = xy(idx,:) - [x y];
            dxdypix = dxdy ./ [diff(obj.hAxes.XLim) diff(obj.hAxes.YLim)] .* pos(3:4);
            dpix2 = sum(dxdypix.^2);
            if dpix2 > 5^2
                idx = [];
            end
        end
        
        function showFrame(obj, t, updateOverlaidViewers)
            %SHOWFRAME Display frame t.
            if ~exist('t', 'var') || isempty(t)
                t = obj.currentFrameIndex;
            end
            if isempty(obj.hChannel) || ~isvalid(obj.hChannel)
                obj.showFrame@ImageStackViewer(t);
                return
            end
            if isempty(obj.hChannel.hOverlayChannel) || ~isvalid(obj.hChannel.hOverlayChannel)
                obj.showFrame@ImageStackViewer(t);
            else
                try
                    obj.hOverlayChannelViewer = obj.findOverlayChannelViewer();
                    if isempty(obj.hOverlayChannelViewer)
                        obj.showFrame@ImageStackViewer(t);
                        return
                    end
                    % images to overlay
                    I1 = obj.hImageStack.getFrame(t);
                    I2 = obj.hOverlayChannelViewer.currentFrameData;
                    I1 = imadjust(uint16(I1)); % always use autocontrast
                    I2 = imadjust(uint16(I2));
                    I2 = obj.hChannel.getOtherChannelImageInLocalCoords(obj.hChannel.hOverlayChannel, I2);
                    % show overlaid images
                    obj.hAxes.CLim = [0 2^16-1];
                    obj.hImage.CData = imfuse(I1, I2, 'ColorChannels', obj.hChannel.overlayColorChannels);
                    if isempty(obj.hImage.CData)
                        obj.hImage.XData = [];
                        obj.hImage.YData = [];
                    else
                        obj.hImage.XData = [1 size(obj.hImage.CData, 2)];
                        obj.hImage.YData = [1 size(obj.hImage.CData, 1)];
                        if obj.hImageStack.numFrames > 1
                            obj.hSlider.Value = t;
                        end
                    end
                    obj.updateTopText();
                    notify(obj, 'FrameChanged');
                catch
                    obj.showFrame@ImageStackViewer(t);
                end
            end
            if (~isempty(obj.hChannel) && isvalid(obj.hChannel)) ...
                    && (~exist('updateOverlaidViewers', 'var') || updateOverlaidViewers)
                if ~isempty(obj.hSiblingViewers) % !!! YOU NEED TO UPDATE THIS MANUALLY, e.g. obj.updateSiblingViewers()
                    for hSiblingViewer = obj.hSiblingViewers
                        if isvalid(hSiblingViewer) && isequal(hSiblingViewer.hChannel.hOverlayChannel, obj.hChannel)
                            hSiblingViewer.showFrame([], false);
                        end
                    end
                end
            end
        end
        
        function menuBtnDown(obj)
            %MENUBUTTONPRESSED Handle menu button press.
            menu = obj.getMenu();
            hFig = ancestor(obj.hPanel, 'Figure');
            menu.Parent = hFig;
            pos = Utilities.getPixelPositionInAncestor(obj.hMenuBtn, hFig);
            menu.Position(1:2) = pos(1:2);
            menu.Visible = 1;
        end
        function menu = getMenu(obj)
            %GETACTIONSMENU Return menu with channel image actions.
            menu = uicontextmenu;
            
            % channel -------------------
            uimenu(menu, 'Label', 'Rename Channel', ...
                'Callback', @(varargin) obj.hChannel.editLabel());
            
            % images -------------------
            numImages = numel(obj.hChannel.hImages);
            if numImages > 1
                submenu = uimenu(menu, 'Label', 'Select Image', ...
                    'Separator', 'on');
                for hImage = obj.hChannel.hImages
                    uimenu(submenu, 'Label', hImage.getLabelWithInfo(), ...
                        'Checked', isequal(hImage, obj.hImageStack), ...
                        'Callback', @(varargin) obj.setImageStack(hImage));
                end
            end
            
            uimenu(menu, 'Label', 'Load Image (Stack) From File', ...
                'Separator', numImages <= 1, ...
                'Callback', @(varargin) obj.loadNewImage());
            
            if ~isempty(obj.hImageStack) && ~isempty(obj.hImageStack.fileInfo)
                uimenu(menu, 'Label', 'Reload Selected Image From File', ...
                    'Callback', @(varargin) obj.hImageStack.reload(true));
            end
            
            if ~isempty(obj.hImageStack)
                uimenu(menu, 'Label', 'Save Selected Image To File', ...
                    'Callback', @(varargin) obj.hImageStack.save());
            end
            
            if numImages > 0
                submenu = uimenu(menu, 'Label', 'Remove Image');
                for hImage = obj.hChannel.hImages
                    uimenu(submenu, 'Label', hImage.getLabelWithInfo(), ...
                        'Checked', isequal(hImage, obj.hImageStack), ...
                        'Callback', @(varargin) obj.removeImage(hImage));
                end
            end
            
            if ~isempty(obj.hImageStack)
                uimenu(menu, 'Label', 'Rename Selected Image', ...
                    'Callback', @(varargin) obj.hImageStack.editLabel());
            end
                
            if ~isempty(obj.hImageStack) && obj.hImageStack.numFrames > 1
                uimenu(menu, 'Label', 'Set Selected Image Stack Frame Interval', ...
                    'Callback', @(varargin) obj.hImageStack.editFrameInterval());
            end
            
            % display options -------------------
            submenu = uimenu(menu, 'Label', 'Display Options', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Show Spots', ...
                'Checked', obj.showSpots, ...
                'Callback', @(varargin) obj.toggleShowSpots());
            uimenu(submenu, 'Label', 'Show Selected Spot', ...
                'Checked', obj.showSelectedSpot, ...
                'Callback', @(varargin) obj.toggleShowSelectedSpot());
            uimenu(submenu, 'Label', 'Edit Spot Markers', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.editSpotMarkerProperties());
            uimenu(submenu, 'Label', 'Edit Selected Spot Marker', ...
                'Callback', @(varargin) obj.editSelectedSpotMarkerProperties());
            
            % sibling channels and associated viewers -------------------
            hSiblingChannels = obj.hChannel.getSiblingChannels();
            hSiblingViewers = obj.getSiblingViewers();
            
            % channel overlay -------------------
            if ~isempty(hSiblingChannels)
                label = 'Overlay Channel';
                if ~isempty(obj.hChannel.hOverlayChannel)
                    label = [label ' (' char(obj.hChannel.hOverlayChannel.label) ')'];
                end
                submenu = uimenu(menu, 'Label', label, ...
                    'Separator', 'on');
                uimenu(submenu, 'Label', 'None', ...
                    'Checked', isempty(obj.hChannel.hOverlayChannel), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayChannel(Channel.empty));
                for hSiblingChannel = hSiblingChannels
                    uimenu(submenu, 'Label', hSiblingChannel.label, ...
                        'Checked', isequal(hSiblingChannel, obj.hChannel.hOverlayChannel), ...
                        'Callback', @(varargin) obj.hChannel.setOverlayChannel(hSiblingChannel));
                end
                
                submenu = uimenu(menu, 'Label', 'Overlay Colors');
                uimenu(submenu, 'Label', 'green-magenta', ...
                    'Checked', isequal(obj.hChannel.overlayColorChannels, [2 1 2]), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayColorChannels([2 1 2]));
                uimenu(submenu, 'Label', 'magenta-green', ...
                    'Checked', isequal(obj.hChannel.overlayColorChannels, [1 2 1]), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayColorChannels([1 2 1]));
                uimenu(submenu, 'Label', 'red-cyan', ...
                    'Checked', isequal(obj.hChannel.overlayColorChannels, [1 2 2]), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayColorChannels([1 2 2]));
                uimenu(submenu, 'Label', 'cyan-red', ...
                    'Checked', isequal(obj.hChannel.overlayColorChannels, [2 1 1]), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayColorChannels([2 1 1]));
                uimenu(submenu, 'Label', 'green-red', ...
                    'Checked', isequal(obj.hChannel.overlayColorChannels, [2 1 0]), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayColorChannels([2 1 0]));
                uimenu(submenu, 'Label', 'red-green', ...
                    'Checked', isequal(obj.hChannel.overlayColorChannels, [1 2 0]), ...
                    'Callback', @(varargin) obj.hChannel.setOverlayColorChannels([1 2 0]));
            end
            
            % channel alignment -------------------
            if ~isempty(hSiblingChannels)
                label = 'Align To Channel';
                if ~isempty(obj.hChannel.hAlignedToChannel)
                    label = [label ' (' char(obj.hChannel.hAlignedToChannel.label) ')'];
                end
                submenu = uimenu(menu, 'Label', label, ...
                    'Separator', 'on');
                uimenu(submenu, 'Label', 'None', ...
                    'Checked', isempty(obj.hChannel.hAlignedToChannel), ...
                    'Callback', @(varargin) obj.hChannel.alignToChannel(Channel.empty));
                for hSiblingChannel = hSiblingChannels
                    hSiblingViewer = ChannelImageViewer.empty;
                    if ~isempty(hSiblingViewers)
                        for hViewer = hSiblingViewers
                            if isequal(hViewer.hChannel, hSiblingChannel)
                                hSiblingViewer = hViewer;
                                break
                            end
                        end
                    end
                    if ~isempty(hSiblingViewer)
                        movingImage = obj.currentFrameData;
                        fixedImage = hSiblingViewer.currentFrameData;
                    else
                        movingImage = [];
                        fixedImage = [];
                    end
                    if ~isempty(movingImage)
                        movingImage = imadjust(uint16(movingImage));
                    end
                    if ~isempty(fixedImage)
                        fixedImage = imadjust(uint16(fixedImage));
                    end
                    uimenu(submenu, 'Label', hSiblingChannel.label, ...
                        'Checked', isequal(obj.hChannel.hAlignedToChannel, hSiblingChannel), ...
                        'Callback', @(varargin) obj.hChannel.alignToChannel(hSiblingChannel, '', movingImage, fixedImage));
                end
            end
            
            % image operations -------------------
            if ~isempty(obj.hImageStack)
                uimenu(menu, 'Label', 'Duplicate', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.duplicateCurrentImage());

                if obj.hImageStack.numFrames > 1
                    uimenu(menu, 'Label', 'Z-Project', ...
                        'Callback', @(varargin) obj.zprojectCurrentImage());
                end

                filterMenu = uimenu(menu, 'Label', 'Filter');
                uimenu(filterMenu, 'Label', 'Gaussian', ...
                        'Callback', @(varargin) obj.gaussFilterCurrentImage());
                uimenu(filterMenu, 'Label', 'Tophat', ...
                        'Callback', @(varargin) obj.tophatFilterCurrentImage());

                uimenu(menu, 'Label', 'Threshold', ...
                    'Callback', @(varargin) obj.thresholdCurrentImage());
            end
            
            % spots -------------------
            if ~isempty(obj.hImageStack)
                uimenu(menu, 'Label', 'Find Spots', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.hChannel.findSpotsInImage(obj.currentFrameData, obj.hImage));
            end
            if ~isempty(obj.hChannel.hSpots) && ~isempty(hSiblingChannels)
                uimenu(menu, 'Label', 'Copy Mapped Spots to all Channels', ...
                    'Separator', isempty(obj.hImageStack), ...
                    'Callback', @(varargin) obj.hChannel.copyMappedSpotsToAllSiblingChannels());
            end
            if ~isempty(obj.hChannel.hSpots)
                uimenu(menu, 'Label', 'Clear Spots', ...
                    'Separator', isempty(obj.hImageStack) && isempty(hSiblingChannels), ...
                    'Callback', @(varargin) obj.hChannel.clearSpots());
            end
        end
        
        function hSiblingViewers = getSiblingViewers(obj)
            % GETOTHERVIEWERS Get other viewers in UI.
            %   Get all other ChannelImageViewer objects that are siblings
            %   of this object in the UI tree.
            hSiblingViewers = ChannelImageViewer.empty(1,0);
            if ~isempty(obj.hPanel.Parent)
                siblingPanels = setdiff(findobj(obj.hPanel.Parent.Children, 'flat', 'Type', 'uipanel'), obj.hPanel);
                for k = 1:numel(siblingPanels)
                    panel = siblingPanels(k);
                    if ~isempty(panel.UserData) && isobject(panel.UserData) && class(panel.UserData) == "ChannelImageViewer"
                        hSiblingViewers(end+1) = panel.UserData;
                    end
                end
            end
        end
        function updateSiblingViewers(obj)
            obj.hSiblingViewers = obj.getSiblingViewers();
        end
        function setSiblingViewers(obj, h)
            obj.hSiblingViewers = h;
        end
        function hViewer = findOverlayChannelViewer(obj)
            hViewer = ChannelImageViewer.empty;
            if isempty(obj.hChannel.hOverlayChannel)
                return
            end
            if ~isempty(obj.hOverlayChannelViewer) && isequal(obj.hOverlayChannelViewer.hChannel, obj.hChannel.hOverlayChannel)
                hViewer = obj.hOverlayChannelViewer;
                return
            end
            hSiblingViewers = obj.getSiblingViewers();
            if ~isempty(hSiblingViewers)
                for hSiblingViewer = hSiblingViewers
                    if isequal(hSiblingViewer.hChannel, obj.hChannel.hOverlayChannel)
                        hViewer = hSiblingViewer;
                        return
                    end
                end
            end
        end
        function hViewers = findViewersOverlaidWithThisChannel(obj)
            hViewers = ChannelImageViewer.empty(1,0);
            hSiblingViewers = obj.getSiblingViewers();
            if ~isempty(hSiblingViewers)
                for hSiblingViewer = hSiblingViewers
                    if isequal(hSiblingViewer.hChannel.hOverlayChannel, obj.hChannel)
                        hViewers(end+1) = hSiblingViewer;
                    end
                end
            end
        end
        function clearAllRelatedViewers(obj)
            obj.hOverlayChannelViewer = ChannelImageViewer.empty;
            obj.hSiblingViewers = ChannelImageViewer.empty(1,0);
        end
        
        function duplicateCurrentImage(obj)
            %DUPLICATE Duplicate current image stack.
            %   Append duplicate image to channel's image list.
            try
                hNewImage = obj.hImageStack.duplicate();
                if ~isempty(hNewImage) && ~isempty(hNewImage.data)
                    obj.hChannel.hImages = [obj.hChannel.hImages hNewImage];
                    obj.hImageStack = hNewImage;
                end
            catch
            end
        end
        function zprojectCurrentImage(obj)
            %ZPROJECT Z-Project frames of selected image stack.
            %   Append z-projected image to channel's image list.
            try
                hNewImage = obj.hImageStack.zproject([], '', obj.hImage);
                if ~isempty(hNewImage) && ~isempty(hNewImage.data)
                    obj.hChannel.hImages = [obj.hChannel.hImages hNewImage];
                    obj.hImageStack = hNewImage;
                end
            catch
            end
        end
        function gaussFilterCurrentImage(obj)
            %GAUSSFILTER Apply Gaussian filter to selected image (stack).
            try
                t = obj.currentFrameIndex;
                obj.hImageStack.gaussFilter(t, [], obj.hImage);
                obj.showFrame();
            catch
            end
        end
        function tophatFilterCurrentImage(obj)
            %TOPHATFILTER Apply tophat filter to selected image (stack).
            try
                t = obj.currentFrameIndex;
                obj.hImageStack.tophatFilter(t, [], obj.hImage);
                obj.showFrame();
            catch
            end
        end
        function thresholdCurrentImage(obj)
            %THRESHOLD Threshold selected image stack frame.
            %   Append thresholded mask to channel's image list.
            try
                t = obj.currentFrameIndex;
                hNewImage = obj.hImageStack.threshold(t, [], obj.hImage);
                if ~isempty(hNewImage) && ~isempty(hNewImage.data)
                    obj.hChannel.hImages = [obj.hChannel.hImages hNewImage];
                    obj.hImageStack = hNewImage;
                end
            catch
            end
        end
    end
end

