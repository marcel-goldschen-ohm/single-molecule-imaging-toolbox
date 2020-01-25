classdef TimeSeriesViewer < handle
    %TIMESERIESVIEWER
    %
    %   TODO:
    %   - implement named data point selections
    %   - allow baselining to brushed data
    %   - baseline spline
    %   - visualize masking
    %   - resampling
    %   - filtering
    
    properties
        % time series data
        ts = TimeSeries.empty(1,0);
        
        % UI elements
        hPanel
        
        hTraceAxes
        hTraceZeroLine
        hTraceLine
        hTraceBaseLine
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
        hShowRawOrBtn
        hShowZeroBtn
        hShowBaselineBtn
        hShowIdealBtn
%         hFilterBtn
        
        visibleTsIndices
        tsLineOffset = 0;
        tsWrapWidth = inf;
        
        hVisibleTsEdit
        hPrevTsBtn
        hNextTsBtn
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
        
        isShowRaw
        isShowBaselined
        isShowBaselinedAndScaled
        
        isShowZero
        isShowBaseline
        isShowIdeal
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
            obj.hTraceZeroLine = line(ax, nan, nan, ...
                'LineStyle', '-', 'Color', [0.5 0.5 0.5], ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hTraceLine = line(ax, nan, nan, ...
                'LineStyle', '-', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hTraceBaseLine = line(ax, nan, nan, ...
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
            
            obj.hShowRawOrBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', 'BS', 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Raw, Baselined and/or Scaled Data', ...
                'Callback', @(varargin) obj.showRawOrBtnDown());
            
            obj.hShowZeroBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', '__', 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Zero Line', ...
                'Value', 0, ...
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
%             obj.hFilterBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
%                 'String', char(hex2dec('2a0d')), 'Position', [0 0 20 20], ...
%                 'Tooltip', 'Apply Filter', ...
%                 'Value', 1, ...
%                 'Callback', @(varargin) obj.updateUI());

            obj.hVisibleTsEdit = uicontrol(obj.hPanel, 'style', 'edit', ...
                'String', '', 'Position', [0 0 40 20], ...
                'Tooltip', 'Visible Time Series', ...
                'Callback', @(varargin) obj.goTo());
            obj.hPrevTsBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', '<', 'Position', [0 0 20 20], ...
                'Tooltip', 'Previous Time Series', ...
                'Callback', @(varargin) obj.prev());
            obj.hNextTsBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', '>', 'Position', [0 0 20 20], ...
                'Tooltip', 'Next Time Series', ...
                'Callback', @(varargin) obj.next());

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
            if ~isempty(obj.ts)
                obj.visibleTsIndices = 1;
            else
                obj.visibleTsIndices = [];
            end
            %obj.updateUI(); % called by set.visibleTraceIndices
        end
        function set.visibleTsIndices(obj, idx)
            obj.visibleTsIndices = idx;
            obj.updateUI();
        end
        function updateUI(obj)
            numTs = numel(obj.ts);
            % delete unneeded graphics objects
            if numel(obj.hTraceLine) > numTs
                delete(obj.hTraceLine(numTs+1:end));
                delete(obj.hTraceIdealLine(numTs+1:end));
                delete(obj.hHistBar(numTs+1:end));
                delete(obj.hHistIdealLines(numTs+1:end));
            end
            % default text in histogram is off, we'll turn it on as needed
            obj.hHistUpperRightText.Visible = 'off';
            obj.hHistUpperRightText.String = '';
            % keep track of colors used
            colorIndex = 1;
            % offset between multiple or wrapped time series
            y0 = 0;
            % loop over each time series
            for t = 1:numTs
                % create graphics objects for this time series if needed
                if numel(obj.hTraceLine) < t
                    obj.hTraceZeroLine(t) = line(obj.hTraceAxes, nan, nan, ...
                        'LineStyle', '-', 'Color', [0.5 0.5 0.5], ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                    obj.hTraceLine(t) = line(obj.hTraceAxes, nan, nan, ...
                        'LineStyle', '-', ...
                        'HitTest', 'off', 'PickableParts', 'none', ...
                        'Visible', 'off');
                    obj.hTraceBaseLine(t) = line(obj.hTraceAxes, nan, nan, ...
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
                % get the time series data
                try
                    if find(obj.visibleTsIndices == t, 1)
                        x = obj.ts(t).time;
                        if obj.isShowRaw
                            y = obj.ts(t).rawData;
                        elseif obj.isShowBaselined
                            y = obj.ts(t).rawData + obj.ts(t).offset;
                        else % baselined and scaled
                            y = obj.ts(t).data;
                        end
                    else
                        x = [];
                        y = [];
                    end
                catch
                    x = [];
                    y = [];
                end
                if isempty(y)
                    % if no time series data, hide all associated graphics
                    % objects and go to the next time series
                    obj.hTraceZeroLine(t).Visible = 'off';
                    obj.hTraceZeroLine(t).XData = nan;
                    obj.hTraceZeroLine(t).YData = nan;
                    obj.hTraceLine(t).Visible = 'off';
                    obj.hTraceLine(t).XData = nan;
                    obj.hTraceLine(t).YData = nan;
                    obj.hTraceBaseLine(t).Visible = 'off';
                    obj.hTraceBaseLine(t).XData = nan;
                    obj.hTraceBaseLine(t).YData = nan;
                    obj.hTraceIdealLine(t).Visible = 'off';
                    obj.hTraceIdealLine(t).XData = nan;
                    obj.hTraceIdealLine(t).YData = nan;
                    obj.hHistBar(t).Visible = 'off';
                    obj.hHistBar(t).XData = nan;
                    obj.hHistBar(t).YData = nan;
                    obj.hHistIdealLines(t).Visible = 'off';
                    obj.hHistIdealLines(t).XData = nan;
                    obj.hHistIdealLines(t).YData = nan;
                    continue
                end
                % trace wrap?
                nowrap = isinf(obj.tsWrapWidth) || x(end) - x(1) <= obj.tsWrapWidth;
                if ~nowrap
                    wrapNumPts = find(x - x(1) > obj.tsWrapWidth, 1) - 1;
                    wrapNumSegments = ceil(double(length(y)) / wrapNumPts);
                end
                % zero line (mostly for offset time series)
                if obj.isShowZero
                    if nowrap
                        obj.hTraceZeroLine(t).XData = [x(1); x(end)];
                        obj.hTraceZeroLine(t).YData = [y0; y0];
                    else
                        obj.hTraceZeroLine(t).XData = ...
                            repmat([x(1); x(1) + obj.tsWrapWidth; nan], wrapNumSegments, 1);
                        obj.hTraceZeroLine(t).YData = reshape( ...
                            repmat([y0; y0; nan], 1, wrapNumSegments) ...
                            + repmat([obj.tsLineOffset; obj.tsLineOffset; nan], 1, wrapNumSegments) ...
                            .* repmat(0:wrapNumSegments-1, 3, 1), ...
                            [], 1);
                    end
                    obj.hTraceZeroLine(t).Visible = 'on';
                else
                    % hide uneeded zero line
                    obj.hTraceZeroLine(t).Visible = 'off';
                    obj.hTraceZeroLine(t).XData = nan;
                    obj.hTraceZeroLine(t).YData = nan;
                end
                % offset time series data
                if obj.tsLineOffset ~= 0
                    y = y + y0;
                end
                % plot time series data
                if nowrap
                    obj.hTraceLine(t).XData = x;
                    obj.hTraceLine(t).YData = y;
                else
                    % wrap trace every so many points
                    [wx, wy] = TimeSeriesViewer.wrap(x, y, wrapNumPts, obj.tsLineOffset);
                    obj.hTraceLine(t).XData = wx;
                    obj.hTraceLine(t).YData = wy;
                end
                if obj.tsLineOffset == 0
                    % if we're not offsetting multiple time series,
                    % give each time series a unique color
                    obj.hTraceLine(t).Color = obj.colors(colorIndex,:);
                    colorIndex = colorIndex + 1;
                else
                    % if we are offsetting multiple time series, use the
                    % same color for all of them
                    obj.hTraceLine(t).Color = obj.colors(1,:);
                end
                obj.hTraceLine(t).Visible = 'on';
                % baseline
                if obj.isShowBaseline
                    if obj.isShowRaw
                        % baseline on top of raw data
                        baseline = zeros(size(y)) - obj.ts(t).offset + y0;
                    else
                        % baselined data will have a baseline at zero (or
                        % offset if we are offseting this time series)
                        baseline = zeros(size(y)) + y0;
                    end
                    if nowrap
                        obj.hTraceBaseLine(t).XData = x;
                        obj.hTraceBaseLine(t).YData = baseline;
                    else
                        % wrap trace every so many points
                        [~, wbaseline] = TimeSeriesViewer.wrap(x, baseline, wrapNumPts, obj.tsLineOffset);
                        obj.hTraceBaseLine(t).XData = wx;
                        obj.hTraceBaseLine(t).YData = wbaseline;
                    end
                    obj.hTraceBaseLine(t).Visible = 'on';
                else
                    obj.hTraceBaseLine(t).Visible = 'off';
                    obj.hTraceBaseLine(t).XData = nan;
                    obj.hTraceBaseLine(t).YData = nan;
                end
                % ideal
                if obj.isShowIdeal
                    % ... TODO
                    ideal = [];
                    % ideal = ... + y0;
                else
                    ideal = [];
                end
                if isequal(size(y), size(ideal))
                    % draw ideal trace on top of data
                    if nowrap
                        obj.hTraceIdealLine(t).XData = x;
                        obj.hTraceIdealLine(t).YData = ideal;
                    else
                        % wrap trace every so many points
                        [~, wideal] = TimeSeriesViewer.wrap(x, ideal, wrapNumPts, obj.tsLineOffset);
                        obj.hTraceIdealLine(t).XData = wx;
                        obj.hTraceIdealLine(t).YData = wideal;
                    end
                    if obj.tsLineOffset == 0
                        % if we're not offsetting multiple time series,
                        % give each time series a unique color
                        obj.hTraceIdealLine(t).Color = obj.colors(colorIndex,:);
                        colorIndex = colorIndex + 1;
                    else
                        % if we are offsetting multiple time series, use
                        % the same color for all of them
                        obj.hTraceIdealLine(t).Color = obj.colors(2,:);
                    end
                    obj.hTraceIdealLine(t).Visible = 'on';
                else
                    obj.hTraceIdealLine(t).Visible = 'off';
                    obj.hTraceIdealLine(t).XData = nan;
                    obj.hTraceIdealLine(t).YData = nan;
                end
                % histogram
                nbins = str2num(obj.hHistNumBinsEdit.String);
                if nowrap
                    ynn = y(~isnan(y));
                else
                    ynn = wy(~isnan(wy));
                end
                ylim = minmax(reshape(ynn, 1, []));
                ylim = ylim + [-1 1] .* (0.1 * diff(ylim));
                edges = linspace(ylim(1), ylim(2), nbins + 1);
                centers = (edges(1:end-1) + edges(2:end)) / 2;
                counts = histcounts(ynn, edges);
                area = trapz(centers, counts);
                sqrtCounts = obj.hHistSqrtCountsBtn.Value;
                if sqrtCounts
                    counts = sqrt(counts);
                end
                % plot histogram of data
                obj.hHistBar(t).XData = centers;
                obj.hHistBar(t).YData = counts;
                obj.hHistBar(t).FaceColor = obj.hTraceLine(t).Color;
                obj.hHistBar(t).Visible = 'on';
                % ideal histogram
                if isequal(size(y), size(ideal))
                    % plot a GMM fit to data overlaid on the histogram
                    % based on levels in ideal trace
                    if numel(centers) < 100
                        bins = reshape(linspace(edges(1), edges(end), 101), [] ,1);
                    else
                        bins = reshape(centers, [], 1);
                    end
                    if nowrap
                        idealnn = ideal(~isnan(ideal));
                    else
                        idealnn = wideal(~isnan(wideal));
                    end
                    ustates = unique(idealnn);
                    nustates = numel(ustates);
                    fits = zeros(numel(bins), nustates);
                    npts = numel(idealnn);
                    for k = 1:nustates
                        idx = idealnn == ustates(k);
                        [mu, sigma] = normfit(ynn(idx));
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
                    % indicate # of idealized states in upper right of
                    % histogram axes
                    obj.hHistUpperRightText.String = ...
                        strtrim([obj.hHistUpperRightText.String ' ' num2str(nustates)]);
                    obj.hHistUpperRightText.Visible = 'on';
                else
                    obj.hHistIdealLines(t).Visible = 'off';
                    obj.hHistIdealLines(t).XData = nan;
                    obj.hHistIdealLines(t).YData = nan;
                end
                if obj.tsLineOffset ~= 0
                    % increment offset for next time series
                    if nowrap
                        y0 = y0 + obj.tsLineOffset;
                    else
                        y0 = y0 + wrapNumSegments * obj.tsLineOffset;
                    end
                end
            end
        end
        
        function set.tsLineOffset(obj, yoffset)
            obj.tsLineOffset = yoffset;
            obj.updateUI();
        end
        function setTsLineOffsetDialog(obj)
            answer = inputdlg({'Y axis offset between data lines'}, 'Line Offset', 1, {num2str(obj.tsLineOffset)});
            if ~isempty(answer)
                obj.tsLineOffset = str2num(answer{1});
            end
        end
        
        function set.tsWrapWidth(obj, w)
            if w <= 0
                w = inf;
            end
            obj.tsWrapWidth = w;
            obj.updateUI();
        end
        function setTsWrapWidthDialog(obj)
            answer = inputdlg({'Wrap width (inf => no wrap):'}, 'Wrap Width', 1, {num2str(obj.tsWrapWidth)});
            if ~isempty(answer)
                obj.tsWrapWidth = str2num(answer{1});
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
        
        function tf = get.isShowRaw(obj)
            tf = obj.hShowRawOrBtn.String == "R";
        end
        function tf = get.isShowBaselined(obj)
            tf = obj.hShowRawOrBtn.String == "B";
        end
        function tf = get.isShowBaselinedAndScaled(obj)
            tf = obj.hShowRawOrBtn.String == "BS";
        end
        function showRaw(obj)
            obj.hShowRawOrBtn.String = "R";
            obj.updateUI();
        end
        function showBaselined(obj)
            obj.hShowRawOrBtn.String = "B";
            obj.updateUI();
        end
        function showBaselinedAndScaled(obj)
            obj.hShowRawOrBtn.String = "BS";
            obj.updateUI();
        end
        function tf = get.isShowZero(obj)
            tf = obj.hShowZeroBtn.Value > 0;
        end
        function tf = get.isShowBaseline(obj)
            tf = obj.hShowBaselineBtn.Value > 0;
        end
        function tf = get.isShowIdeal(obj)
            tf = obj.hShowIdealBtn.Value > 0;
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
            bx = bx - 5 - 3*lineh;
%             obj.hFilterBtn.Position = [bx by lineh lineh];
            obj.hShowIdealBtn.Position = [bx by lineh lineh];
            obj.hShowBaselineBtn.Position = [bx+lineh by lineh lineh];
            obj.hShowZeroBtn.Position = [bx+2*lineh by lineh lineh];
            bx = bx - 5 - lineh;
            obj.hShowRawOrBtn.Position = [bx by lineh lineh];
            bx = bx - 5 - 4*lineh;
            obj.hPrevTsBtn.Position = [bx by lineh lineh];
            obj.hVisibleTsEdit.Position = [bx+lineh by 2*lineh lineh];
            obj.hNextTsBtn.Position = [bx+3*lineh by lineh lineh];
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
            
            uimenu(menu, 'Label', 'Baseline Flat', ...
                'Callback', @(varargin) obj.baselineFlat());
            uimenu(menu, 'Label', 'Baseline Linear Two Region', ...
                'Callback', @(varargin) obj.baselineLinearTwoRegion());
            
            submenu = uimenu(menu, 'Label', 'Display Options', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Set Multi-Line Offset', ...
                'Callback', @(varargin) obj.setTsLineOffsetDialog());
            uimenu(submenu, 'Label', 'Set Data Wrap Width', ...
                'Callback', @(varargin) obj.setTsWrapWidthDialog());
        end
        
        function showRawOrBtnDown(obj)
            menu = uicontextmenu;
            uimenu(menu, 'Label', '(R) Show Raw Data', ...
                'Checked', obj.isShowRaw, ...
                'Callback', @(varargin) obj.showRaw());
            uimenu(menu, 'Label', '(B) Show Baselined Data', ...
                'Checked', obj.isShowBaselined, ...
                'Callback', @(varargin) obj.showBaselined());
            uimenu(menu, 'Label', '(BS) Show Baselined & Scaled Data', ...
                'Checked', obj.isShowBaselinedAndScaled, ...
                'Callback', @(varargin) obj.showBaselinedAndScaled());
            
            hFig = ancestor(obj.hPanel, 'Figure');
            menu.Parent = hFig;
            pos = Utilities.getPixelPositionInAncestor(obj.hShowRawOrBtn, hFig);
            menu.Position(1:2) = pos(1:2);
            menu.Visible = 1;
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
        
        function goTo(obj, t)
            if isempty(obj.ts)
                return
            end
            n = numel(obj.ts);
            allStr = sprintf("1:%d", n);
            if ~exist('t', 'var')
                if obj.hVisibleTsEdit.String == allStr
                    t = 1:n;
                else
                    t = str2num(obj.hVisibleTsEdit.String);
                    if isempty(t)
                        t = 1:n;
                    end
                end
            end
            if isempty(t)
                t = 1;
            else
                t(t < 1) = 1;
                t(t > n) = n;
                t = unique(t);
            end
            obj.visibleTsIndices = t; % will call updateUI()
            if isequal(t, 1:n)
                obj.hVisibleTsEdit.String = allStr;
            else
                obj.hVisibleTsEdit.String = num2str(t);
            end
        end
        function prev(obj)
            n = numel(obj.ts);
            allStr = sprintf("1:%d", n);
            if obj.hVisibleTsEdit.String == allStr
                obj.goTo(n);
                return
            end
            t = str2num(obj.hVisibleTsEdit.String);
            if isempty(t) % all t
                obj.goTo(n);
            elseif numel(t) > 1
                obj.goTo(t(end));
            elseif t > 1
                obj.goTo(t-1);
            end
        end
        function next(obj)
            n = numel(obj.ts);
            allStr = sprintf("1:%d", n);
            if obj.hVisibleTsEdit.String == allStr
                obj.goTo(1);
                return
            end
            t = str2num(obj.hVisibleTsEdit.String);
            if isempty(t) % all t
                obj.goTo(1);
            elseif numel(t) > 1
                obj.goTo(t(1));
            elseif t < n
                obj.goTo(t+1);
            end
        end
        
        function xrange = selectXRange(obj, msg, msgWidth)
            xrange = [];
            if ~exist('msg', 'var')
                msg = 'X Range:';
            end
            if ~exist('msgWidth', 'var')
                msgWidth = 20 + 5 * length(msg);
            end
            
            obj.hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels');
            x = obj.hMenuBtn.Position(1) + 2 * obj.hMenuBtn.Position(3);
            y = obj.hMenuBtn.Position(2);
            w = msgWidth + 200;
            h = obj.hMenuBtn.Position(4);
            obj.hDialogPanel.Position = [x y w h];
            
            uicontrol(obj.hDialogPanel, 'style', 'text', ...
                'String', msg, 'Position', [0 0 msgWidth h], ...
                'HorizontalAlignment', 'right');
            from = uicontrol(obj.hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [msgWidth 0 60 h], ...
                'Callback', @fromEdited_);
            to = uicontrol(obj.hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [msgWidth+60 0 60 h], ...
                'Callback', @toEdited_);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [msgWidth+120 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [msgWidth+160 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', 'uiresume()');
            
            obj.hROI = drawrectangle(obj.hTraceAxes, ...
                'LineWidth', 1);
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
        function baselineFlat(obj)
            xrange = obj.selectXRange('Baseline Region:');
            for t = obj.visibleTsIndices
                try
                    x = obj.ts(t).time;
                    idx = (x >= xrange(1)) & (x <= xrange(2));
                    obj.ts(t).offset = -mean(obj.ts(t).rawData(idx));
                catch
                end
            end
            obj.updateUI();
        end
        function baselineLinearTwoRegion(obj)
            xrange1 = obj.selectXRange('Baseline Region 1/2:');
            xrange2 = obj.selectXRange('Baseline Region 2/2:');
%             x1 = mean(xrange1);
%             x2 = mean(xrange2);
            for t = obj.visibleTsIndices
                try
                    x = obj.ts(t).time;
                    idx1 = (x >= xrange1(1)) & (x <= xrange1(2));
                    idx2 = (x >= xrange2(1)) & (x <= xrange2(2));
                    idx = union(idx1, idx2);
                    lx = x(idx);
                    ly = y(idx);
                    fit = polyfit(lx, ly, 1);
                    obj.ts(t).offset = -polyval(fit, x);
%                     y1 = mean(obj.ts(t).rawData(idx1));
%                     y2 = mean(obj.ts(t).rawData(idx2));
%                     m = (y2 - y1) / (x2 - x1);
%                     b = y1 - m * x1;
%                     obj.ts(t).offset = -(m .* x + b);
                catch
                end
            end
            obj.updateUI();
        end
    end
    
    methods (Static)
        function [wx, wy] = wrap(x, y, N, yoffset)
            % wrap x and y every N data points and offset each wrapped
            % segment by yoffset
            % insert nan to separate wrapped segments
            n = length(y);
            numSegments = ceil(double(n) / N);
            wn = n+(numSegments-1);
            wx = repmat([x(1:N); nan], numSegments, 1);
            wx = wx(1:wn);
            wy = nan(wn,1);
            dati = true(wn,1);
            dati(N+1:N+1:end) = false;
            wy(dati) = y;
            wrapoffset = ...
                reshape([ ...
                repmat(((0:numSegments-1) .* yoffset), N, 1); ...
                nan(1,numSegments) ...
                ], [], 1);
            wy = wy + wrapoffset(1:wn);
        end
    end
end

