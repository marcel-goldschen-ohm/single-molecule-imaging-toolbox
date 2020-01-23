classdef TimeSeriesViewer < handle
    %TIMESERIESVIEWER
    
    properties
        % time series data
        ts = TimeSeries.empty(1,0);
        
        % UI elements
        hPanel
        
        hTraceAxes
        hTraceLine
        hTraceBaseline
        hTraceIdealLine
        
        hHistAxes
        hHistBar
        hHistIdealLines
        hHistUpperRightText
        hHistNumBinsText
        hHistNumBinsEdit
        hHistSqrtCountsBtn
        
        hMenuBtn
        hAutoscaleXYBtn
        hAutoscaleYBtn
        hAutoscaleXBtn
        
        hShowRawOrBtnGroup
        hShowRawBtn
        hShowBaselinedBtn
        hShowBaselinedAndScaledBtn
        
        hShowBaselineBtn
        hShowIdealBtn
        hFilterBtn
    end
    
    properties (Access = private)
        colors = lines();
        hROI % for temporary ROI selections (e.g. rectangle range)
        hDialogPanel % for within UI dialogs
    end
    
    properties (Dependent)
        Parent % hPanel.Parent
        Position % hPanel.Position
        Visible % hPanel.Visible
    end
    
    methods
        function obj = TimeSeriesViewer(parent)
            %TIMESERIESVIEWER Constructor.
            
            % main panel will hold all other UI elements
            obj.hPanel = uipanel( ...
                'BorderType', 'none', ...
                'AutoResizeChildren', 'off', ... % will be handeld by resize()
                'UserData', obj ... % ref this object
                );
            if exist('parent', 'var') && ~isempty(parent) && isvalid(parent) && isgraphics(parent)
                obj.hPanel.Parent = parent;
            end
            
            % trace axes -------------
            obj.hTraceAxes = axes(obj.hPanel, 'Units', 'pixels', ...
                'TickLength', [0.004 0.002]);
            ax = obj.hTraceAxes;
            ax.Toolbar.Visible = 'off';
            ax.Interactions = []; %[regionZoomInteraction('Dimensions', 'xy')];
            box(ax, 'on');
            hold(ax, 'on');
            obj.hTraceLine = line(ax, nan, nan, ...
                'LineStyle', '-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hTraceBaseline = line(ax, nan, nan, ...
                'LineStyle', '--', 'Color', [0 0 0], ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hTraceIdealLine = line(ax, nan, nan, ...
                'LineStyle', '-', ...
                'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            % hist axes -------------
            obj.hHistAxes = axes(obj.hPanel, 'Units', 'pixels', ...
                'XTick', [], 'YTick', []);
            ax = obj.hHistAxes;
            ax.Toolbar.Visible = 'off';
            ax.Interactions = []; %[regionZoomInteraction('Dimensions', 'xy')];
            box(ax, 'on');
            hold(ax, 'on');
            obj.hHistBar = barh(ax, nan, nan, ...
                'BarWidth', 1, ...
                'LineStyle', 'none', ...
                'FaceAlpha', 0.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hHistIdealLines = line(ax, nan, nan, ...
                'LineStyle', '-', ...
                'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hHistUpperRightText = text(ax, 0.99, 0.99, '', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hHistNumBinsText = uicontrol(obj.hPanel, 'style', 'text', ...
                'String', 'bins', ...
                'HorizontalAlignment', 'right');
            obj.hHistNumBinsEdit = uicontrol(obj.hPanel, 'style', 'edit', ...
                'String', '80', ...
                'Tooltip', '# Bins', ...
                'Callback', @(varargin) obj.updateUI());
            obj.hHistSqrtCountsBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('221a')), ...
                'Tooltip', 'sqrt(counts)', ...
                'Callback', @(varargin) obj.updateUI());
                
            linkaxes([obj.hTraceAxes obj.hHistAxes], 'y');
            
            % other -------------
            obj.hMenuBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Projection Menu', ...
                'Callback', @(varargin) obj.menuBtnDown());
            
            obj.hAutoscaleXYBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2922')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Autoscale XY', ...
                'Callback', @(varargin) obj.autoscaleXY());
            obj.hAutoscaleYBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2195')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Autoscale Y', ...
                'Callback', @(varargin) obj.autoscaleY());
            obj.hAutoscaleXBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2194')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Autoscale X', ...
                'Callback', @(varargin) obj.autoscaleX());
            
            obj.hShowRawOrBtnGroup = uibuttongroup(obj.hPanel, ...
                'BorderType', 'none', ...
                'Units', 'pixels', 'Position', [0 0 60 20]);
            obj.hShowRawBtn = uicontrol(obj.hShowRawOrBtnGroup, 'style', 'togglebutton', ...
                'String', 'R', 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Raw Data', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hShowBaselinedBtn = uicontrol(obj.hShowRawOrBtnGroup, 'style', 'togglebutton', ...
                'String', 'B', 'Position', [20 0 20 20], ...
                'Tooltip', 'Show Baselined Data', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hShowBaselinedAndScaledBtn = uicontrol(obj.hShowRawOrBtnGroup, 'style', 'togglebutton', ...
                'String', 'BS', 'Position', [40 0 20 20], ...
                'Tooltip', 'Show Baselined & Scaled Data', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateUI());
            
            obj.hShowBaselineBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('2505')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Baseline', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hShowIdealBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('220f')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Idealization', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hFilterBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('2a0d')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Apply Filter', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateUI());

            % layout
            obj.hPanel.SizeChangedFcn = @(varargin) obj.resize();
            obj.resize();
        end
        function delete(obj)
            %DELETE Delete all graphics objects and listeners.
            obj.deleteListeners();
            delete(obj.hPanel); % will delete all other child graphics objects
        end
        
        function deleteListeners(obj)
        end
        function updateListeners(obj)
            obj.deleteListeners();
        end
        
        function set.ts(obj, ts)
            obj.ts = ts;
            obj.updateUI();
        end
        function updateUI(obj)
            numTs = numel(obj.ts);
            if numel(obj.hTraceLine) > numTs
                delete(obj.hTraceLine(numTs+1:end));
                delete(obj.hTraceIdealLine(numTs+1:end));
                delete(obj.hHistBar(numTs+1:end));
                delete(obj.hHistIdealLines(numTs+1:end));
            end
            obj.hHistUpperRightText.Visible = 'off';
            obj.hHistUpperRightText.String = '';
            colorIndex = 1;
            for t = 1:numTs
                if numel(obj.hTraceLine) < t
                    obj.hTraceLine(t) = line(obj.hTraceAxes, nan, nan, ...
                        'LineStyle', '-', ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                    obj.hTraceBaseline(t) = line(obj.hTraceAxes, nan, nan, ...
                        'LineStyle', '--', 'Color', [0 0 0], ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                    obj.hTraceIdealLine(t) = line(obj.hTraceAxes, nan, nan, ...
                        'LineStyle', '-', ...
                        'LineWidth', 1.5, ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                    obj.hHistBar(t) = barh(obj.hHistAxes, nan, nan, ...
                        'BarWidth', 1, ...
                        'LineStyle', 'none', ...
                        'FaceAlpha', 0.5, ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                    obj.hHistIdealLines(t) = line(obj.hHistAxes, nan, nan, ...
                        'LineStyle', '-', ...
                        'LineWidth', 1.5, ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                end
                try
                    x = obj.ts(t).time;
                    if obj.hShowRawBtn.Value
                        y = obj.ts(t).rawData;
                    elseif obj.hShowBaselinedBtn.Value
                        y = obj.ts(t).rawData + obj.ts(t).offset;
                    else
                        y = obj.ts(t).data;
                    end
                catch
                    x = [];
                    y = [];
                end
                if isempty(y)
                    obj.hTraceLine(t).Visible = 'off';
                    obj.hTraceLine(t).XData = nan;
                    obj.hTraceLine(t).YData = nan;
                    obj.hTraceBaseline(t).Visible = 'off';
                    obj.hTraceBaseline(t).XData = nan;
                    obj.hTraceBaseline(t).YData = nan;
                    obj.hTraceIdealLine(t).Visible = 'off';
                    obj.hTraceIdealLine(t).XData = nan;
                    obj.hTraceIdealLine(t).YData = nan;
                    obj.hHistBar(t).Visible = 'off';
                    obj.hHistBar(t).XData = nan;
                    obj.hHistBar(t).YData = nan;
                    obj.hHistIdealLines(t).Visible = 'off';
                    obj.hHistIdealLines(t).XData = nan;
                    obj.hHistIdealLines(t).YData = nan;
%                     if t == 1
%                         obj.hHistUpperRightText.Visible = 'off';
%                         obj.hHistUpperRightText.String = '';
%                     end
                    continue
                end
                obj.hTraceLine(t).XData = x;
                obj.hTraceLine(t).YData = y;
                obj.hTraceLine(t).Color = obj.colors(colorIndex,:);
                colorIndex = colorIndex + 1;
                obj.hTraceLine(t).Visible = 'on';
                % baseline
                if obj.hShowBaselineBtn.Value
                    obj.hTraceBaseline(t).XData = x;
                    if obj.hShowRawBtn.Value
                        obj.hTraceBaseline(t).YData = zeros(size(y)) - obj.ts(t).offset;
                    else
                        obj.hTraceBaseline(t).YData = zeros(size(y));
                    end
                    obj.hTraceBaseline(t).Visible = 'on';
                else
                    obj.hTraceBaseline(t).Visible = 'off';
                    obj.hTraceBaseline(t).XData = nan;
                    obj.hTraceBaseline(t).YData = nan;
                end
                % ideal
                if obj.hShowIdealBtn.Value
                    if t == 1
                        ideal = y;
                        ideal(y <= 0.5) = 0.25;
                        ideal(y > 0.5) = 0.75;
                    else
                        ideal = y;
                        ideal(y <= 0.25) = 0.125;
                        ideal(y > 0.25) = 0.375;
                    end
                else
                    ideal = [];
                end
                if isequal(size(y), size(ideal))
                    obj.hTraceIdealLine(t).XData = x;
                    obj.hTraceIdealLine(t).YData = ideal;
                    obj.hTraceIdealLine(t).Color = obj.colors(colorIndex,:);
                    colorIndex = colorIndex + 1;
                    obj.hTraceIdealLine(t).Visible = 'on';
                else
                    obj.hTraceIdealLine(t).Visible = 'off';
                    obj.hTraceIdealLine(t).XData = nan;
                    obj.hTraceIdealLine(t).YData = nan;
                end
                % histogram
                nbins = str2num(obj.hHistNumBinsEdit.String);
                ylim = [min(y) max(y)];
                ylim = ylim + [-1 1] .* (0.1 * diff(ylim));
                edges = linspace(ylim(1), ylim(2), nbins + 1);
                centers = (edges(1:end-1) + edges(2:end)) / 2;
                counts = histcounts(y, edges);
                area = trapz(centers, counts);
                sqrtCounts = obj.hHistSqrtCountsBtn.Value;
                if sqrtCounts
                    counts = sqrt(counts);
                end
                obj.hHistBar(t).XData = centers;
                obj.hHistBar(t).YData = counts;
                obj.hHistBar(t).FaceColor = obj.hTraceLine(t).Color;
                obj.hHistBar(t).Visible = 'on';
                % ideal histogram
                if isequal(size(y), size(ideal))
                    if numel(centers) < 100
                        bins = reshape(linspace(edges(1), edges(end), 101), [] ,1);
                    else
                        bins = reshape(centers, [], 1);
                    end
                    ustates = unique(ideal);
                    nustates = numel(ustates);
                    fits = zeros(numel(bins), nustates);
                    npts = numel(ideal);
                    for k = 1:nustates
                        idx = ideal == ustates(k);
                        [mu, sigma] = normfit(y(idx));
                        weight = double(sum(idx)) / npts * area;
                        fits(:,k) = weight .* normpdf(bins, mu, sigma);
                    end
                    if sqrtCounts
                        fits = sqrt(fits);
                    end
                    bins = repmat(bins, 1, nustates);
                    bins = [bins; nan(1,nustates)];
                    fits = [fits; nan(1,nustates)];
                    obj.hHistIdealLines(t).XData = reshape(fits, [], 1);
                    obj.hHistIdealLines(t).YData = reshape(bins, [], 1);
                    obj.hHistIdealLines(t).Color = obj.hTraceIdealLine(t).Color;
                    obj.hHistIdealLines(t).Visible = 'on';
                    obj.hHistUpperRightText.String = strtrim([obj.hHistUpperRightText.String ' ' num2str(nustates)]);
                    obj.hHistUpperRightText.Visible = 'on';
                else
                    obj.hHistIdealLines(t).Visible = 'off';
                    obj.hHistIdealLines(t).XData = nan;
                    obj.hHistIdealLines(t).YData = nan;
%                     if t == 1
%                         obj.hHistUpperRightText(t).Visible = 'off';
%                         obj.hHistUpperRightText.String = '';
%                     end
                end
            end
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
        
        function resize(obj)
            %RESIZE Reposition all graphics objects within hPanel.
            
            % reposition image axes within panel
            bbox = getpixelposition(obj.hPanel);
            margin = 2;
            lineh = 20;
            x = margin + 40;
            y = margin + lineh + margin;
            w = bbox(3) - margin - x;
            h = bbox(4) - margin - lineh - margin - y;
            if ~isempty(obj.hTraceAxes.YLabel.String)
                x = x + lineh;
                w = w - lineh;
            end
            if ~isempty(obj.hTraceAxes.XLabel.String)
                y = y + lineh;
                h = h - lineh;
            end
            obj.hTraceAxes.Position = [x y w-100-margin h];
            obj.hHistAxes.Position = [x+w-100 y 100 h];
            % get actual displayed image axes position.
            pos = Utilities.plotboxpos(obj.hTraceAxes);
            x = pos(1); y = pos(2); w = pos(3); h = pos(4);
            
            % top buttons
            by = y + h + margin;
            bx = x + 35;
            obj.hMenuBtn.Position = [bx by lineh lineh];
            bx = x + w - 3*lineh;
            obj.hAutoscaleXBtn.Position = [bx by lineh lineh];
            obj.hAutoscaleYBtn.Position = [bx+lineh by lineh lineh];
            obj.hAutoscaleXYBtn.Position = [bx+2*lineh by lineh lineh];
            bx = bx - margin - 3*lineh;
            obj.hShowRawOrBtnGroup.Position = [bx by 3*lineh lineh];
            obj.hShowRawBtn.Position = [0 0 lineh lineh];
            obj.hShowBaselinedBtn.Position = [lineh 0 lineh lineh];
            obj.hShowBaselinedAndScaledBtn.Position = [2*lineh 0 lineh lineh];
            bx = bx - margin - 3*lineh;
            obj.hFilterBtn.Position = [bx by lineh lineh];
            obj.hShowIdealBtn.Position = [bx+lineh by lineh lineh];
            obj.hShowBaselineBtn.Position = [bx+2*lineh by lineh lineh];
            bx = x + w + margin;
            obj.hHistNumBinsText.Position = [bx by 30 lineh];
            obj.hHistNumBinsEdit.Position = [bx+30 by 70-lineh lineh];
            obj.hHistSqrtCountsBtn.Position = [bx+100-lineh by lineh lineh];
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
        end
        
        function updateTrace(obj)
            if obj.Visible == "off"
                return
            end
%             obj.updateTopText();
            hSpot = obj.hChannel.hSelectedSpot;
            if ~isempty(hSpot)
                hSpot.updateZProjectionFromImageStack();
                [x, y, isMasked] = hSpot.getTimeSeriesData();
                if ~isempty(y)
                    obj.hTraceLine.XData = x;
                    obj.hTraceLine.YData = y;
                    obj.autoscaleY();
                    obj.hTraceLine.Visible = 'on';
                    obj.hHistAxes.XLabel.String = [char(hex2dec('2190')) ' ' char(hSpot.tsData.timeUnits)];
                    % ideal
                    if obj.hShowIdealBtn.Value
                        try
                            ideal = hSpot.tsModel.idealData;
                        catch
                            ideal = [];
                        end
                        if isequal(size(y), size(ideal))
                            obj.hTraceIdealLine.XData = x;
                            obj.hTraceIdealLine.YData = ideal;
                            obj.hTraceIdealLine.Visible = 'on';
                        else
                            obj.hTraceIdealLine.Visible = 'off';
                            obj.hTraceIdealLine.XData = nan;
                            obj.hTraceIdealLine.YData = nan;
                        end
                    else
                        ideal = [];
                        obj.hTraceIdealLine.Visible = 'off';
                        obj.hTraceIdealLine.XData = nan;
                        obj.hTraceIdealLine.YData = nan;
                    end
                    % histogram
                    nbins = str2num(obj.hHistNumBinsEdit.String);
                    limits = obj.hTraceAxes.YLim;
                    edges = linspace(limits(1), limits(2), nbins + 1);
                    centers = (edges(1:end-1) + edges(2:end)) / 2;
                    counts = histcounts(y, edges);
                    area = trapz(centers, counts);
                    sqrtCounts = obj.hHistSqrtCountsBtn.Value;
                    if sqrtCounts
                        counts = sqrt(counts);
                    end
                    obj.hHistBar.XData = centers;
                    obj.hHistBar.YData = counts;
                    obj.hHistBar.Visible = 'on';
                    % norm dist about idealized states
                    if isempty(ideal)
                        obj.hHistIdealLines.Visible = 'off';
                        obj.hHistIdealLines.XData = nan;
                        obj.hHistIdealLines.YData = nan;
                        obj.hHistUpperRightText.Visible = 'off';
                    else
                        if numel(centers) < 100
                            bins = reshape(linspace(edges(1), edges(end), 101), [] ,1);
                        else
                            bins = reshape(centers, [], 1);
                        end
                        ustates = unique(ideal);
                        nustates = numel(ustates);
                        fits = zeros(numel(bins), nustates);
                        npts = numel(ideal);
                        for k = 1:nustates
                            idx = ideal == ustates(k);
                            [mu, sigma] = normfit(y(idx));
                            weight = double(sum(idx)) / npts * area;
                            fits(:,k) = weight .* normpdf(bins, mu, sigma);
                        end
                        if sqrtCounts
                            fits = sqrt(fits);
                        end
                        bins = repmat(bins, 1, nustates);
                        bins = [bins; nan(1,nustates)];
                        fits = [fits; nan(1,nustates)];
                        obj.hHistIdealLines.XData = reshape(fits, [], 1);
                        obj.hHistIdealLines.YData = reshape(bins, [], 1);
                        obj.hHistIdealLines.Visible = 'on';
                        obj.hHistUpperRightText.String = num2str(nustates);
                        obj.hHistUpperRightText.Visible = 'on';
                    end
                    return
                end
            end
            obj.hTraceLine.Visible = 'off';
            obj.hTraceLine.XData = nan;
            obj.hTraceLine.YData = nan;
            obj.hTraceIdealLine.Visible = 'off';
            obj.hTraceIdealLine.XData = nan;
            obj.hTraceIdealLine.YData = nan;
            obj.hHistBar.Visible = 'off';
            obj.hHistBar.XData = nan;
            obj.hHistBar.YData = nan;
            obj.hHistIdealLines.Visible = 'off';
            obj.hHistIdealLines.XData = nan;
            obj.hHistIdealLines.YData = nan;
        end
        
        function autoscaleXY(obj)
            ymin = arrayfun(@(line) nanmin(line.YData), obj.hTraceLine);
            if isempty(ymin) || all(isnan(ymin))
                return
            end
            ymax = arrayfun(@(line) nanmax(line.YData), obj.hTraceLine);
            ymin = min(ymin);
            ymax = max(ymax);
            xmin = arrayfun(@(line) nanmin(line.XData), obj.hTraceLine);
            xmax = arrayfun(@(line) nanmax(line.XData), obj.hTraceLine);
            xmin = min(xmin);
            xmax = max(xmax);
            dy = 0.1 * (ymax - ymin);
            try
                axis(obj.hTraceAxes, [xmin xmax ymin-dy ymax+dy]);
            catch
            end
        end
        function autoscaleX(obj)
            xmin = arrayfun(@(line) nanmin(line.XData), obj.hTraceLine);
            if isempty(xmin) || all(isnan(xmin))
                return
            end
            xmax = arrayfun(@(line) nanmax(line.XData), obj.hTraceLine);
            xmin = min(xmin);
            xmax = max(xmax);
            try
                obj.hTraceAxes.XLim = [xmin xmax];
            catch
            end
        end
        function autoscaleY(obj)
            ymin = arrayfun(@(line) nanmin(line.YData), obj.hTraceLine);
            if isempty(ymin) || all(isnan(ymin))
                return
            end
            ymax = arrayfun(@(line) nanmax(line.YData), obj.hTraceLine);
            ymin = min(ymin);
            ymax = max(ymax);
            dy = 0.1 * (ymax - ymin);
            try
                obj.hTraceAxes.YLim = [ymin-dy ymax+dy];
            catch
            end
        end
        
        function xrange = getXRange(obj, msg)
            xrange = [];
            if ~exist('msg', 'var')
                msg = 'X Range:';
            end
            
            obj.hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels');
            x = obj.hMenuBtn.Position(1) + 2 * obj.hMenuBtn.Position(3);
            y = obj.hMenuBtn.Position(2);
            w = 300;
            h = obj.hMenuBtn.Position(4);
            obj.hDialogPanel.Position = [x y w h];
            
            uicontrol(obj.hDialogPanel, 'style', 'text', ...
                'String', msg, 'Position', [0 0 100 h], ...
                'HorizontalAlignment', 'right');
            from = uicontrol(obj.hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [100 0 60 h], ...
                'Callback', @fromEdited_);
            to = uicontrol(obj.hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [160 0 60 h], ...
                'Callback', @toEdited_);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [220 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [260 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', 'uiresume()');
            
            obj.hROI = drawrectangle(obj.hTraceAxes);
            obj.hROI.Position(2) = obj.hTraceAxes.YLim(1);
            obj.hROI.Position(4) = diff(obj.hTraceAxes.YLim);
            from.String = num2str(obj.hROI.Position(1));
            to.String = num2str(obj.hROI.Position(1) + obj.hROI.Position(3));
            listeners(1) = addlistener(obj.hROI, 'MovingROI', @roiEvent_);
            listeners(2) = addlistener(obj.hROI, 'ROIMoved', @roiEvent_);
            
            function fromEdited_(varargin)
                a = str2num(from.String);
                b = obj.hROI.Position(1) + obj.hROI.Position(3);
                obj.hROI.Position(1) = a;
                obj.hROI.Position(3) = max(0, b-a);
                if a > b
                    to.String = num2str(a);
                end
            end
            function toEdited_(varargin)
                a = obj.hROI.Position(1);
                b = str2num(to.String);
                obj.hROI.Position(1) = min(a, b);
                obj.hROI.Position(3) = max(0, b-a);
                if a > b
                    from.String = num2str(b);
                end
            end
            function roiEvent_(varargin)
                obj.hROI.Position(2) = obj.hTraceAxes.YLim(1);
                obj.hROI.Position(4) = diff(obj.hTraceAxes.YLim);
                from.String = num2str(obj.hROI.Position(1));
                to.String = num2str(obj.hROI.Position(1) + obj.hROI.Position(3));
            end
            function ok_(varargin)
                xrange = [obj.hROI.Position(1), obj.hROI.Position(1) + obj.hROI.Position(3)];
                uiresume();
            end
            
            uiwait();
            delete(listeners);
            delete(obj.hDialogPanel);
            delete(obj.hROI);
        end
    end
end

