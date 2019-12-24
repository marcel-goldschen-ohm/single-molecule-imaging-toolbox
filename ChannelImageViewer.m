classdef ChannelImageViewer < ImageStackViewer
    %CHANNELIMAGEVIEWER Image stack viewer for a channel.
    %   I/O for the channel's list of image stacks.
    %   Select amongst the channel's list of image stacks.
    %   Apply various image operations, possibly adding new images to the
    %   channel's list of images.
    %   Find spots, select spots by clicking on them.
    %
    %	Created by Marcel Goldschen-Ohm
    %	<goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>
    
    properties
        % Channel handle.
        channel = Channel;
        
        % Markers indicating the position of the channel's spots.
        spotMarkers = gobjects(0);
        
        % Marker indicating the position of the selcted spot.
        selectedSpotMarker = gobjects(0);
        
        % Drop down menu button (menu is also available via right click in
        % the image axes).
        menuButton = gobjects(0);
        
        % Zoom to show full image button.
        zoomOutButton = gobjects(0);
        
        % Brightness/Contrast button.
        brightnessContrastButton = gobjects(0);
    end
    
    properties (Access = private)
        channelLabelChangedListener = event.listener.empty;
        selectedImageChangedListener = event.listener.empty;
        spotsChangedListener = event.listener.empty;
        selectedSpotChangedListener = event.listener.empty;
        alignedToChannelChangedListener = event.listener.empty;
        overlayChannelChangedListener = event.listener.empty;
    end
    
    methods
        function obj = ChannelImageViewer(parent)
            %CHANNELIMAGEVIEWER Constructor.
            
            % requires a parent graphics object
            % will resize itself to its parent when the containing figure
            % is resized
            if ~exist('parent', 'var') || ~isgraphics(parent)
                parent = figure();
                addToolbarExplorationButtons(parent); % old style
            end
            
            % ImageStackViewer constructor.
            obj@ImageStackViewer(parent);
            
            % change info text to a pushbutton
            if isgraphics(obj.infoText)
                delete(obj.infoText);
            end
            obj.infoText = uicontrol(parent, 'Style', 'pushbutton', ...
                'Callback', @(varargin) obj.infoTextPressed());
            
            obj.menuButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Image Menu', ...
                'Callback', @(varargin) obj.menuButtonPressed());
            
            obj.zoomOutButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Autoscale to Image', ...
                'Callback', @(varargin) obj.zoomOutFullImage());
            
            obj.brightnessContrastButton = uicontrol(parent, 'style', 'pushbutton', ...
                'String', char(hex2dec('25d0')), 'Position', [0 0 15 15], ...
                'Tooltip', 'Brightness/Contrast', ...
                'Callback', @(varargin) obj.editBrightnessContrast());
            
            obj.leftHeaderButtons = obj.menuButton;
            obj.rightHeaderButtons = [obj.brightnessContrastButton obj.zoomOutButton];
            
            obj.spotMarkers = scatter(obj.imageAxes, nan, nan, 'mo', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.selectedSpotMarker = scatter(obj.imageAxes, nan, nan, 'co', ...
                'LineWidth', 2, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            obj.resize();
            
            if ~isempty(obj.channel)
                obj.channel = obj.channel; % sets listeners and stuff
            end
        end
        
        function delete(obj)
            %DELETE Delete all graphics object properties and listeners.
            obj.deleteListeners();
            h = [ ...
                obj.spotMarkers ...
                obj.selectedSpotMarker ...
                obj.menuButton ...
                obj.zoomOutButton ...
                obj.brightnessContrastButton ...
                ];
            delete(h(isgraphics(h)));
        end
        
        function deleteListeners(obj)
            if isvalid(obj.channelLabelChangedListener)
                delete(obj.channelLabelChangedListener);
                obj.channelLabelChangedListener = event.listener.empty;
            end
            if isvalid(obj.selectedImageChangedListener)
                delete(obj.selectedImageChangedListener);
                obj.selectedImageChangedListener = event.listener.empty;
            end
            if isvalid(obj.spotsChangedListener)
                delete(obj.spotsChangedListener);
                obj.spotsChangedListener = event.listener.empty;
            end
            if isvalid(obj.selectedSpotChangedListener)
                delete(obj.selectedSpotChangedListener);
                obj.selectedSpotChangedListener = event.listener.empty;
            end
            if isvalid(obj.alignedToChannelChangedListener)
                delete(obj.alignedToChannelChangedListener);
                obj.alignedToChannelChangedListener = event.listener.empty;
            end
            if isvalid(obj.overlayChannelChangedListener)
                delete(obj.overlayChannelChangedListener);
                obj.overlayChannelChangedListener = event.listener.empty;
            end
        end
        
        function updateListeners(obj)
            obj.deleteListeners();
            if isempty(obj.channel)
                return
            end
            obj.channelLabelChangedListener = ...
                addlistener(obj.channel, 'LabelChanged', @(varargin) obj.onChannelLabelChanged());
            obj.selectedImageChangedListener = ...
                addlistener(obj.channel, 'SelectedImageChanged', @(varargin) obj.onSelectedImageChanged());
            obj.spotsChangedListener = ...
                addlistener(obj.channel, 'SpotsChanged', @(varargin) obj.onSpotsChanged());
            obj.selectedSpotChangedListener = ...
                addlistener(obj.channel, 'SelectedSpotChanged', @(varargin) obj.onSelectedSpotChanged());
            obj.alignedToChannelChangedListener = ...
                addlistener(obj.channel, 'AlignedToChanged', @(varargin) obj.showFrame());
            obj.overlayChannelChangedListener = ...
                addlistener(obj.channel, 'OverlayChannelChanged', @(varargin) obj.showFrame());
        end
        
        function set.channel(obj, channel)
            % MUST always have a valid channel handle.
            if isempty(channel) || ~isvalid(channel)
                channel = Channel;
            end
            
            % set handle to channel and update displayed image
            obj.channel = channel;
            obj.imageAxes.YLabel.String = channel.label;
            
            % show selected image
            if ~isempty(channel.selectedImage) && any(channel.images == channel.selectedImage)
                obj.imageStack = channel.selectedImage;
            elseif ~isempty(channel.images)
                obj.imageStack = channel.images(1);
            else
                obj.imageStack = ImageStack;
            end
            obj.showFrame();
            obj.resize();
            
            % update spots
            obj.updateSpotMarkers();
            obj.updateSelectedSpotMarker();
            
            % update listeners
            obj.updateListeners();
        end
        
        function onChannelLabelChanged(obj)
            obj.imageAxes.YLabel.String = obj.channel.label;
            obj.resize();
        end
        
        function onSelectedImageChanged(obj)
            obj.imageStack = obj.channel.selectedImage;
        end
        
        function onSpotsChanged(obj)
            obj.updateSpotMarkers();
        end
        
        function onSelectedSpotChanged(obj)
            obj.updateSelectedSpotMarker();
        end
        
        function updateSpotMarkers(obj)
            %UPDATESPOTMARKERS Update graphics to show spot locations.
            xy = [];
            if ~isempty(obj.channel.spots)
                xy = vertcat(obj.channel.spots.xy);
            end
            if isempty(xy)
                obj.spotMarkers.XData = nan;
                obj.spotMarkers.YData = nan;
            else
                obj.spotMarkers.XData = xy(:,1);
                obj.spotMarkers.YData = xy(:,2);
            end
        end
        
        function updateSelectedSpotMarker(obj)
            %UPDATESELECTEDSPOTMARKER Update graphics to show selected spot location.
            if isempty(obj.channel.selectedSpot) || isempty(obj.channel.selectedSpot.xy)
                obj.selectedSpotMarker.XData = nan;
                obj.selectedSpotMarker.YData = nan;
            else
                obj.selectedSpotMarker.XData = obj.channel.selectedSpot.xy(1);
                obj.selectedSpotMarker.YData = obj.channel.selectedSpot.xy(2);
            end
        end
        
        function showFrame(obj, t)
            %SHOWFRAME Display frame t.
            if ~exist('t', 'var') || isempty(t)
                t = obj.imageStack.selectedFrameIndex;
            end
            if isempty(obj.channel.overlayChannel)
                % show frame as ususal
                obj.showFrame@ImageStackViewer(t);
                return
            end
            % if we got here we have an overlay
            try
                I1 = obj.channel.selectedImage.getFrame(t);
                I2 = obj.channel.overlayChannel.selectedImage.getFrame();
                I1 = imadjust(uint16(I1));
                I2 = imadjust(uint16(I2));
                I2 = obj.channel.getOtherChannelImageInLocalCoords(obj.channel.overlayChannel, I2);
                % show overlaid images
                obj.imageFrame.CData = imfuse(I1, I2, 'ColorChannels', obj.channel.overlayColorChannels);
                if isempty(obj.imageFrame.CData)
                    obj.imageFrame.XData = [];
                    obj.imageFrame.YData = [];
                else
                    obj.imageFrame.XData = [1 size(obj.imageFrame.CData, 2)];
                    obj.imageFrame.YData = [1 size(obj.imageFrame.CData, 1)];
                    if obj.imageStack.numFrames > 1
                        obj.frameSlider.Value = t;
                        notify(obj, 'FrameChanged');
                    end
                end
                obj.updateInfoText();
            catch
                % show frame as ususal
                obj.showFrame@ImageStackViewer(t);
            end
        end
        
        function menuButtonPressed(obj)
            %MENUBUTTONPRESSED Handle menu button press.
            menu = obj.getMenu();
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.menuButton.Position(1:2);
            menu.Visible = 1;
        end
        
        function menu = getMenu(obj)
            %GETACTIONSMENU Return menu with channel image actions.
            menu = uicontextmenu;
            
            if isempty(obj.channel)
                return
            end
            
            uimenu(menu, 'Label', 'Rename Channel', ...
                'Callback', @(varargin) obj.channel.editLabel());
            
            nimages = numel(obj.channel.images);
            if nimages > 1
                submenu = uimenu(menu, 'Label', 'Select Image', ...
                    'Separator', 'on');
                for image = obj.channel.images
                    uimenu(submenu, 'Label', image.getLabelWithInfo(), ...
                        'Checked', isequal(image, obj.channel.selectedImage), ...
                        'Callback', @(varargin) obj.channel.setSelectedImage(image));
                end
            end
            
            uimenu(menu, 'Label', 'Load Image (Stack) From File', ...
                'Separator', nimages <= 1, ...
                'Callback', @(varargin) obj.channel.loadNewImage());
            
            if nimages > 0
                submenu = uimenu(menu, 'Label', 'Remove Image');
                for image = obj.channel.images
                    uimenu(submenu, 'Label', image.getLabelWithInfo(), ...
                        'Checked', isequal(image, obj.channel.selectedImage), ...
                        'Callback', @(varargin) obj.channel.removeImage(image, true));
                end
            end
            
%             if nimages > 0
%                 submenu = uimenu(menu, 'Label', 'Image Options', ...
%                     'Separator', 'on');
%                 for image = obj.channel.images
%                     immenu = uimenu(submenu, 'Label', image.getLabelWithInfo());
%                     if ~isempty(image.fileInfo)
%                         uimenu(immenu, 'Label', 'Reload From File', ...
%                             'Callback', @(varargin) image.reload());
%                     end
%                     uimenu(immenu, 'Label', 'Rename', ...
%                         'Callback', @(varargin) image.editLabel());
%                     if image.numFrames > 1
%                         uimenu(immenu, 'Label', 'Set Frame Interval', ...
%                             'Callback', @(varargin) image.editFrameInterval());
%                     end
%                 end
%             end
            
            if ~isempty(obj.channel.selectedImage)
                if ~isempty(obj.channel.selectedImage.fileInfo)
                    uimenu(menu, 'Label', 'Reload Image From File', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.channel.selectedImage.reload());
                end

                uimenu(menu, 'Label', 'Rename Image', ...
                    'Separator', isempty(obj.channel.selectedImage.fileInfo), ...
                    'Callback', @(varargin) obj.channel.selectedImage.editLabel());
                
                if obj.channel.selectedImage.numFrames > 1
                    uimenu(menu, 'Label', 'Set Image Stack Frame Interval', ...
                        'Callback', @(varargin) obj.channel.selectedImage.editFrameInterval());
                end
            end
            
            submenu = uimenu(menu, 'Label', 'Display Options', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Spot Markers', ...
                'Callback', @(varargin) obj.editSpotMarkerProperties());
            uimenu(submenu, 'Label', 'Selected Spot Marker', ...
                'Callback', @(varargin) obj.editSelectedSpotMarkerProperties());
            
            otherChannels = obj.channel.getOtherChannels();
            if ~isempty(otherChannels)
                submenu = uimenu(menu, 'Label', 'Overlay Channel', ...
                    'Separator', 'on');
                uimenu(submenu, 'Label', 'None', ...
                    'Checked', isempty(obj.channel.overlayChannel), ...
                    'Callback', @(varargin) obj.channel.setOverlayChannel(Channel.empty));
                for channel = otherChannels
                    uimenu(submenu, 'Label', channel.label, ...
                        'Checked', isequal(channel, obj.channel.overlayChannel), ...
                        'Callback', @(varargin) obj.channel.setOverlayChannel(channel));
                end
                
                submenu = uimenu(menu, 'Label', 'Overlay Colors');
                uimenu(submenu, 'Label', 'green-magenta', ...
                    'Checked', isequal(obj.channel.overlayColorChannels, [2 1 2]), ...
                    'Callback', @(varargin) obj.channel.setOverlayColorChannels([2 1 2]));
                uimenu(submenu, 'Label', 'magenta-green', ...
                    'Checked', isequal(obj.channel.overlayColorChannels, [1 2 1]), ...
                    'Callback', @(varargin) obj.channel.setOverlayColorChannels([1 2 1]));
                uimenu(submenu, 'Label', 'red-cyan', ...
                    'Checked', isequal(obj.channel.overlayColorChannels, [1 2 2]), ...
                    'Callback', @(varargin) obj.channel.setOverlayColorChannels([1 2 2]));
                uimenu(submenu, 'Label', 'cyan-red', ...
                    'Checked', isequal(obj.channel.overlayColorChannels, [2 1 1]), ...
                    'Callback', @(varargin) obj.channel.setOverlayColorChannels([2 1 1]));
                uimenu(submenu, 'Label', 'green-red', ...
                    'Checked', isequal(obj.channel.overlayColorChannels, [2 1 0]), ...
                    'Callback', @(varargin) obj.channel.setOverlayColorChannels([2 1 0]));
                uimenu(submenu, 'Label', 'red-green', ...
                    'Checked', isequal(obj.channel.overlayColorChannels, [1 2 0]), ...
                    'Callback', @(varargin) obj.channel.setOverlayColorChannels([1 2 0]));
            end
            
            if ~isempty(otherChannels)
                submenu = uimenu(menu, 'Label', 'Align To Channel', ...
                    'Separator', 'on');
                uimenu(submenu, 'Label', 'None', ...
                    'Checked', isempty(obj.channel.alignedTo.channel), ...
                    'Callback', @(varargin) obj.channel.alignToChannel(Channel.empty));
                for channel = otherChannels
                    uimenu(submenu, 'Label', channel.label, ...
                        'Checked', isequal(obj.channel.alignedTo.channel, channel), ...
                        'Callback', @(varargin) obj.channel.alignToChannel(channel));
                end
            end
            
            if ~isempty(obj.channel.selectedImage)
                uimenu(menu, 'Label', 'Autoscale', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.zoomOutFullImage());
                
                uimenu(menu, 'Label', 'Duplicate', ...
                    'Callback', @(varargin) obj.channel.duplicateSelectedImage());

                if obj.channel.selectedImage.numFrames > 1
                    uimenu(menu, 'Label', 'Z-Project', ...
                        'Callback', @(varargin) obj.channel.zprojectSelectedImage([], '', obj.imageFrame));
                end

                filterMenu = uimenu(menu, 'Label', 'Filter');
                uimenu(filterMenu, 'Label', 'Gaussian', ...
                        'Callback', @(varargin) obj.channel.gaussFilterSelectedImage([], [], obj.imageFrame));
                uimenu(filterMenu, 'Label', 'Tophat', ...
                        'Callback', @(varargin) obj.channel.tophatFilterSelectedImage([], [], obj.imageFrame));

                uimenu(menu, 'Label', 'Threshold', ...
                    'Callback', @(varargin) obj.channel.thresholdSelectedImage([], obj.imageFrame));
            end
            
            if ~isempty(obj.channel.selectedImage)
                uimenu(menu, 'Label', 'Find Spots', ...
                    'Separator', 'on', ...
                    'Callback', @(varargin) obj.channel.findSpotsInSelectedImage(obj.imageFrame));
            end
            
            if ~isempty(obj.channel.spots)
                uimenu(menu, 'Label', 'Copy Aligned Spots to all Channels', ...
                    'Separator', isempty(obj.channel.selectedImage), ...
                    'Callback', @(varargin) obj.channel.copyAlignedSpotsToAllOtherChannels());

                uimenu(menu, 'Label', 'Clear Spots', ...
                    'Callback', @(varargin) obj.channel.clearSpots());
            end
        end
        
        function infoTextPressed(obj)
            %INFOTEXTPRESSED Handle button press in info text area.
            menu = uicontextmenu;
            for image = obj.channel.images
                uimenu(menu, 'Label', image.getLabelWithInfo(), ...
                    'Checked', isequal(image, obj.channel.selectedImage), ...
                    'Callback', @(varargin) obj.channel.setSelectedImage(image));
            end
            
            fig = ancestor(obj.Parent, 'Figure');
            menu.Parent = fig;
            menu.Position(1:2) = obj.infoText.Position(1:2);
            menu.Visible = 1;
        end
        
        function imageAxesButtonDown(obj, src, event)
            %IMAGEAXESBUTTONDOWN Handle button press in image axes.
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            if event.Button == 1 % left
                % select spot
                idx = obj.spotIndexAt(x, y);
                if idx
                    obj.channel.selectedSpot = obj.channel.spots(idx);
                    if ~isempty(obj.channel.Parent)
                        obj.channel.Parent.selectedSpotIndex = idx;
                    end
                else
                    clickSpot = Spot;
                    clickSpot.xy = [x y];
                    obj.channel.selectedSpot = clickSpot;
                    if ~isempty(obj.channel.Parent)
                        obj.channel.Parent.selectedSpotIndex = [];
                    end
                end
            elseif event.Button == 2 % middle
            elseif event.Button == 3 % right
                % popup menu
                menu = obj.getMenu();
                fig = ancestor(obj.Parent, 'Figure');
                menu.Parent = fig;
                menu.Position(1:2) = get(fig, 'CurrentPoint');
                idx = obj.spotIndexAt(x, y);
                if idx
                    uimenu(menu, 'Label', 'Remove Spot', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.channel.removeSpot(idx));
                else
                    uimenu(menu, 'Label', 'Add Spot', ...
                        'Separator', 'on', ...
                        'Callback', @(varargin) obj.channel.addSpot([x y]));
                end
                menu.Visible = 1;
            end
        end
        
        function idx = spotIndexAt(obj, x, y)
            %SPOTINDEXAT Return index of spot at (x,y).
            idx = [];
            if isempty(obj.channel.spots)
                return
            end
            xy = vertcat(obj.channel.spots.xy);
            if isempty(xy)
                return
            end
            nspots = numel(obj.channel.spots);
            d = sqrt(sum((xy - repmat([x y], [nspots 1])).^2, 2));
            [d, idx] = min(d);
            ax = obj.imageAxes;
            tmpUnits = ax.Units;
            ax.Units = 'pixels';
            pos = ax.Position;
            ax.Units = tmpUnits;
            dxdy = obj.channel.spots(idx).xy - [x y];
            dxdypix = dxdy ./ [diff(ax.XLim) diff(ax.YLim)] .* pos(3:4);
            dpix = sqrt(sum(dxdypix.^2));
            if dpix > 5
                idx = [];
            end
        end
        
        function editBrightnessContrast(obj)
            warndlg('Brightness/Contrast not yet implemented.', 'Coming Soon');
        end
        
        function editSpotMarkerProperties(obj)
            answer = inputdlg( ...
                {'Marker', 'Color (r g b)', 'Size', 'Linewidth'}, ...
                '', 1, ...
                {obj.spotMarkers.Marker, ...
                num2str(obj.spotMarkers.CData), ...
                num2str(obj.spotMarkers.SizeData), ...
                num2str(obj.spotMarkers.LineWidth)});
            if isempty(answer)
                return
            end
            if ~isempty(answer{1})
                [obj.spotMarkers.Marker] = answer{1};
            end
            if ~isempty(answer{2})
                [obj.spotMarkers.CData] = str2num(answer{2});
            end
            if ~isempty(answer{3})
                [obj.spotMarkers.SizeData] = str2num(answer{3});
            end
            if ~isempty(answer{4})
                [obj.spotMarkers.LineWidth] = str2num(answer{4});
            end
        end
        
        function editSelectedSpotMarkerProperties(obj)
            answer = inputdlg( ...
                {'Marker', 'Color (r g b)', 'Size', 'Linewidth'}, ...
                '', 1, ...
                {obj.selectedSpotMarker.Marker, ...
                num2str(obj.selectedSpotMarker.CData), ...
                num2str(obj.selectedSpotMarker.SizeData), ...
                num2str(obj.selectedSpotMarker.LineWidth)});
            if isempty(answer)
                return
            end
            if ~isempty(answer{1})
                [obj.selectedSpotMarker.Marker] = answer{1};
            end
            if ~isempty(answer{2})
                [obj.selectedSpotMarker.CData] = str2num(answer{2});
            end
            if ~isempty(answer{3})
                [obj.selectedSpotMarker.SizeData] = str2num(answer{3});
            end
            if ~isempty(answer{4})
                [obj.selectedSpotMarker.LineWidth] = str2num(answer{4});
            end
        end
    end
end

