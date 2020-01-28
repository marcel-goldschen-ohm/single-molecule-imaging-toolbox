classdef TimeSeriesExtViewer < handle
    %TIMESERIESEXTVIEWER
    
    properties
        % time series data
        ts = TimeSeriesExt.empty(1,0);
        visibleTsIndices
        
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
        hTopText
        hAutoscaleXYBtn
        hAutoscaleYBtn
        hAutoscaleXBtn
        hShowRawOrBtn
        hShowMaskedBtn
        hShowZeroBtn
        hShowBaselineBtn
        hShowIdealBtn
        hApplyFilterBtn
        
        hVisibleTsEdit
        hPrevTsBtn
        hNextTsBtn
        
        filterObj
        
        tsLineOffset = 0;
        tsWrapWidth = inf;
        isShowHist = true;
        
        sumSamplesN = 1;
        downsampleN = 1;
        upsampleN = 1;
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
        
        isShowMasked
        isShowZero
        isShowBaseline
        isShowIdeal
        isApplyFilter
    end
    
    methods
        function obj = TimeSeriesExtViewer(parent)
            %TIMESERIESEXTVIEWER Constructor.
            
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
                'LineStyle', '-', 'Color', [0.75 0.75 0.75], ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hTraceLine = plot(ax, nan, nan, ...
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
                'Position', [0 0 100 1], ...
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
            obj.hTopText = uicontrol(obj.hPanel, 'style', 'text', ...
                'String', '', 'Position', [0 0 0 20], ...
                'Visible', 'off');
            
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
            obj.hShowMaskedBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', 'M', 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Masked Data Points', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI());
            
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
            obj.hApplyFilterBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('2a0d')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Apply Filter', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateUI());

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
            isInit = isempty(obj.ts) && isempty(obj.visibleTsIndices);
            obj.ts = ts;
            if isInit
                obj.goTo(1);
            end
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
                    obj.hTraceLine(t) = plot(obj.hTraceAxes, nan, nan, ...
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
                        [x, y] = obj.getTimeSeriesAsShown(t);
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
                    [wx, wy] = TimeSeriesExtViewer.wrap(x, y, wrapNumPts, obj.tsLineOffset);
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
                        offset = obj.ts(t).offset;
                        if numel(offset) > 1
                            if obj.sumSamplesN > 1
                                N = obj.sumSamplesN;
                                n = floor(double(size(offset,1)) / N);
                                offset0 = offset;
                                offset = offset0(1:N:n*N,:);
                                for k = 2:N
                                    offset = offset + offset0(k:N:n*N,:);
                                end
                            end
                            if obj.downsampleN > 1 || obj.upsampleN > 1
                                offset = resample(offset, obj.upsampleN, obj.downsampleN);
                            end
                        end
                        baseline = zeros(size(y)) - offset + y0;
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
                        [~, wbaseline] = TimeSeriesExtViewer.wrap(x, baseline, wrapNumPts, obj.tsLineOffset);
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
                        [~, wideal] = TimeSeriesExtViewer.wrap(x, ideal, wrapNumPts, obj.tsLineOffset);
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
            if isempty(w) || w <= 0
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
        
        function set.isShowHist(obj, tf)
            obj.isShowHist = tf;
            obj.resize();
        end
        function toggleShowHist(obj)
            obj.isShowHist = ~obj.isShowHist;
        end
        
        function set.sumSamplesN(obj, N)
            if isempty(N)
                N = 1;
            end
            obj.sumSamplesN = N;
            obj.updateUI();
        end
        function setSumSamplesN(obj, N)
            if ~exist('N', 'var')
                answer = inputdlg({'Sum blocks of N samples:'}, ...
                    'Sum Sample Blocks', 1, {num2str(obj.sumSamplesN)});
                if isempty(answer)
                    return
                end
                N = str2num(answer{1});
            end
            obj.sumSamplesN = N;
        end
        
        function set.downsampleN(obj, N)
            if isempty(N)
                N = 1;
            end
            obj.downsampleN = N;
            obj.updateUI();
        end
        function set.upsampleN(obj, N)
            if isempty(N)
                N = 1;
            end
            obj.upsampleN = N;
            obj.updateUI();
        end
        function setResampling(obj, P, Q)
            if ~exist('P', 'var') || ~exist('Q', 'var')
                answer = inputdlg({'Resample at P/Q original rate (1/1 => no resampling):'}, ...
                    'Resample', 1, {'1/1'});
                if isempty(answer)
                    return
                end
                try
                    PQ = strsplit(answer{1}, '/');
                    P = str2num(PQ{1});
                    Q = str2num(PQ{2});
                catch
                    return
                end
            end
            if isempty(P)
                P = 1;
            end
            if isempty(Q)
                Q = 1;
            end
            obj.upsampleN = P;
            obj.downsampleN = Q;
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
        function tf = get.isShowMasked(obj)
            tf = obj.hShowMaskedBtn.Value > 0;
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
        function tf = get.isApplyFilter(obj)
            tf = obj.hApplyFilterBtn.Value > 0;
        end
        
        function [x, y] = getTimeSeriesAsShown(obj, t)
            x = obj.ts(t).time;
            if obj.isShowRaw
                y = obj.ts(t).raw.data;
            elseif obj.isShowBaselined
                y = obj.ts(t).raw.data + obj.ts(t).offset;
            else % baselined and scaled
                y = obj.ts(t).data;
            end
            % filter
            if obj.isApplyFilter && ~isempty(obj.filterObj)
                y = filtfilt(obj.filterObj, y);
            end
            % mask
            if ~obj.isShowMasked && any(obj.ts(t).isMasked)
                y(obj.ts(t).mask) = nan;
            end
            % sum sample blocks
            if obj.sumSamplesN > 1
                N = obj.sumSamplesN;
                n = floor(double(size(y,1)) / N);
                y0 = y;
                y = y0(1:N:n*N,:);
                for k = 2:N
                    y = y + y0(k:N:n*N,:);
                end
                x = x(1:N:n*N);
            end
            % resample
            if (obj.downsampleN > 1 || obj.upsampleN > 1) ...
                    && (obj.downsampleN ~= obj.upsampleN)
                if obj.upsampleN > 1
                    N = obj.upsampleN;
                    x0 = x;
                    dx = diff(x0);
                    dx = double(dx) ./ N;
                    x = upsample(x0, N);
                    x = x(1:end-(N-1));
                    for k = 2:N
                        x(k:N:end-1) = x0(1:end-1) + (k-1) .* dx;
                    end
                end
                if obj.downsampleN > 1
                    x = downsample(x, obj.downsampleN);
                end
                y = resample(y, obj.upsampleN, obj.downsampleN);
                y = y(1:length(x));
            end
        end
        function sel = getBrushedSelectionForRawData(obj, t)
            sel = logical(obj.hTraceLine(t).BrushData);
            if isempty(sel)
                return
            elseif ~any(sel)
                sel = logical([]);
                return
            end
            
            % convert sel from plotted indices to original raw data indices
            
            % wrap
            if ~isinf(obj.tsWrapWidth)
                x = obj.ts(t).time;
                if x(end) - x(1) > obj.tsWrapWidth
                    wrapNumPts = find(x - x(1) > obj.tsWrapWidth, 1) - 1;
                    sel(wrapNumPts+1:wrapNumPts+1:end) = [];
                end
            end
            % resample
            if (obj.downsampleN > 1 || obj.upsampleN > 1) ...
                    && (obj.downsampleN ~= obj.upsampleN)
                if obj.downsampleN > 1
                    N = obj.downsampleN;
                    sel = reshape(repmat(reshape(sel, 1, []), N, 1), 1, []);
                end
                if obj.upsampleN > 1
                    N = obj.upsampleN;
                    sel = reshape(sel, 1, []);
                    pad = mod(length(sel), N);
                    if pad > 0
                        sel(end+1:end+N-pad) = false;
                    end
                    sel = any(reshape(sel, N, []), 1);
                end
            end
            % sum sample blocks
            if obj.sumSamplesN > 1
                N = obj.sumSamplesN;
                sel = reshape(repmat(reshape(sel, 1, []), N, 1), 1, []);
            end
            % resampling may have left sel with the wrong number of pts
            n = size(obj.ts(t).raw.data, 1);
            if length(sel) < n
                sel(end+1:n) = false;
            elseif length(sel) > n
                sel(n+1:end) = [];
            end
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
            if obj.isShowHist
                hw = obj.hHistAxes.Position(3);
                obj.hTraceAxes.Position = [x y w-hw-margin h];
                obj.hHistAxes.Position = [x+w-hw y hw h];
                obj.hHistAxes.Visible = 'on';
                [obj.hHistAxes.Children.Visible] = deal('on');
            else
                obj.hTraceAxes.Position = [x y w-10 h];
                obj.hHistAxes.Visible = 'off';
                [obj.hHistAxes.Children.Visible] = deal('off');
            end
            % get actual displayed image axes position.
            pos = Utilities.plotboxpos(obj.hTraceAxes);
            x = pos(1); y = pos(2); w = pos(3); h = pos(4);
            
            % top buttons
            by = y + h + margin;
            bx = margin;%x + 35;
            obj.hMenuBtn.Position = [bx by lineh lineh];
            bx = x + w - 3*lineh;
            obj.hAutoscaleXBtn.Position = [bx by lineh lineh];
            obj.hAutoscaleYBtn.Position = [bx+lineh by lineh lineh];
            obj.hAutoscaleXYBtn.Position = [bx+2*lineh by lineh lineh];
            bx = bx - 5 - 4*lineh;
            obj.hApplyFilterBtn.Position = [bx by lineh lineh];
            obj.hShowIdealBtn.Position = [bx+lineh by lineh lineh];
            obj.hShowBaselineBtn.Position = [bx+2*lineh by lineh lineh];
            obj.hShowZeroBtn.Position = [bx+3*lineh by lineh lineh];
            bx = bx - 5 - 2*lineh;
            obj.hShowRawOrBtn.Position = [bx by lineh lineh];
            obj.hShowMaskedBtn.Position = [bx+lineh by lineh lineh];
            if isvalid(obj.hVisibleTsEdit) && obj.hVisibleTsEdit.Visible == "on"
                bx = bx - 5 - 4*lineh;
                obj.hPrevTsBtn.Position = [bx by lineh lineh];
                obj.hVisibleTsEdit.Position = [bx+lineh by 2*lineh lineh];
                obj.hNextTsBtn.Position = [bx+3*lineh by lineh lineh];
            end
            if obj.hTopText.Visible == "on"
                obj.hTopText.Position = [x+35 by bx-5-(x+35) lineh];
            end
            if obj.isShowHist
                bx = x + w + margin + hw - lineh - 80;
                obj.hHistNumBinsText.Position = [bx by 30 lineh];
                obj.hHistNumBinsEdit.Position = [bx+30 by 50 lineh];
                obj.hHistSqrtCountsBtn.Position = [bx+80 by lineh lineh];
                obj.hHistNumBinsText.Visible = 'on';
                obj.hHistNumBinsEdit.Visible = 'on';
                obj.hHistSqrtCountsBtn.Visible = 'on';
            else
                obj.hHistNumBinsText.Visible = 'off';
                obj.hHistNumBinsEdit.Visible = 'off';
                obj.hHistSqrtCountsBtn.Visible = 'off';
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
            %numTs = numel(obj.ts);
            
            keys = string.empty;
            for ts = obj.ts
                keys = [keys string(ts.selections.keys)];
            end
            submenu = uimenu(menu, 'Label', 'Selections');
            for key = unique(keys)
                uimenu(submenu, 'Label', key, ...
                    'Callback', @(varargin) obj.setSelection(key));
            end
            uimenu(menu, 'Label', 'Name Current Selection', ...
                'Callback', @(varargin) obj.nameCurrentSelection());
            submenu = uimenu(menu, 'Label', 'Remove Selection');
            for key = unique(keys)
                uimenu(submenu, 'Label', key, ...
                    'Callback', @(varargin) obj.removeSelection(key));
            end
            uimenu(menu, 'Label', 'Select All', ...
                'Callback', @(varargin) obj.selectAll());
            
            submenu = uimenu(menu, 'Label', 'Mask', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Mask Selection', ...
                'Callback', @(varargin) obj.maskSelection());
            uimenu(submenu, 'Label', 'Unmask Selection', ...
                'Callback', @(varargin) obj.unmaskSelection());
            uimenu(submenu, 'Label', 'Mask All', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.maskAll());
            uimenu(submenu, 'Label', 'Clear Mask', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearMask());
            
            submenu = uimenu(menu, 'Label', 'Baseline', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Baseline Flat', ...
                'Callback', @(varargin) obj.baselineFlat());
            uimenu(submenu, 'Label', 'Baseline Linear', ...
                'Callback', @(varargin) obj.baselineLinear());
            uimenu(submenu, 'Label', 'Baseline Polynomial', ...
                'Callback', @(varargin) obj.baselinePolynomialDialog());
            uimenu(submenu, 'Label', 'Baseline Spline', ...
                'Callback', @(varargin) obj.baselineSplineDialog());
            uimenu(submenu, 'Label', 'Baseline Nonlinear', ...
                'Callback', @(varargin) obj.baselineNonlinearDialog());
            uimenu(submenu, 'Label', 'Clear Baseline Offset', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearBaselineOffset());
            
            label = 'Filter';
            if ~isempty(obj.filterObj)
                try
                    if isa(obj.filterObj, 'digitalFilter')
                        label = sprintf("Filter (%s %s)", ...
                            obj.filterObj.FrequencyResponse, ...
                            obj.filterObj.ImpulseResponse);
                    end
                catch
                end
            end
            submenu = uimenu(menu, 'Label', label, ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Design Digital Filter', ...
                'Callback', @(varargin) obj.designDigitalFilter());
            uimenu(submenu, 'Label', 'Visualize Filter Response', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.visualizeFilterResponse());
            
            label = 'Resample';
            if obj.sumSamplesN > 1 && (obj.upsampleN > 1 || obj.downsampleN > 1)
                label = sprintf("Resample (+%d, %d/%d)", obj.sumSamplesN, obj.upsampleN, obj.downsampleN);
            elseif obj.sumSamplesN > 1
                label = sprintf("Resample (+%d)", obj.sumSamplesN);
            elseif obj.upsampleN > 1 || obj.downsampleN > 1
                label = sprintf("Resample (%d/%d)", obj.upsampleN, obj.downsampleN);
            end
            submenu = uimenu(menu, 'Label', label, ...
                'Separator', 'on');
            label = 'Sum Sample Blocks';
            if obj.sumSamplesN > 1
                label = sprintf("Sum Sample Blocks (+%d)", obj.sumSamplesN);
            end
            uimenu(submenu, 'Label', label, ...
                'Checked', obj.sumSamplesN > 1, ...
                'Callback', @(varargin) obj.setSumSamplesN());
            label = 'Resample';
            if obj.upsampleN > 1 || obj.downsampleN > 1
                label = sprintf("Resample (%d/%d)", obj.upsampleN, obj.downsampleN);
            end
            uimenu(submenu, 'Label', label, ...
                'Separator', 'on', ...
                'Checked', obj.upsampleN > 1 || obj.downsampleN > 1, ...
                'Callback', @(varargin) obj.setResampling());
            uimenu(submenu, 'Label', 'Clear All Resampling', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearAllResampling());
            
            submenu = uimenu(menu, 'Label', 'Display Options', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Set Multi-Line Offset', ...
                'Callback', @(varargin) obj.setTsLineOffsetDialog());
            uimenu(submenu, 'Label', 'Set Data Wrap Width', ...
                'Callback', @(varargin) obj.setTsWrapWidthDialog());
            uimenu(submenu, 'Label', 'Show Histogram', ...
                'Separator', 'on', ...
                'Checked', obj.isShowHist, ...
                'Callback', @(varargin) obj.toggleShowHist());
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
            if isempty(obj.visibleTsIndices)
                return
            end
            lines = obj.hTraceLine(obj.visibleTsIndices);
            ymin = arrayfun(@(line) nanmin(line.YData), lines);
            if isempty(ymin) || all(isnan(ymin))
                return
            end
            ymax = arrayfun(@(line) nanmax(line.YData), lines);
            ymin = min(ymin);
            ymax = max(ymax);
            xmin = arrayfun(@(line) nanmin(line.XData), lines);
            xmax = arrayfun(@(line) nanmax(line.XData), lines);
            xmin = min(xmin);
            xmax = max(xmax);
            dx = arrayfun(@(line) mean(diff(line.XData(~isnan(line.XData)))), lines);
            dx = nanmean(dx) / 2;
            dy = 0.1 * (ymax - ymin);
            try
                axis(obj.hTraceAxes, [xmin-dx xmax+dx ymin-dy ymax+dy]);
            catch
            end
        end
        function autoscaleX(obj)
            if isempty(obj.visibleTsIndices)
                return
            end
            lines = obj.hTraceLine(obj.visibleTsIndices);
            xmin = arrayfun(@(line) nanmin(line.XData), lines);
            if isempty(xmin) || all(isnan(xmin))
                return
            end
            xmax = arrayfun(@(line) nanmax(line.XData), lines);
            xmin = min(xmin);
            xmax = max(xmax);
            dx = arrayfun(@(line) mean(diff(line.XData(~isnan(line.XData)))), lines);
            dx = nanmean(dx) / 2;
            try
                obj.hTraceAxes.XLim = [xmin-dx xmax+dx];
            catch
            end
        end
        function autoscaleY(obj)
            if isempty(obj.visibleTsIndices)
                return
            end
            lines = obj.hTraceLine(obj.visibleTsIndices);
            ymin = arrayfun(@(line) nanmin(line.YData), lines);
            if isempty(ymin) || all(isnan(ymin))
                return
            end
            ymax = arrayfun(@(line) nanmax(line.YData), lines);
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
        
        function setSelection(obj, name)
            for t = obj.visibleTsIndices
                try
                    if obj.ts(t).selections.isKey(name)
                        szdata = size(obj.ts(t).raw.data);
                        idx = obj.ts(t).selections(name);
                        if islogical(idx)
                            sel = uint8(idx);
                        else
                            sel = zeros(szdata, 'uint8');
                            sel(idx) = 1;
                        end
                        if ~isinf(obj.tsWrapWidth)
                            x = obj.ts(t).time;
                            if x(end) - x(1) > obj.tsWrapWidth
                                % adjust sel to account for wrap
                                wrapNumPts = find(x - x(1) > obj.tsWrapWidth, 1) - 1;
                                sel = TimeSeriesExtViewer.insertSeparators(sel, wrapNumPts, uint8(0));
                            end
                        end
                        obj.hTraceLine(t).BrushData = reshape(sel, 1, []);
                    else
                        obj.hTraceLine(t).BrushData = [];
                    end
                catch
                end
            end
        end
        function nameCurrentSelection(obj, name)
            if ~exist('name', 'var') || isempty(name)
                answer = inputdlg({'Selection Name'}, 'Named Selection', 1, {''});
                if isempty(answer)
                    return
                end
                name = string(answer{1});
            end
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawData(t);
                    if isempty(sel)
                        continue
                    end
                    obj.ts(t).selections(name) = sel;
                catch
                end
            end
        end
        function removeSelection(obj, name)
            for t = obj.visibleTsIndices
                if obj.ts(t).selections.isKey(name)
                    obj.ts(t).selections.remove(name);
                end
            end
        end
        function selectAll(obj)
            for t = obj.visibleTsIndices
                try
                    obj.hTraceLine(t).BrushData = ones(size(obj.hTraceLine(t).YData), 'uint8');
                catch
                end
            end
        end
        
        function maskSelection(obj)
            for t = obj.visibleTsIndices
                try
                    if all(obj.ts(t).isMasked)
                        continue
                    end
                    sel = obj.getBrushData(t);
                    if isempty(sel)
                        continue
                    end
                    if ~isequal(size(obj.ts(t).isMasked), size(obj.ts(t).raw.data))
                        obj.ts(t).isMasked = obj.ts(t).mask;
                    end
                    obj.ts(t).isMasked(sel) = true;
                catch
                end
            end
            obj.updateUI();
        end
        function unmaskSelection(obj)
            for t = obj.visibleTsIndices
                try
                    if ~any(obj.ts(t).isMasked)
                        continue
                    end
                    sel = obj.getBrushData(t);
                    if isempty(sel)
                        continue
                    end
                    if ~isequal(size(obj.ts(t).isMasked), size(obj.ts(t).raw.data))
                        obj.ts(t).isMasked = obj.ts(t).mask;
                    end
                    obj.ts(t).isMasked(sel) = false;
                catch
                end
            end
            obj.updateUI();
        end
        function maskAll(obj)
            for t = obj.visibleTsIndices
                try
                    obj.ts(t).isMasked = true;
                catch
                end
            end
            obj.updateUI();
        end
        function clearMask(obj)
            for t = obj.visibleTsIndices
                try
                    obj.ts(t).isMasked = false;
                catch
                end
            end
            obj.updateUI();
        end
        
        function baselineFlat(obj)
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawData(t);
                    if isempty(sel)
                        continue
                    end
                    obj.ts(t).offset = -mean(obj.ts(t).raw.data(sel));
                catch
                end
            end
            obj.updateUI();
        end
        function baselineLinear(obj)
            obj.baselinePolynomial(1);
        end
        function baselinePolynomial(obj, order)
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawData(t);
                    if isempty(sel)
                        continue
                    end
                    x = obj.ts(t).time;
                    y = obj.ts(t).raw.data;
                    fit = polyfit(x(sel), y(sel), order);
                    obj.ts(t).offset = -polyval(fit, x);
                catch
                end
            end
            obj.updateUI();
        end
        function baselinePolynomialDialog(obj)
            dlg = dialog('Name', 'Baseline Polynomial');
            dlg.Position(3) = 300;
            dlg.Position(4) = 90;
            uicontrol(dlg, 'style', 'text', ...
                'String', 'Polynomial Order ', 'Position', [10 60 140 20], ...
                'HorizontalAlignment', 'right');
            orderEdit = uicontrol(dlg, 'style', 'edit', ...
                'String', '3', 'Position', [150 60 140 20]);
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Close', 'Position', [100 10 60 40], ...
                'Callback', 'delete(gcf)');
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Fit', 'Position', [160 10 60 40], ...
                'Callback', @(varargin) obj.baselinePolynomial(str2num(orderEdit.String)));
        end
        function baselineSpline(obj, numSegments)
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawData(t);
                    if isempty(sel)
                        continue
                    end
                    x = obj.ts(t).time;
                    y = obj.ts(t).raw.data;
                    pp = splinefit(x(sel), y(sel), numSegments);
                    obj.ts(t).offset = -ppval(pp, x);
                catch
                    msgbox("!!! Requires package 'splinefit'. See Add-On Explorer.", ...
                        'Baseline Spline');
                    return;
                end
            end
            obj.updateUI();
        end
        function baselineSplineDialog(obj)
            dlg = dialog('Name', 'Baseline Spline');
            dlg.Position(3) = 300;
            dlg.Position(4) = 90;
            uicontrol(dlg, 'style', 'text', ...
                'String', '# Spline Segments ', 'Position', [10 60 140 20], ...
                'HorizontalAlignment', 'right');
            numSegmentsEdit = uicontrol(dlg, 'style', 'edit', ...
                'String', '3', 'Position', [150 60 140 20]);
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Close', 'Position', [100 10 60 40], ...
                'Callback', 'delete(gcf)');
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Fit', 'Position', [160 10 60 40], ...
                'Callback', @(varargin) obj.baselineSpline(str2num(numSegmentsEdit.String)));
        end
        function baselineNonlinear(obj, expression, initialCoefficients)
            expression = strtrim(expression);
            if ~startsWith(expression, 'y~') && ~startsWith(expression, 'y ~')
                expression = "y ~ " + expression;
            end
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawData(t);
                    if isempty(sel)
                        continue
                    end
                    x = obj.ts(t).time;
                    y = obj.ts(t).raw.data;
                    mdl = fitnlm(x(sel), y(sel), expression, initialCoefficients);
                    obj.ts(t).offset = -predict(mdl, x);
                catch
                end
            end
            obj.updateUI();
        end
        function baselineNonlinearDialog(obj)
            dlg = dialog('Name', 'Baseline Nonlinear');
            dlg.Position(3) = 600;
            dlg.Position(4) = 110;
            uicontrol(dlg, 'style', 'text', ...
                'String', 'Expression y~fun(x,b1,b2,...) ', 'Position', [10 80 190 20], ...
                'HorizontalAlignment', 'right');
            expressionEdit = uicontrol(dlg, 'style', 'edit', ...
                'String', '', 'Position', [200 80 390 20]);
            uicontrol(dlg, 'style', 'text', ...
                'String', 'Starting Coefficients [b1 b2 ...] ', 'Position', [10 60 190 20], ...
                'HorizontalAlignment', 'right');
            coeffEdit = uicontrol(dlg, 'style', 'edit', ...
                'String', '', 'Position', [200 60 390 20]);
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Close', 'Position', [230 10 60 40], ...
                'Callback', 'delete(gcf)');
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Fit', 'Position', [310 10 60 40], ...
                'Callback', @(varargin) obj.baselineNonlinear( ...
                expressionEdit.String, str2num(coeffEdit.String)));
        end
        function clearBaselineOffset(obj)
            for t = obj.visibleTsIndices
                try
                    obj.ts(t).offset = 0;
                catch
                end
            end
            obj.updateUI();
        end
        
        function designDigitalFilter(obj)
            obj.filterObj = designfilt();
            obj.updateUI();
        end
        function visualizeFilterResponse(obj)
            if ~isempty(obj.filterObj)
                fvtool(obj.filterObj);
            end
        end
        
        function clearAllResampling(obj)
            obj.sumSamplesN = 1;
            obj.downsampleN = 1;
            obj.upsampleN = 1;
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
        function OLD_baselineFlat(obj)
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
        function OLD_baselineLinearTwoRegion(obj)
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
        
        function wdata = insertSeparators(data, N, sepValue)
            n = length(data);
            numSegments = ceil(double(n) / N);
            wn = n+(numSegments-1);
            wdata = zeros(wn,1,class(data));
            dati = true(wn,1);
            dati(N+1:N+1:end) = false;
            wdata(dati) = data;
            wdata(~dati) = sepValue;
        end
    end
end

