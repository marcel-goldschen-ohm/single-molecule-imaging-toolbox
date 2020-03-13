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
        
        hMainMenuBtn
        hTopText
        hAutoscaleXYBtn
        hAutoscaleYBtn
        hAutoscaleXBtn
        hPageLeftBtn
        hPageRightBtn
        hShowRawBtn
        hShowArtifactsBtn
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
        
        tmp = struct();
    end
    
    properties (Access = private)
        colors = lines();
        
        hBaselinePolyline
    end
    
    properties (Dependent)
        Parent % hPanel.Parent
        Position % hPanel.Position
        Visible % hPanel.Visible
        
        isShowRaw
        isShowArtifacts
        isShowMasked
        isShowZero
        isShowBaseline
        isShowIdeal
        isApplyFilter
        
        histNumBins
        isHistSqrtCounts
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
            
            obj.hPageLeftBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', '<<', 'Position', [0 0 20 20], ...
                'Tooltip', 'Page Left', ...
                'Callback', @(varargin) obj.pageLeft());
            obj.hPageRightBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', '>>', 'Position', [0 0 20 20], ...
                'Tooltip', 'Page Right', ...
                'Callback', @(varargin) obj.pageRight());
            
            obj.hShowRawBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', 'raw', 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Raw Data (Otherwise Show Baselined, Scaled, etc.)', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateShowRaw());
            obj.hShowArtifactsBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('22a5')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Artifacts', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hShowMaskedBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('2750')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Masked Data Points', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hShowZeroBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', '__', 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Zero Line', ...
                'Value', 0, ...
                'Callback', @(varargin) obj.updateUI(), ...
                'Visible', 'off');
            obj.hShowBaselineBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('2505')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Show Baseline', ...
                'Value', 1, ...
                'Callback', @(varargin) obj.updateUI());
            obj.hShowIdealBtn = uicontrol(obj.hPanel, 'style', 'togglebutton', ...
                'String', char(hex2dec('238d')), 'Position', [0 0 20 20], ...
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
            
            obj.hMainMenuBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', char(hex2dec('2630')), 'Position', [0 0 20 20], ...
                'Tooltip', 'Projection Menu', ...
                'Callback', @(varargin) obj.mainMenuBtnDown());

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
        
        function set.tsLineOffset(obj, yoffset)
            if isempty(yoffset)
                yoffset = 0;
            end
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
            obj.updateUI();
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
            tf = obj.hShowRawBtn.Value > 0;
        end
        function tf = get.isShowArtifacts(obj)
            tf = obj.hShowArtifactsBtn.Value > 0;
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
        function set.isShowRaw(obj, tf)
            try
                if isvalid(obj.hBaselinePolyline) ...
                        && class(obj.hBaselinePolyline) == "images.roi.Polyline"
                    if tf
                        % update polyline to track baseline offset
                        t = obj.visibleTsIndices(1);
                        y0 = -obj.ts(t).offset .* obj.ts(t).scale;
                        if numel(y0) == 1
                            obj.hBaselinePolyline.Position(:,2) = obj.hBaselinePolyline.Position(:,2) + y0;
                        else
                            x = obj.ts(t).time;
                            obj.hBaselinePolyline.Position(:,2) = obj.hBaselinePolyline.Position(:,2) ...
                                + interp1(x, y0, obj.hBaselinePolyline.Position(:,1));
                        end
                    else%if ~tf
                        % update polyline to track zeroed baseline
                        obj.hBaselinePolyline.Position(:,2) = 0;
                    end
                end
            catch
            end
            obj.hShowRawBtn.Value = tf;
            obj.updateUI();
        end
        function set.isShowArtifacts(obj, tf)
            obj.hShowArtifactsBtn.Value = tf;
            obj.updateUI();
        end
        function set.isShowMasked(obj, tf)
            obj.hShowMaskedBtn.Value = tf;
            obj.updateUI();
        end
        function set.isShowZero(obj, tf)
            obj.hShowZeroBtn.Value = tf;
            obj.updateUI();
        end
        function set.isShowBaseline(obj, tf)
            obj.hShowBaselineBtn.Value = tf;
            obj.updateUI();
        end
        function set.isShowIdeal(obj, tf)
            obj.hShowIdealBtn.Value = tf;
            obj.updateUI();
        end
        function set.isApplyFilter(obj, tf)
            obj.hApplyFilterBtn.Value = tf;
            obj.updateUI();
        end
        function toggleShowRaw(obj)
            obj.isShowRaw = ~obj.isShowRaw;
        end
        function toggleShowArtifacts(obj)
            obj.isShowArtifacts = ~obj.isShowArtifacts;
        end
        function toggleShowMasked(obj)
            obj.isShowMasked = ~obj.isShowMasked;
        end
        function toggleShowZero(obj)
            obj.isShowZero = ~obj.isShowZero;
        end
        function toggleShowBaseline(obj)
            obj.isShowBaseline = ~obj.isShowBaseline;
        end
        function toggleShowIdeal(obj)
            obj.isShowIdeal = ~obj.isShowIdeal;
        end
        function toggleApplyFilter(obj)
            obj.isApplyFilter = ~obj.isApplyFilter;
        end
        function updateShowRaw(obj)
            obj.isShowRaw = obj.hShowRawBtn.Value;
        end
        
        function nbins = get.histNumBins(obj)
            nbins = str2num(obj.hHistNumBinsEdit.String);
        end
        function set.histNumBins(obj, nbins)
            obj.hHistNumBinsEdit.String = num2str(nbins);
            obj.updateUI();
        end
        function setHistNumBins(obj, nbins)
            if ~exist('nbins', 'var')
                answer = inputdlg({'# Bins:'}, ...
                    'Histogram', 1, {num2str(obj.histNumBins)});
                if isempty(answer)
                    return
                end
                nbins = str2num(answer{1});
            end
            obj.histNumBins = nbins;
        end
        function tf = get.isHistSqrtCounts(obj)
            tf = obj.hHistSqrtCountsBtn.Value > 0;
        end
        function set.isHistSqrtCounts(obj, tf)
            obj.hHistSqrtCountsBtn.Value = tf;
            obj.updateUI();
        end
        function toggleHistSqrtCounts(obj)
            obj.isHistSqrtCounts = ~obj.isHistSqrtCounts;
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
            pos = TimeSeriesExtViewer.plotboxpos(obj.hTraceAxes);
            x = pos(1); y = pos(2); w = pos(3); h = pos(4);
            
            % menu button
            bx = margin;
            by = y + h + margin;
            obj.hMainMenuBtn.Position = [bx by lineh lineh];
            % autoscale buttons
            bx = x + w - 3*lineh;
            obj.hAutoscaleXBtn.Position = [bx by lineh lineh];
            obj.hAutoscaleYBtn.Position = [bx+lineh by lineh lineh];
            obj.hAutoscaleXYBtn.Position = [bx+2*lineh by lineh lineh];
            % page buttons
            bx = bx - 5 - 2*lineh;
            obj.hPageLeftBtn.Position = [bx by lineh lineh];
            obj.hPageRightBtn.Position = [bx+lineh by lineh lineh];
            % toggle buttons
            bx = bx - 5 - 6*lineh;
            obj.hShowRawBtn.Position = [bx by lineh lineh];
            obj.hShowArtifactsBtn.Position = [bx+lineh by lineh lineh];
            obj.hShowMaskedBtn.Position = [bx+2*lineh by lineh lineh];
            obj.hApplyFilterBtn.Position = [bx+3*lineh by lineh lineh];
            obj.hShowIdealBtn.Position = [bx+4*lineh by lineh lineh];
            obj.hShowBaselineBtn.Position = [bx+5*lineh by lineh lineh];
%             obj.hShowZeroBtn.Position = [bx+5*lineh by lineh lineh];
            % ts nav buttons
            if isvalid(obj.hVisibleTsEdit) && obj.hVisibleTsEdit.Visible == "on"
                bx = bx - 5 - 4*lineh;
                obj.hPrevTsBtn.Position = [bx by lineh lineh];
                obj.hVisibleTsEdit.Position = [bx+lineh by 2*lineh lineh];
                obj.hNextTsBtn.Position = [bx+3*lineh by lineh lineh];
            end
            % text above plot
            if obj.hTopText.Visible == "on"
                obj.hTopText.Position = [x+35 by bx-5-(x+35) lineh];
            end
            % histogram
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
        
        function updateUI(obj)
            % make sure we have plot objects for each time series and get
            % rid of any extra
            obj.addOrRemovePlotObjectsToMatchTimeSeries();
            
            % default text in histogram is off, we'll turn it on as needed
            obj.hHistUpperRightText.Visible = 'off';
            obj.hHistUpperRightText.String = '';
            
            colorIndex = 1;
            y0 = 0; % offset between multiple or wrapped time series
            
            numTs = numel(obj.ts);
            for t = 1:numTs
                % get the time series data to display
                try
                    if find(obj.visibleTsIndices == t, 1)
                        [x, y] = obj.getTsAsShown(t);
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
                if y0
                    % offset time series data (for multiple or wrapped
                    % traces)
                    y = y + y0;
                end
                
                % wrapped segments? {} => no wrapping
                wrapSegIdx = obj.getWrapSegmentIndices(x);
                
                obj.updateZeroLine(t, x, y0, wrapSegIdx);
                
                obj.updateTraceLine(t, x, y, wrapSegIdx);
                if obj.tsLineOffset == 0
                    % unique colors for overlaid traces
                    obj.hTraceLine(t).Color = obj.colors(colorIndex,:);
                    colorIndex = colorIndex + 1;
                else
                    % same color for offset traces
                    obj.hTraceLine(t).Color = obj.colors(1,:);
                end
                
                obj.updateBaseLine(t, x, y0, wrapSegIdx);
                
                obj.updateIdealLine(t, x, y, y0, wrapSegIdx);
                if obj.tsLineOffset == 0
                    % unique colors for overlaid traces
                    obj.hTraceIdealLine(t).Color = obj.colors(colorIndex,:);
                    colorIndex = colorIndex + 1;
                else
                    % same color for offset traces
                    obj.hTraceIdealLine(t).Color = obj.colors(2,:);
                end
                
                obj.updateHistogram(t);
                
                % increment offset for next time series
                if obj.tsLineOffset ~= 0
                    if isempty(wrapSegIdx)
                        y0 = y0 + obj.tsLineOffset;
                    else
                        numSegs = numel(wrapSegIdx);
                        y0 = y0 + numSegs * obj.tsLineOffset;
                    end
                end
            end
        end
        function addOrRemovePlotObjectsToMatchTimeSeries(obj)
            numTs = numel(obj.ts);
            % always keep at least one set of graphics objects
            numGraphics = max(1, numTs);
            % delete unneeded graphics objects
            if numel(obj.hTraceLine) > numGraphics
                delete(obj.hTraceLine(numGraphics+1:end));
                delete(obj.hTraceIdealLine(numGraphics+1:end));
                delete(obj.hHistBar(numGraphics+1:end));
                delete(obj.hHistIdealLines(numGraphics+1:end));
            end
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
            end
            if numGraphics > numTs
                obj.hTraceZeroLine(numGraphics).Visible = 'off';
                obj.hTraceLine(numGraphics).Visible = 'off';
                obj.hTraceBaseLine(numGraphics).Visible = 'off';
                obj.hTraceIdealLine(numGraphics).Visible = 'off';
                obj.hHistBar(numGraphics).Visible = 'off';
                obj.hHistIdealLines(numGraphics).Visible = 'off';
            end
        end
        function wrapSegIdx = getWrapSegmentIndices(obj, x)
            wrapSegIdx = {};
            if isinf(obj.tsWrapWidth) || x(end) - x(1) <= obj.tsWrapWidth
                return
            end
            i = 1;
            nx = size(x,1);
            while i <= nx
                j = find(x - x(i) > obj.tsWrapWidth, 1) - 1;
                if j
                    wrapSegIdx{end+1} = i:j;
                    i = j + 1;
                else
                    wrapSegIdx{end+1} = i:nx;
                    return
                end
            end
        end
        function [wx, wy] = getWrappedData(obj, x, y, wrapSegIdx)
            if ~exist('wrapSegIdx', 'var')
                wrapSegIdx = obj.getWrapSegmentIndices(x);
            end
            numPts = size(y,1);
            numSegs = numel(wrapSegIdx);
            wx = nan(numPts + numSegs - 1, 1);
            wy = wx;
            for k = 1:numSegs
                idx = wrapSegIdx{k};
                wx(idx+(k-1)) = x(idx) - x(idx(1));
                wy(idx+(k-1)) = y(idx) + (k-1) * obj.tsLineOffset;
            end
        end
        function updateZeroLine(obj, t, x, y0, wrapSegIdx)
            if ~obj.isShowZero
                obj.hTraceZeroLine(t).Visible = 'off';
                obj.hTraceZeroLine(t).XData = nan;
                obj.hTraceZeroLine(t).YData = nan;
                return
            end
            
            if isempty(wrapSegIdx)
                obj.hTraceZeroLine(t).XData = [x(1); x(end)];
                obj.hTraceZeroLine(t).YData = [y0; y0];
            else
                numSegs = numel(wrapSegIdx);
                obj.hTraceZeroLine(t).XData = repmat([0; obj.tsWrapWidth; nan], numSegs, 1);
                obj.hTraceZeroLine(t).YData = reshape( ...
                    repmat([y0; y0; nan], 1, numSegs) ...
                    + repmat([obj.tsLineOffset; obj.tsLineOffset; nan], 1, numSegs) ...
                    .* repmat(0:numSegs-1, 3, 1), ...
                    [], 1);
            end
            
            obj.hTraceZeroLine(t).Visible = 'on';
        end
        function updateTraceLine(obj, t, x, y, wrapSegIdx)
            if isempty(wrapSegIdx)
                obj.hTraceLine(t).XData = x;
                obj.hTraceLine(t).YData = y;
            else
                [wx, wy] = obj.getWrappedData(x, y, wrapSegIdx);
                obj.hTraceLine(t).XData = wx;
                obj.hTraceLine(t).YData = wy;
            end
            obj.hTraceLine(t).Visible = 'on';
        end
        function updateBaseLine(obj, t, x, y0, wrapSegIdx)
            if ~obj.isShowBaseline
                obj.hTraceBaseLine(t).Visible = 'off';
                obj.hTraceBaseLine(t).XData = nan;
                obj.hTraceBaseLine(t).YData = nan;
                return
            end
            
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
                baseline = zeros(size(x)) - offset + y0;
            else
                % baselined data will have a baseline at zero (or
                % offset if we are offseting this time series)
                baseline = zeros(size(x)) + y0;
            end
            
            if isempty(wrapSegIdx)
                obj.hTraceBaseLine(t).XData = x;
                obj.hTraceBaseLine(t).YData = baseline;
            else
                [wx, wbaseline] = obj.getWrappedData(x, baseline, wrapSegIdx);
                obj.hTraceBaseLine(t).XData = wx;
                obj.hTraceBaseLine(t).YData = wbaseline;
            end
            
            obj.hTraceBaseLine(t).Visible = 'on';
        end
        function updateIdealLine(obj, t, x, y, y0, wrapSegIdx)
            if ~obj.isShowIdeal
                obj.hTraceIdealLine(t).Visible = 'off';
                obj.hTraceIdealLine(t).XData = nan;
                obj.hTraceIdealLine(t).YData = nan;
                return
            end
            
            try
                idealx = obj.ts(t).ideal.time;
                idealy = obj.ts(t).ideal.data;
                %[~, ideal] = obj.getResampledTs(zeros(size(ideal)), ideal);
                idealy = idealy + y0;
            catch
                idealx = [];
                idealy = [];
            end
            
            if isempty(idealy)%~isequal(size(y), size(ideal))
                obj.hTraceIdealLine(t).Visible = 'off';
                obj.hTraceIdealLine(t).XData = nan;
                obj.hTraceIdealLine(t).YData = nan;
                return
            end
            
            if isempty(wrapSegIdx)
                obj.hTraceIdealLine(t).XData = idealx;
                obj.hTraceIdealLine(t).YData = idealy;
            else
                [widealx, widealy] = obj.getWrappedData(idealx, idealy, wrapSegIdx);
                obj.hTraceIdealLine(t).XData = widealx;
                obj.hTraceIdealLine(t).YData = widealy;
            end
            
            obj.hTraceIdealLine(t).Visible = 'on';
        end
        function updateHistogram(obj, t)
            if ~obj.isShowHist
                return
            end
            
            nbins = str2num(obj.hHistNumBinsEdit.String);
            y = obj.hTraceLine(t).YData;
            ynn = y(~isnan(y));
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
            obj.hHistBar(t).XData = centers;
            obj.hHistBar(t).YData = counts;
            obj.hHistBar(t).FaceColor = obj.hTraceLine(t).Color;
            obj.hHistBar(t).Visible = 'on';
            
            ideal = obj.hTraceIdealLine(t).YData;
            if ~isequal(size(y), size(ideal))
                obj.hHistIdealLines(t).Visible = 'off';
                obj.hHistIdealLines(t).XData = nan;
                obj.hHistIdealLines(t).YData = nan;
                return
            end
            
            % plot a GMM fit to data overlaid on the histogram
            % based on levels in ideal trace
            if numel(centers) < 100
                bins = reshape(linspace(edges(1), edges(end), 101), [] ,1);
            else
                bins = reshape(centers, [], 1);
            end
            idealnn = ideal(~isnan(ideal));
            ustates = unique(idealnn);
            nustates = numel(ustates);
            fits = zeros(numel(bins), nustates);
            npts = numel(idealnn);
            for k = 1:nustates
                idx = ideal == ustates(k);
                yk = y(idx);
                [mu, sigma] = normfit(yk(~isnan(yk)));
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
        end
        function [x, y] = getTsAsShown(obj, t)
            x = obj.ts(t).time;
            if obj.isShowRaw
                y = obj.ts(t).raw.data;
            elseif obj.isShowArtifacts
                y = (obj.ts(t).raw.data + obj.ts(t).offset) .* obj.ts(t).scale;
            else
                y = obj.ts(t).data;
            end
            % filter
            if obj.isApplyFilter && ~isempty(obj.filterObj)
                if isa(obj.filterObj, 'digitalFilter')
                    y = filtfilt(obj.filterObj, y);
                else
                    y = filtfilt(obj.filterObj, 1, y);
                end
            end
            % mask
            if ~obj.isShowMasked && any(obj.ts(t).isMasked)
                y(obj.ts(t).mask) = nan;
            end
            % resample
            [x, y] = obj.getResampledTs(x, y);
        end
        function [x, y] = getResampledTs(obj, x, y)
            % sum sample blocks
            if obj.sumSamplesN > 1
                N = obj.sumSamplesN;
                n = floor(double(length(y)) / N);
                x = x(1:N:n*N);
                y0 = y;
                y = y0(1:N:n*N,:);
                for k = 2:N
                    y = y + y0(k:N:n*N,:);
                end
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
        function [x, tf] = getResampledLogicals(obj, x, tf)
            % sum sample blocks
            if obj.sumSamplesN > 1
                N = obj.sumSamplesN;
                n = floor(double(length(tf)) / N);
                x = x(1:N:n*N);
                tf = any(reshape(tf(1:n*N), N, []), 1);
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
                    tf = reshape(repmat(reshape(tf, 1, []), N, 1), 1, []);
                    tf = tf(1:end-(N-1));
                end
                if obj.downsampleN > 1
                    N = obj.downsampleN;
                    x = downsample(x, N);
                    pad = mod(length(tf), N);
                    if pad > 0
                        tf(end+1:end+(N-pad)) = false;
                    end
                    tf = any(reshape(tf, N, []), 1);
                end
            end
        end
        function sel = getBrushedSelectionForRawTs(obj, t)
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
        
        function mainMenuBtnDown(obj)
            %MENUBUTTONPRESSED Handle menu button press.
            hMainMenu = obj.getMainMenu();
            hFig = ancestor(obj.hPanel, 'Figure');
            hMainMenu.Parent = hFig;
            pos = Utilities.getPixelPositionInAncestor(obj.hMainMenuBtn, hFig);
            hMainMenu.Position(1:2) = pos(1:2);
            hMainMenu.Visible = 1;
        end
        function menu = getMainMenu(obj)
            %GETACTIONSMENU Return menu with channel image actions.
            menu = uicontextmenu;
            
            % file -------------
            submenu = uimenu(menu, 'Label', 'File');
            uimenu(submenu, 'Label', 'Load Data', ...
                'Callback', @(varargin) obj.loadData());
            uimenu(submenu, 'Label', 'Import HEKA Data', ...
                'Callback', @(varargin) obj.importHEKA());
            uimenu(submenu, 'Label', 'Save Data', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.saveData());
            uimenu(submenu, 'Label', 'Clear Data', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearData());
            
            % selections -------------
            submenu = uimenu(menu, 'Label', 'Select', ...
                'Separator', 'on');
            keys = string.empty;
            for ts = obj.ts
                keys = [keys string(ts.selections.keys)];
            end
            if ~isempty(keys)
                subsubmenu = uimenu(submenu, 'Label', 'Named Selections');
                for key = unique(keys)
                    uimenu(subsubmenu, 'Label', key, ...
                        'Callback', @(varargin) obj.setSelection(key));
                end
            end
            uimenu(submenu, 'Label', 'Name Current Selection', ...
                'Callback', @(varargin) obj.nameCurrentSelection());
            if ~isempty(keys)
                subsubmenu = uimenu(submenu, 'Label', 'Remove Selection', ...
                    'Separator', 'on');
                for key = unique(keys)
                    uimenu(subsubmenu, 'Label', key, ...
                        'Callback', @(varargin) obj.removeSelection(key));
                end
            end
            uimenu(submenu, 'Label', 'Select All', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.selectAll());
            uimenu(submenu, 'Label', 'Select None', ...
                'Callback', @(varargin) obj.selectNone());
            uimenu(submenu, 'Label', 'Select Ideal State', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.selectIdealState());
            
            % mask -------------
            submenu = uimenu(menu, 'Label', 'Mask', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Mask Selection', ...
                'Callback', @(varargin) obj.maskSelection());
            uimenu(submenu, 'Label', 'Unmask Selection', ...
                'Callback', @(varargin) obj.unmaskSelection());
            uimenu(submenu, 'Label', 'Mask All', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.maskAll());
            uimenu(submenu, 'Label', 'Unmask All', ...
                'Callback', @(varargin) obj.unmaskAll());
            
            % baseline -------------
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
            uimenu(submenu, 'Label', 'Draw Baseline Nodes', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.drawBaselineNodes());
            uimenu(submenu, 'Label', 'Edit Baseline Nodes', ...
                'Callback', @(varargin) obj.editBaselineNodes());
            uimenu(submenu, 'Label', 'Baseline Sliding Gaussian', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.baselineSlidingGaussian());
            uimenu(submenu, 'Label', 'Baseline Sliding Lognormal Peak', ...
                'Callback', @(varargin) obj.baselineSlidingLognormalPeak());
            uimenu(submenu, 'Label', 'Clear Baseline Offset', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearBaselineOffset());
            
            % filter -------------
            label = 'Filter (None)';
            if ~isempty(obj.filterObj)
                try
                    if isa(obj.filterObj, 'digitalFilter')
                        label = sprintf("Filter (%s %s)", ...
                            obj.filterObj.FrequencyResponse, ...
                            obj.filterObj.ImpulseResponse);
                    else
                        label = sprintf("Filter (Gaussian %d pts)", ...
                            length(obj.filterObj));
                    end
                catch
                end
            end
            submenu = uimenu(menu, 'Label', label, ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Gaussian Filter', ...
                'Callback', @(varargin) obj.setGaussianFilter());
            uimenu(submenu, 'Label', 'Design Digital Filter', ...
                'Callback', @(varargin) obj.designDigitalFilter());
            uimenu(submenu, 'Label', 'Visualize Filter Response', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.visualizeFilterResponse());
            uimenu(submenu, 'Label', 'Clear Filter', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearFilter());
            
            % resample -------------
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
            
            % model -------------
            submenu = uimenu(menu, 'Label', 'Model', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Threshold Idealization', ...
                'Callback', @(varargin) obj.thresholdIdealization());
            uimenu(submenu, 'Label', 'kmeans Idealization', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.kmeansIdealization());
            uimenu(submenu, 'Label', 'DISC Idealization', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.idealizeWithDISC());
            
            % simulation -------------
            submenu = uimenu(menu, 'Label', 'Simulation', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Simulate HMM', ...
                'Callback', @(varargin) obj.appendSimulatedHMM());
            
            % artifacts -------------
            submenu = uimenu(menu, 'Label', 'Artifacts', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Subtract Capacitive Artifacts', ...
                'Callback', @(varargin) obj.subtractCapacitiveArtifacts());
            
            % display -------------
            submenu = uimenu(menu, 'Label', 'Display Options', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Show Raw Data', ...
                'Checked', obj.isShowRaw, ...
                'Callback', @(varargin) obj.toggleShowRaw());
            uimenu(submenu, 'Label', 'Show Artifacts', ...
                'Checked', obj.isShowArtifacts, ...
                'Callback', @(varargin) obj.toggleShowArtifacts());
            uimenu(submenu, 'Label', [char(hex2dec('2750')) ': Show Masked'], ...
                'Checked', obj.isShowMasked, ...
                'Callback', @(varargin) obj.toggleShowMasked());
            uimenu(submenu, 'Label', [char(hex2dec('2a0d')) ': Apply Filter'], ...
                'Checked', obj.isApplyFilter, ...
                'Callback', @(varargin) obj.toggleApplyFilter());
            uimenu(submenu, 'Label', [char(hex2dec('238d')) ': Show Ideal'], ...
                'Checked', obj.isShowIdeal, ...
                'Callback', @(varargin) obj.toggleShowIdeal());
            uimenu(submenu, 'Label', [char(hex2dec('2505')) ': Show Baseline'], ...
                'Checked', obj.isShowBaseline, ...
                'Callback', @(varargin) obj.toggleShowBaseline());
            uimenu(submenu, 'Label', '__: Show Zero Line', ...
                'Checked', obj.isShowZero, ...
                'Callback', @(varargin) obj.toggleShowZero());
            uimenu(submenu, 'Label', ['Set X Axis Limits [' num2str(obj.hTraceAxes.XLim) ']'], ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.setXLim());
            uimenu(submenu, 'Label', ['Set Y Axis Limits [' num2str(obj.hTraceAxes.YLim) ']'], ...
                'Callback', @(varargin) obj.setYLim());
            uimenu(submenu, 'Label', 'Set Multi-Line Offset', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.setTsLineOffsetDialog());
            uimenu(submenu, 'Label', 'Set Data Wrap Width', ...
                'Callback', @(varargin) obj.setTsWrapWidthDialog());
            uimenu(submenu, 'Label', 'Show Histogram', ...
                'Separator', 'on', ...
                'Checked', obj.isShowHist, ...
                'Callback', @(varargin) obj.toggleShowHist());
            uimenu(submenu, 'Label', ['Set Histogram #Bins (' num2str(obj.histNumBins) ')'], ...
                'Callback', @(varargin) obj.setHistNumBins());
            uimenu(submenu, 'Label', ['Histogram ' char(hex2dec('221a')) 'freq'], ...
                'Checked', obj.isHistSqrtCounts, ...
                'Callback', @(varargin) obj.toggleHistSqrtCounts());
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
        
        function pageLeft(obj)
            obj.hTraceAxes.XLim = obj.hTraceAxes.XLim ...
                - 0.9 * diff(obj.hTraceAxes.XLim);
        end
        function pageRight(obj)
            obj.hTraceAxes.XLim = obj.hTraceAxes.XLim ...
                + 0.9 * diff(obj.hTraceAxes.XLim);
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
                        % resample
                        x = obj.ts(t).time;
                        [x, sel] = obj.getResampledLogicals(x, sel);
                        sel = uint8(sel);
                        % wrap
                        if ~isinf(obj.tsWrapWidth)
                            if x(end) - x(1) > obj.tsWrapWidth
                                wrapNumPts = find(x - x(1) > obj.tsWrapWidth, 1) - 1;
                                sel = TimeSeriesExtViewer.insertSeparators(sel, wrapNumPts, uint8(0));
                            end
                        end
                        try
                            currentSel = obj.hTraceLine(t).BrushData;
                            obj.hTraceLine(t).BrushData = uint8(any([currentSel; reshape(sel, 1, [])], 1));
                        catch
                            obj.hTraceLine(t).BrushData = reshape(sel, 1, []);
                        end
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
                    sel = obj.getBrushedSelectionForRawTs(t);
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
        function selectNone(obj)
            for t = obj.visibleTsIndices
                try
                    obj.hTraceLine(t).BrushData = [];
                catch
                end
            end
        end
        function selectIdealState(obj, k)
            if ~exist('k', 'var')
                answer = inputdlg({'Ideal State Index:'}, ...
                    'Select State', 1, {'1'});
                if isempty(answer)
                    return
                end
                k = str2num(answer{1});
            end
            for t = obj.visibleTsIndices
                try
                    ideal = obj.ts(t).ideal.data;
                    states = unique(ideal);
                    idx = find(ideal == states(k));
                    if ~isequal(size(obj.hTraceLine(t).BrushData), size(obj.hTraceLine(t).YData))
                        obj.hTraceLine(t).BrushData = zeros(size(obj.hTraceLine(t).YData), 'uint8');
                    end
                    obj.hTraceLine(t).BrushData(idx) = 1;
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
                    sel = obj.getBrushedSelectionForRawTs(t);
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
                    sel = obj.getBrushedSelectionForRawTs(t);
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
        function unmaskAll(obj)
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
                    sel = obj.getBrushedSelectionForRawTs(t);
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
                    sel = obj.getBrushedSelectionForRawTs(t);
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
                'String', 'Cancel', 'Position', [100 10 60 40], ...
                'Callback', @(varargin) cancel_());
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Fit', 'Position', [160 10 60 40], ...
                'Callback', @(varargin) obj.baselinePolynomial(str2num(orderEdit.String)));
            dlg.UserData.offsets = {};
            for t = obj.visibleTsIndices
                dlg.UserData.offsets{t} = obj.ts(t).offset;
            end
            function cancel_()
                for t = obj.visibleTsIndices
                    obj.ts(t).offset = dlg.UserData.offsets{t};
                end
                delete(dlg);
                obj.updateUI();
            end
        end
        function baselineSpline(obj, numSegments)
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawTs(t);
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
                'String', 'Cancel', 'Position', [100 10 60 40], ...
                'Callback', @(varargin) cancel_());
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Fit', 'Position', [160 10 60 40], ...
                'Callback', @(varargin) obj.baselineSpline(str2num(numSegmentsEdit.String)));
            dlg.UserData.offsets = {};
            for t = obj.visibleTsIndices
                dlg.UserData.offsets{t} = obj.ts(t).offset;
            end
            function cancel_()
                for t = obj.visibleTsIndices
                    obj.ts(t).offset = dlg.UserData.offsets{t};
                end
                delete(dlg);
                obj.updateUI();
            end
        end
        function baselineNonlinear(obj, expression, initialCoefficients)
            expression = strtrim(expression);
            if ~startsWith(expression, 'y~') && ~startsWith(expression, 'y ~')
                expression = "y ~ " + expression;
            end
            for t = obj.visibleTsIndices
                try
                    sel = obj.getBrushedSelectionForRawTs(t);
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
                'String', 'y~b1*x+b2', 'Position', [200 80 390 20]);
            uicontrol(dlg, 'style', 'text', ...
                'String', 'Starting Coefficients [b1 b2 ...] ', 'Position', [10 60 190 20], ...
                'HorizontalAlignment', 'right');
            coeffEdit = uicontrol(dlg, 'style', 'edit', ...
                'String', '1 0', 'Position', [200 60 390 20]);
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [230 10 60 40], ...
                'Callback', @(varargin) cancel_());
            uicontrol(dlg, 'style', 'pushbutton', ...
                'String', 'Fit', 'Position', [310 10 60 40], ...
                'Callback', @(varargin) obj.baselineNonlinear( ...
                expressionEdit.String, str2num(coeffEdit.String)));
            dlg.UserData.offsets = {};
            for t = obj.visibleTsIndices
                dlg.UserData.offsets{t} = obj.ts(t).offset;
            end
            function cancel_()
                for t = obj.visibleTsIndices
                    obj.ts(t).offset = dlg.UserData.offsets{t};
                end
                delete(dlg);
                obj.updateUI();
            end
        end
        function drawBaselineNodes(obj)
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels');
            x = 2;
            y = obj.hMainMenuBtn.Position(2);
            w = 180;
            h = obj.hMainMenuBtn.Position(4);
            hDialogPanel.Position = [x y w h];
            
            uicontrol(hDialogPanel, 'style', 'text', ...
                'String', 'Baseline Nodes', 'Position', [0 0 100 h], ...
                'BackgroundColor', [0 0 0], ...
                'ForegroundColor', [1 1 1]);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [100 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', @cancel_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [140 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            
            t = obj.visibleTsIndices(1);
            originalOffset = obj.ts(t).offset;
            
            obj.hBaselinePolyline = drawpolyline(obj.hTraceAxes);
            roiEvent_();
            listeners(1) = addlistener(obj.hBaselinePolyline, 'ROIMoved', @roiEvent_);
            
            function roiEvent_(varargin)
                try
                    t = obj.visibleTsIndices(1);
                    ptsx = obj.hBaselinePolyline.Position(:,1);
                    ptsy = obj.hBaselinePolyline.Position(:,2);
                    baseline = interp1(ptsx, ptsy, obj.ts(t).time, 'makima');
                    if obj.isShowRaw
                        obj.ts(t).offset = -baseline;
                    else
                        obj.ts(t).offset = obj.ts(t).offset - baseline ./ obj.ts(t).scale;
                        obj.hBaselinePolyline.Position(:,2) = 0;
                        obj.updateUI();
                    end
                catch e
                    e.message
                end
            end
            function ok_(varargin)
                uiresume();
            end
            function cancel_(varargin)
                t = obj.visibleTsIndices(1);
                obj.ts(t).offset = originalOffset;
                obj.updateUI();
                uiresume();
            end
            
            uiwait();
            delete(listeners);
            delete(hDialogPanel);
            delete(obj.hBaselinePolyline);
            obj.updateUI();
        end
        function editBaselineNodes(obj, numNodesOrNodesXY)
            if ~exist('numNodesOrNodesXY', 'var')
                answer = inputdlg({'# Nodes:'}, ...
                    'Baseline Nodes', 1, {'100'});
                if isempty(answer)
                    return
                end
                numNodesOrNodesXY = str2num(answer{1});
            end
            
            t = obj.visibleTsIndices(1);
            if numel(numNodesOrNodesXY) == 1
                % number of nodes
                numNodes = numNodesOrNodesXY;
                time = obj.ts(t).time;
                nodex = reshape(linspace(time(1), time(end), numNodes), [], 1);
                nodey = zeros(size(nodex));
                if obj.isShowRaw
                    if numel(obj.ts(t).offset) == 1
                        nodey = nodey - obj.ts(t).offset;
                    else
                        nodey = interp1(obj.ts(t).time, -obj.ts(t).offset, nodex);
                    end
                end
                nodesXY = [nodex nodey];
            elseif size(numNodesOrNodesXY,2) == 2
                % node [x y] positions
                nodesXY = numNodesOrNodesXY;
            else
                return
            end
            
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels');
            x = 2;
            y = obj.hMainMenuBtn.Position(2);
            w = 180;
            h = obj.hMainMenuBtn.Position(4);
            hDialogPanel.Position = [x y w h];
            
            uicontrol(hDialogPanel, 'style', 'text', ...
                'String', 'Baseline Nodes', 'Position', [0 0 100 h], ...
                ... %'HorizontalAlignment', 'right', ...
                'BackgroundColor', [0 0 0], ...
                'ForegroundColor', [1 1 1]);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [100 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', @cancel_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [140 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            
            t = obj.visibleTsIndices(1);
            originalOffset = obj.ts(t).offset;
            
            obj.hBaselinePolyline = images.roi.Polyline(obj.hTraceAxes, 'Position', nodesXY);
            roiEvent_();
            listeners(1) = addlistener(obj.hBaselinePolyline, 'ROIMoved', @roiEvent_);
            
            function roiEvent_(varargin)
                try
                    ptsx = obj.hBaselinePolyline.Position(:,1);
                    ptsy = obj.hBaselinePolyline.Position(:,2);
                    t = obj.visibleTsIndices(1);
                    baseline = interp1(ptsx, ptsy, obj.ts(t).time, 'makima');
                    if obj.isShowRaw
                        obj.ts(t).offset = -baseline;
                    else
                        obj.ts(t).offset = obj.ts(t).offset - baseline ./ obj.ts(t).scale;
                        obj.hBaselinePolyline.Position(:,2) = 0;
                        obj.updateUI();
                    end
                catch err
                    disp(err);
                    uiresume();
                end
            end
            function ok_(varargin)
                uiresume();
            end
            function cancel_(varargin)
                t = obj.visibleTsIndices(1);
                obj.ts(t).offset = originalOffset;
                obj.updateUI();
                uiresume();
            end
            
            uiwait();
            delete(listeners);
            delete(hDialogPanel);
            delete(obj.hBaselinePolyline);
            obj.updateUI();
        end
        function baselineSlidingGaussian(obj, windowPts, stepPts)
            if ~exist('windowPts', 'var') || ~exist('stepPts', 'var')
                answer = inputdlg({'Window (pts):', 'Step (pts):'}, ...
                    'Baseline Gaussian Sliding Window', 1, {'1000', '100'});
                if isempty(answer)
                    return
                end
                windowPts = str2num(answer{1});
                stepPts = str2num(answer{2});
            end
            for t = obj.visibleTsIndices
                try
                    sel = logical(obj.hTraceLine(t).BrushData);
                    if isempty(sel) || ~any(sel)
                        continue
                    end
                    x = obj.hTraceLine(t).XData(sel);
                    y = obj.hTraceLine(t).YData(sel);
                    ny = length(y);
                    n = ceil(double(ny-windowPts) / stepPts) + 1;
                    nodesXY = zeros(n, 2);
                    for i = 1:n
                        a = 1 + (i-1) * stepPts;
                        b = min(a + windowPts - 1, ny);
                        idx = a:b;
                        wx = x(idx);
                        wy = y(idx);
                        [mu, sigma] = normfit(wy);
                        nodesXY(i,:) = [mean(wx) mu];
                    end
                    nodesXY = [x(1) nodesXY(1,2); nodesXY; x(end) nodesXY(end,2)];
                    obj.editBaselineNodes(nodesXY);
                    return
                catch err
                    disp(err);
                end
            end
            obj.updateUI();
        end
        function baselineSlidingLognormalPeak(obj, windowPts, stepPts)
            if ~exist('windowPts', 'var') || ~exist('stepPts', 'var')
                answer = inputdlg({'Window (pts):', 'Step (pts):'}, ...
                    'Baseline Lognormal Sliding Window', 1, {'1000', '100'});
                if isempty(answer)
                    return
                end
                windowPts = str2num(answer{1});
                stepPts = str2num(answer{2});
            end
            for t = obj.visibleTsIndices
                try
                    sel = logical(obj.hTraceLine(t).BrushData);
                    if isempty(sel) || ~any(sel)
                        continue
                    end
                    x = obj.hTraceLine(t).XData(sel);
                    y = obj.hTraceLine(t).YData(sel);
                    ny = length(y);
                    n = ceil(double(ny-windowPts) / stepPts) + 1;
                    nodesXY = zeros(n, 2);
                    for i = 1:n
                        a = 1 + (i-1) * stepPts;
                        b = min(a + windowPts - 1, ny);
                        idx = a:b;
                        wx = x(idx);
                        wy = y(idx);
                        shift = min(wy) - min(abs(diff(wy)));
                        [phat, pci] = lognfit(wy - shift);
                        mu = phat(1);
                        sigma = phat(2);
                        mode = exp(mu - sigma^2);
                        nodesXY(i,:) = [mean(wx) mode+shift];
                    end
                    nodesXY = [x(1) nodesXY(1,2); nodesXY; x(end) nodesXY(end,2)];
                    obj.editBaselineNodes(nodesXY);
                    return
                catch err
                    disp(err);
                end
            end
            obj.updateUI();
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
        
        function setGaussianFilter(obj, ratioOfCutoffToSampleFrequency)
            if ~exist('ratioOfCutoffToSampleFrequency', 'var')
                answer = inputdlg({'Cutoff / Sample Frequency Ratio:'}, ...
                    'Gaussian Filter', 1, {''});
                if isempty(answer) || isempty(answer{1})
                    return
                end
                ratioOfCutoffToSampleFrequency = str2num(answer{1});
            end
            % sigma = standard deviation of impulse response in time domain
            % given -3 dB cutoff frequency
            sigma = sqrt(log(2)) / (2 * pi * ratioOfCutoffToSampleFrequency);
            alpha = 10;
            N = 2 * ceil(alpha * sigma) + 1;
            win = gausswin(N, alpha);
            obj.filterObj = win / sum(win);
            % to use the filter:
            % filtered = filtfilt(obj.filterObj, 1, unfiltered);
            obj.updateUI();
        end
        function designDigitalFilter(obj)
            filt = designfilt();
            if isempty(filt)
                return
            end
            obj.filterObj = filt;
            obj.updateUI();
        end
        function visualizeFilterResponse(obj)
            if ~isempty(obj.filterObj)
                fvtool(obj.filterObj);
            end
        end
        function clearFilter(obj)
            obj.filterObj = [];
            obj.updateUI();
        end
        
        function clearAllResampling(obj)
            obj.sumSamplesN = 1;
            obj.downsampleN = 1;
            obj.upsampleN = 1;
        end
        
        function xrange = selectXRange(obj, msg, initialXRange)
            xrange = [];
            if ~exist('msg', 'var') || isempty(msg)
                msg = 'X Range:';
            end
            msgWidth = 20 + 5 * length(msg);
            
            h = obj.hMainMenuBtn.Position(4);
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels', ...
                'Position', [2 obj.hMainMenuBtn.Position(2) obj.hPrevTsBtn.Position(1)-4 h]);
            uicontrol(hDialogPanel, 'style', 'text', ...
                'String', msg, 'Position', [0 0 msgWidth h], ...
                'HorizontalAlignment', 'right');
            xmin = uicontrol(hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [msgWidth 0 60 h], ...
                'Callback', @xminEdited_);
            xmax = uicontrol(hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [msgWidth+60 0 60 h], ...
                'Callback', @xmaxEdited_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [msgWidth+120 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [msgWidth+160 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', 'uiresume()');
            
            if ~exist('initialXRange', 'var') || isempty(initialXRange)
                hROI = drawrectangle(obj.hTraceAxes, 'LineWidth', 1);
            else
                hROI = images.roi.Rectangle(obj.hTraceAxes, 'LineWidth', 1, ...
                    'Position', [initialXRange(1) obj.hTraceAxes.YLim(1) ...
                    diff(initialXRange) diff(obj.hTraceAxes.YLim)]);
            end
            
            hROI.Position(2) = obj.hTraceAxes.YLim(1);
            hROI.Position(4) = diff(obj.hTraceAxes.YLim);
            xmin.String = num2str(hROI.Position(1));
            xmax.String = num2str(hROI.Position(1) + hROI.Position(3));
            listeners(1) = addlistener(hROI, 'MovingROI', @roiEvent_);
            listeners(2) = addlistener(hROI, 'ROIMoved', @roiEvent_);
            
            function xminEdited_(varargin)
                a = str2num(xmin.String);
                b = hROI.Position(1) + hROI.Position(3);
                hROI.Position(1) = a;
                hROI.Position(3) = max(0, b-a);
                if a > b
                    xmax.String = num2str(a);
                end
            end
            function xmaxEdited_(varargin)
                a = hROI.Position(1);
                b = str2num(xmax.String);
                hROI.Position(1) = min(a, b);
                hROI.Position(3) = max(0, b-a);
                if a > b
                    xmin.String = num2str(b);
                end
            end
            function roiEvent_(varargin)
                hROI.Position(2) = obj.hTraceAxes.YLim(1);
                hROI.Position(4) = diff(obj.hTraceAxes.YLim);
                xmin.String = num2str(hROI.Position(1));
                xmax.String = num2str(hROI.Position(1) + hROI.Position(3));
            end
            function ok_(varargin)
                xrange = [hROI.Position(1), hROI.Position(1) + hROI.Position(3)];
                uiresume();
            end
            
            uiwait();
            delete(listeners);
            delete(hDialogPanel);
            delete(hROI);
        end
        function yrange = selectYRange(obj, msg, initialYRange)
            yrange = [];
            if ~exist('msg', 'var')
                msg = 'Y Range:';
            end
            msgWidth = 20 + 5 * length(msg);
            
            h = obj.hMainMenuBtn.Position(4);
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels', ...
                'Position', [2 obj.hMainMenuBtn.Position(2) obj.hPrevTsBtn.Position(1)-4 h]);
            uicontrol(hDialogPanel, 'style', 'text', ...
                'String', msg, 'Position', [0 0 msgWidth h], ...
                'HorizontalAlignment', 'right');
            ymin = uicontrol(hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [msgWidth 0 60 h], ...
                'Callback', @yminEdited_);
            ymax = uicontrol(hDialogPanel, 'style', 'edit', ...
                'String', '', 'Position', [msgWidth+60 0 60 h], ...
                'Callback', @ymaxEdited_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [msgWidth+120 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [msgWidth+160 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', 'uiresume()');
            
            if ~exist('initialYRange', 'var') || isempty(initialYRange)
                hROI = drawrectangle(obj.hTraceAxes, 'LineWidth', 1);
            else
                hROI = images.roi.Rectangle(obj.hTraceAxes, 'LineWidth', 1, ...
                    'Position', [obj.hTraceAxes.XLim(1) initialYRange(1) ...
                    diff(obj.hTraceAxes.XLim) diff(initialYRange)]);
            end
            
            hROI.Position(1) = obj.hTraceAxes.XLim(1);
            hROI.Position(3) = diff(obj.hTraceAxes.XLim);
            ymin.String = num2str(hROI.Position(2));
            ymax.String = num2str(hROI.Position(2) + hROI.Position(4));
            listeners(1) = addlistener(hROI, 'MovingROI', @roiEvent_);
            listeners(2) = addlistener(hROI, 'ROIMoved', @roiEvent_);
            
            function yminEdited_(varargin)
                a = str2num(ymin.String);
                b = hROI.Position(2) + hROI.Position(4);
                hROI.Position(2) = a;
                hROI.Position(4) = max(0, b-a);
                if a > b
                    ymax.String = num2str(a);
                end
            end
            function ymaxEdited_(varargin)
                a = hROI.Position(2);
                b = str2num(ymax.String);
                hROI.Position(2) = min(a, b);
                hROI.Position(4) = max(0, b-a);
                if a > b
                    ymin.String = num2str(b);
                end
            end
            function roiEvent_(varargin)
                hROI.Position(1) = obj.hTraceAxes.XLim(1);
                hROI.Position(3) = diff(obj.hTraceAxes.XLim);
                ymin.String = num2str(hROI.Position(2));
                ymax.String = num2str(hROI.Position(2) + hROI.Position(4));
            end
            function ok_(varargin)
                yrange = [hROI.Position(2), hROI.Position(2) + hROI.Position(4)];
                uiresume();
            end
            
            uiwait();
            delete(listeners);
            delete(hDialogPanel);
            delete(hROI);
        end
        
        function setXLim(obj, xlim)
            if ~exist('xlim', 'var')
                answer = inputdlg({'X Axis Limits'}, ...
                    'XLim', 1, {num2str(obj.hTraceAxes.XLim)});
                if isempty(answer)
                    return
                end
                xlim = str2num(answer{1});
            end
            obj.hTraceAxes.XLim = xlim;
        end
        function setYLim(obj, ylim)
            if ~exist('ylim', 'var')
                answer = inputdlg({'Y Axis Limits'}, ...
                    'YLim', 1, {num2str(obj.hTraceAxes.YLim)});
                if isempty(answer)
                    return
                end
                ylim = str2num(answer{1});
            end
            obj.hTraceAxes.YLim = ylim;
        end
        
        function thresholdIdealization(obj, thresholds)
            if ~exist('thresholds', 'var')
                answer = inputdlg({'Thresholds:'}, ...
                    'Threshold Idealization', 1, {''});
                if isempty(answer)
                    return
                end
                thresholds = str2num(answer{1});
            end
            for t = obj.visibleTsIndices
                try
                    [x, y] = obj.getTsAsShown(t);
                    obj.ts(t).ideal = timeseries;
                    obj.ts(t).ideal.data = zeros(size(y));
                    obj.ts(t).ideal.time = x;
                    idx = y <= thresholds(1);
                    obj.ts(t).ideal.data(idx) = mean(y(idx));
                    for k = 2:numel(thresholds)
                        idx = (y <= thresholds(k)) & (y > thresholds(k-1));
                        obj.ts(t).ideal.data(idx) = mean(y(idx));
                    end
                    idx = y > thresholds(end);
                    obj.ts(t).ideal.data(idx) = mean(y(idx));
                catch err
                    disp(err);
                end
            end
            obj.updateUI();
        end
        function idealizeWithDISC(obj, numStates)
            wb = waitbar(0, 'DISC...');
            try
                disp('Running DISC...');
                disc_input = initDISC();
                if ~exist('numStates', 'var')
                    answer = inputdlg({'# States:'}, ...
                        'DISC', 1, {''});
                    if isempty(answer)
                        return
                    end
                    numStates = str2num(answer{1});
                end
                if numStates > 0
                    disc_input.return_k = numStates;
                end
                for t = obj.visibleTsIndices
                    try
                        [x, y] = obj.getTsAsShown(t);
                        idx = ~isnan(y);
                        disc_fit = runDISC(y(idx), disc_input);
                        obj.ts(t).ideal.time = x;
                        obj.ts(t).ideal.data = nan(size(y));
                        obj.ts(t).ideal.data(idx) = disc_fit.ideal;
                    catch
                    end
                end
                disp('DISC finished.');
                obj.updateUI();
            catch err
                errordlg([err.message ' Requires DISC (https://github.com/ChandaLab/DISC)'], 'DISC');
            end
            close(wb);
        end
        function kmeansIdealization(obj, numStates)
            if ~exist('numStates', 'var')
                answer = inputdlg({'# States:'}, ...
                    'kmeans', 1, {'2'});
                if isempty(answer)
                    return
                end
                numStates = str2num(answer{1});
            end
            wb = waitbar(0, 'kmeans...');
            try
                t = obj.visibleTsIndices(1);
                [x, y] = obj.getTsAsShown(t);
                idx = find(~isnan(y));
                clusterIds = kmeans(y(idx), numStates);
%                 gmm = fitgmdist(y(idx), numGauss, 'start', ids);
%                 P = posterior(gmm, y(idx)); % P(i,j) = prob data(i) in gauss j
%                 [~,k] = max(P, [], 2);
                obj.ts(t).ideal = timeseries;
                obj.ts(t).ideal.data = nan(size(y));
                for i = 1:numStates
                    idxi = idx(clusterIds == i);
                    [mu, sigma] = normfit(y(idxi));
                    obj.ts(t).ideal.data(idxi) = mu;
                end
                obj.ts(t).ideal.time = x;
                obj.updateUI();
            catch err
                disp(err);
            end
            close(wb);
        end
        
        function subtractCapacitiveArtifacts(obj, viewXLim, fitXLim)
            if ~exist('artifactViewWindow', 'var') || ~exist('defaultArtifactFitXLim', 'var')
                answer = inputdlg({'View XLim: ', 'Fit XLim: '}, ...
                    'Per Artifact Window', 1, {'-0.025 0.025', '-0.001 0.004'});
                if isempty(answer)
                    return
                end
                viewXLim = str2num(answer{1});
                fitXLim = str2num(answer{2});
            end
            hVerticalLine = line(obj.hTraceAxes, [0 0], obj.hTraceAxes.YLim, ...
                'LineStyle', '--', 'color', [0 0 0], ...
                'HitTest', 'off', 'PickableParts', 'none');
            hFitLine = line(obj.hTraceAxes, nan, nan, ...
                'LineStyle', '-', 'color', [1 0 0], ...
                'HitTest', 'off', 'PickableParts', 'none');
            hPreviewLine = line(obj.hTraceAxes, nan, nan, ...
                'LineStyle', '-', 'color', [.5 .5 .5], ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            h = obj.hMainMenuBtn.Position(4);
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels', ...
                'Position', [2 obj.hMainMenuBtn.Position(2) obj.hPrevTsBtn.Position(1)-4 h]);
            label = uicontrol(hDialogPanel, 'style', 'text', ...
                'String', 'Subtract Capacitive Artifact', 'Position', [0 0 200 h], ...
                'BackgroundColor', [0 0 0], ...
                'ForegroundColor', [1 1 1]);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [200 0 40 h], ...
                'BackgroundColor', [1 .3 .3], ...
                'Callback', @cancel_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Skip', 'Position', [240 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', @skip_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Retry', 'Position', [280 0 40 h], ...
                'BackgroundColor', [.3 .9 .3], ...
                'Callback', @retry_);
            uicontrol(hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Accept', 'Position', [320 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @accept_);
            
            wasCanceled = false;
            for t = obj.visibleTsIndices
                try
                    sel = obj.hTraceLine(t).BrushData;
                    if isempty(sel) || ~any(sel)
                        continue
                    end
                    sel = double(sel);
                    sel(sel == 0) = nan;
                    [segs, segIdxs] = TimeSeriesExt.getNonNanSegments(sel);
                    nsegs = numel(segs);
                    xy = zeros(nsegs, 2);
                    sel = zeros(size(sel), 'uint8');
                    for k = 1:nsegs
                        idx = segIdxs{k};
                        x = obj.hTraceLine(t).XData(idx);
                        y = obj.hTraceLine(t).YData(idx);
                        [peak, i] = max(y);
                        xy(k,:) = [x(i) peak];
                        sel(idx(i)) = 1;
                    end
                    obj.hTraceLine(t).BrushData = sel;
                    time = obj.ts(t).time;
                    data = obj.ts(t).data;
                    npts = size(data, 1);
                    k = 1;
                    while k <= nsegs
                        x = xy(k,1);
                        y = xy(k,2);
                        obj.hTraceAxes.XLim = x + viewXLim;
                        xrange = obj.selectXRange('', x + fitXLim);
                        if isempty(xrange)
                            k = k + 1;
                            continue
                        end
                        a = find(time >= xrange(1), 1);
                        b = find(time > xrange(2), 1) - 1;
                        idx = a:b;
                        capData = data(idx);
                        capTime = time(idx);
                        
                        [A, i] = max(capData);
                        x0 = capTime(i);
                        tauRise = time(3);
                        tauFall = time(10);
                        C = capData(1);
                        p0 = [x0 A-C tauRise A-C tauFall (A-C)/2 2*tauFall C];
                        lb = [capTime(1) (A-C)/2 time(1) 0 time(1) 0 time(1) 0];
                        ub = [capTime(end-2) 2*A time(10) 2*A time(20) 2*A time(70) A];
                        p = lsqcurvefit(@TimeSeriesExtViewer.capacitiveTransient, ...
                            p0, capTime, capData, lb, ub);
                        x0 = p(1);
                        idx2 = capTime >= x0;
                        idx = idx(idx2);
                        capData = capData(idx2);
                        capTime = capTime(idx2);
                        p0 = p(2:end);
                        lb = lb(2:end);
                        ub = ub(2:end);
                        p = lsqcurvefit(@(p,data)TimeSeriesExtViewer.capacitiveTransientAtX0(p,data,x0), ...
                            p0, capTime, capData, lb, ub);
                        capFit = TimeSeriesExtViewer.capacitiveTransientAtX0(p, capTime, x0);
                        
                        label.String = sprintf('Subtract Capacitive Artifact: %d, %d/%d', t, k, nsegs);
                        hVerticalLine.XData = [x x];
                        hFitLine.XData = capTime;
                        hFitLine.YData = capFit;
                        hPreviewLine.XData = capTime;
                        hPreviewLine.YData = capData - (capFit - capFit(end));
                        
                        uiwait();
                        if wasCanceled
                            break
                        end
                        k = k + 1;
                    end
                catch err
                    disp(err);
                end
                if wasCanceled
                    break
                end
            end
            delete(hVerticalLine);
            delete(hFitLine);
            delete(hPreviewLine);
            delete(hDialogPanel);
            obj.updateUI();
            function cancel_(varargin)
                wasCanceled = true;
                uiresume();
            end
            function skip_(varargin)
                uiresume();
            end
            function retry_(varargin)
                k = k - 1;
                uiresume();
            end
            function accept_(varargin)
                if ~isequal(size(obj.ts(t).artifact), size(obj.ts(t).time))
                    obj.ts(t).artifact = zeros(size(obj.ts(t).time));
                end
                obj.ts(t).artifact(idx) = capFit - capFit(end);
                %obj.ts(t).offset(idx) = obj.ts(t).offset(idx) - (capFit - capFit(end));
                obj.updateUI();
                uiresume();
            end
        end
        
        function appendSimulatedHMM(obj)
            [x, y, ideal] = TimeSeriesExtViewer.simulateHMM();
            npts = size(y,1);
            nseries = size(y,2);
            nruns = size(y,3);
            newts = TimeSeriesExt.empty(0,nseries);
            for i = 1:nseries
                ts = TimeSeriesExt;
                ts.data = y(:,i,1);
                ts.time = x(:,i,1);
                ts.known.data = ideal(:,i,1);
                ts.known.time = x(:,i,1);
                newts(i) = ts;
            end
            obj.ts = [obj.ts newts];
        end
        
        function clearData(obj)
            obj.ts = TimeSeriesExt.empty(1,0);
            obj.updateUI();
        end
        function saveData(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uiputfile('*.mat', 'Save data to file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            wb = waitbar(0, 'Saving data file...');
            ts = obj.ts;
            save(filepath, 'ts');
            close(wb);
        end
        function loadData(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                [file, path] = uigetfile('*.mat', 'Open data file.');
                if isequal(file, 0)
                    return
                end
                filepath = fullfile(path, file);
            end
            wb = waitbar(0, 'Loading data file...');
            tmp = load(filepath);
            close(wb);
            obj.ts = tmp.ts;
        end
        function importHEKA(obj, filepath)
            if ~exist('filepath', 'var') || isempty(filepath)
                filepath = '';
            end
            heka = TimeSeriesExt.importHEKA(filepath);
            ts = TimeSeriesExt.empty(1,0);
            for i = 1:numel(heka)
                nsweeps = size(heka{i}, 1);
                nchannels = size(heka{i}, 2);
                for sweep = 1:nsweeps
                    for channel = 1:nchannels
                        ts = [ts heka{i}(sweep,channel)];
                    end
                end
            end
            obj.ts = [obj.ts ts];
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
        
        function y = capacitiveTransient(params, x)
            x0 = params(1);
            ampRise = params(2);
            tauRise = params(3);
            ampFall1 = params(4);
            tauFall1 = params(5);
            ampFall2 = params(6);
            tauFall2 = params(7);
            constant = params(8);
            y = ampRise .* (1 - exp(-(x - x0) ./ tauRise)) ...
                .* (ampFall1 .* exp(-(x - x0) ./ tauFall1) ...
                + ampFall2 .* exp(-(x - x0) ./ tauFall2)) + constant;
            y(x < x0) = constant;
        end
        function y = capacitiveTransientAtX0(params, x, x0)
            ampRise = params(1);
            tauRise = params(2);
            ampFall1 = params(3);
            tauFall1 = params(4);
            ampFall2 = params(5);
            tauFall2 = params(6);
            constant = params(7);
            y = ampRise .* (1 - exp(-(x - x0) ./ tauRise)) ...
                .* (ampFall1 .* exp(-(x - x0) ./ tauFall1) ...
                + ampFall2 .* exp(-(x - x0) ./ tauFall2)) + constant;
            y(x < x0) = constant;
        end
        
        function [x, y, ideal] = simulateHMM(nruns, nseries, npts, dt, p0, Q, nsites)
            % dimension of y is #pts x #series x #runs
            if nargin < 6
                % dialog
                answer = inputdlg( ...
                    {'# runs', '# series/run', '# samples/series', 'sample interval (sec)', ...
                    'starting probabilities', 'transition rates (/sec)', ...
                    'emission means', 'emission sigmas', ...
                    '# sites/series'}, ...
                    'Simulation', 1, ...
                    {'1', '1', '1000', '0.1', ...
                    '0.5, 0.5', '0, 1; 1, 0', ...
                    '0, 1', '0.25, 0.33', ...
                    '1'});
                if isempty(answer)
                    return
                end
                nruns = str2num(answer{1});
                nseries = str2num(answer{2});
                npts = str2num(answer{3});
                dt = str2num(answer{4});
                p0 = str2num(answer{5});
                Q = str2num(answer{6});
                mu = str2num(answer{7});
                sigma = str2num(answer{8});
            end
            % transition matrix
            Q = Q - diag(diag(Q));
            Q = Q - diag(sum(Q, 2));
            nstates = size(Q, 1);
            A = ones(nstates, nstates) - exp(-Q .* dt); 
            if isempty(p0)
                % equilibrium
                S = [Q ones(nstates, 1)];
                p0 = ones(1, nstates) / (S * (S'));        
            end
            for k = 1:nstates
                pd(k) = makedist('Normal', 'mu', mu(k), 'sigma', sigma(k));
            end
            nsites = str2num(answer{9});
            % model sanity
            p0 = p0 ./ sum(p0);
            A = A - diag(diag(A));
            A = A + diag(1 - sum(A, 2));
            % allocate memory
            x = reshape([0:npts-1] .* dt, [], 1);
            y = zeros(npts, nseries, nsites, nruns);
            ideal = zeros(npts, nseries, nsites, nruns);
            % states
            states = zeros(npts, nseries, nsites, nruns, 'uint8');
            cump0 = cumsum(p0);
            cumA = cumsum(A, 2);
            rn = rand(npts, nseries, nsites, nruns);
            for r = 1:nruns
                for i = 1:nseries
                    for j = 1:nsites
                        t = 1;
                        states(t,i,j,r) = find(rn(t,i,j,r) <= cump0, 1);
                        for t = 2:npts
                            states(t,i,j,r) = find(rn(t,i,j,r) <= cumA(states(t-1,i,j,r),:), 1);
                        end
                    end
                end
            end
            % noisy & ideal
            for k = 1:numel(pd)
                idx = states == k;
                y(idx) = random(pd(k), nnz(idx), 1);
                ideal(idx) = mean(pd(k));
            end
            % add sites together
            if nsites > 1
                y = sum(y, 3);
                ideal = sum(ideal, 3);
            end
            y = squeeze(y);
            ideal = squeeze(ideal);
        end
    end
end

