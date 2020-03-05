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
        hPageLeftBtn
        hPageRightBtn
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
        
        tmp = struct();
    end
    
    properties (Access = private)
        colors = lines();
%         dialogPositionWithinUi = [];
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
            
            obj.hPageLeftBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', '<<', 'Position', [0 0 20 20], ...
                'Tooltip', 'Page Left', ...
                'Callback', @(varargin) obj.pageLeft());
            obj.hPageRightBtn = uicontrol(obj.hPanel, 'style', 'pushbutton', ...
                'String', '>>', 'Position', [0 0 20 20], ...
                'Tooltip', 'Page Right', ...
                'Callback', @(varargin) obj.pageRight());
            
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
                'Value', 1, ...
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
            tf = obj.hShowRawOrBtn.String == "R";
        end
        function tf = get.isShowBaselined(obj)
            tf = obj.hShowRawOrBtn.String == "B";
        end
        function tf = get.isShowBaselinedAndScaled(obj)
            tf = obj.hShowRawOrBtn.String == "BS";
        end
        function showRaw(obj)
            try
                if obj.hShowRawOrBtn.String ~= "R" ...
                        && isvalid(obj.hROI) ...
                        && class(obj.hROI) == "images.roi.Polyline"
                    % update polyline to track baseline offset
                    t = obj.visibleTsIndices(1);
                    y0 = -obj.ts(t).offset;
                    if numel(y0) == 1
                        obj.hROI.Position(:,2) = obj.hROI.Position(:,2) + y0;
                    else
                        x = obj.ts(t).time;
                        py = obj.hROI.Position(:,2);
                        for i = 1:size(obj.hROI.Position, 1)
                            px = obj.hROI.Position(i,1);
                            idx = find(x >= px, 1);
                            py(i) = py(i) + y0(idx);
                        end
                        obj.hROI.Position(:,2) = py;
                    end
                end
            catch
            end
            obj.hShowRawOrBtn.String = "R";
            obj.updateUI();
        end
        function showBaselined(obj)
            try
                if obj.hShowRawOrBtn.String == "R" ...
                        && isvalid(obj.hROI) ...
                        && class(obj.hROI) == "images.roi.Polyline"
                    % update polyline to track baseline
                    obj.hROI.Position(:,2) = 0;
                end
            catch
            end
            obj.hShowRawOrBtn.String = "B";
            obj.updateUI();
        end
        function showBaselinedAndScaled(obj)
            try
                if obj.hShowRawOrBtn.String == "R" ...
                        && isvalid(obj.hROI) ...
                        && class(obj.hROI) == "images.roi.Polyline"
                    % update polyline to track baseline
                    obj.hROI.Position(:,2) = 0;
                end
            catch
            end
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
            bx = bx - 5 - 2*lineh;
            obj.hPageLeftBtn.Position = [bx by lineh lineh];
            obj.hPageRightBtn.Position = [bx+lineh by lineh lineh];
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
%             obj.dialogPositionWithinUi = [2 by obj.hPrevTsBtn.Position(1)-2-2 lineh];
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
            % delete unneeded graphics objects
            if numel(obj.hTraceLine) > numTs
                delete(obj.hTraceLine(numTs+1:end));
                delete(obj.hTraceIdealLine(numTs+1:end));
                delete(obj.hHistBar(numTs+1:end));
                delete(obj.hHistIdealLines(numTs+1:end));
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
            elseif obj.isShowBaselined
                y = obj.ts(t).raw.data + obj.ts(t).offset;
            else % baselined and scaled
                y = obj.ts(t).data;
            end
            % filter
            if obj.isApplyFilter && ~isempty(obj.filterObj)
                if isa(obj.filterObj, 'digitalFilter')
                    y = filtfilt(obj.filterObj, y);
                else
                    y = filter(obj.filterObj, 1, y);
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
            
            % selections
            submenu = uimenu(menu, 'Label', 'Select');
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
            
            % mask
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
            
            % baseline
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
            uimenu(submenu, 'Label', 'Baseline Sliding Lognormal Peak', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.baselineSlidingLognormalPeak());
%             uimenu(submenu, 'Label', 'GMM Baseline Spline', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.baselineSplineGMMDialog());
%             uimenu(submenu, 'Label', 'Baseline To Selected Gaussian Level', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.baselineToSelectedGaussLevel());
%             uimenu(submenu, 'Label', 'Smooth Baseline', ...
%                 'Separator', 'on', ...
%                 'Callback', @(varargin) obj.smoothBaseline());
            uimenu(submenu, 'Label', 'Clear Baseline Offset', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.clearBaselineOffset());
            
            % model
            submenu = uimenu(menu, 'Label', 'Model', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Threshold Idealization', ...
                'Callback', @(varargin) obj.thresholdIdealization());
            uimenu(submenu, 'Label', 'DISC Idealization', ...
                'Separator', 'on', ...
                'Callback', @(varargin) obj.idealizeWithDISC());
%             uimenu(submenu, 'Label', 'Fit GMM', ...
%                 'Callback', @(varargin) obj.fitGMM());
            
            % filter
            label = 'Filter';
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
            
            % resample
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
            
            % display
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
            
            % custom
            submenu = uimenu(menu, 'Label', 'Custom', ...
                'Separator', 'on');
            uimenu(submenu, 'Label', 'Fit Capacitive Artifacts', ...
                'Callback', @(varargin) obj.fitCapacitiveArtifacts());
            uimenu(submenu, 'Label', 'Subtract Capacitive Artifacts', ...
                'Callback', @(varargin) obj.subtractCapacitiveArtifacts());
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
            obj.hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels');
            x = 2;
            y = obj.hMenuBtn.Position(2);
            w = 180;
            h = obj.hMenuBtn.Position(4);
            obj.hDialogPanel.Position = [x y w h];
            
            uicontrol(obj.hDialogPanel, 'style', 'text', ...
                'String', 'Baseline Nodes', 'Position', [0 0 100 h], ...
                'BackgroundColor', [0 0 0], ...
                'ForegroundColor', [1 1 1]);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [100 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', @cancel_);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [140 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            
            t = obj.visibleTsIndices(1);
            originalOffset = obj.ts(t).offset;
            
            obj.hROI = drawpolyline(obj.hTraceAxes);
            obj.isShowBaseline = 1;
            roiEvent_();
            listeners(1) = addlistener(obj.hROI, 'ROIMoved', @roiEvent_);
            
            function roiEvent_(varargin)
                try
                    t = obj.visibleTsIndices(1);
                    ptsx = obj.hROI.Position(:,1);
                    ptsy = obj.hROI.Position(:,2);
                    baseline = interp1(ptsx, ptsy, obj.ts(t).time, 'makima');
                    if obj.isShowRaw
                        obj.ts(t).offset = -baseline;
                    else
                        obj.ts(t).offset = obj.ts(t).offset - baseline;
                        obj.hROI.Position(:,2) = 0;
                    end
                    obj.updateUI();
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
            delete(obj.hDialogPanel);
            delete(obj.hROI);
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
                npts = length(time);
                step = floor(double(npts) / (numNodes-1));
                idx = [1:step:npts npts];
                nodex = reshape(time(idx), [], 1);
                nodey = zeros(size(nodex));
                if obj.isShowRaw
                    if numel(obj.ts(t).offset) == 1
                        nodey = nodey - obj.ts(t).offset;
                    else
                        nodey = nodey - obj.ts(t).offset(idx);
                    end
                end
                nodesXY = [nodex nodey];
            elseif size(numNodesOrNodesXY,2) == 2
                % node [x y] positions
                nodesXY = numNodesOrNodesXY;
            else
                return
            end
            
            obj.hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels');
            x = 2;
            y = obj.hMenuBtn.Position(2);
            w = 180;
            h = obj.hMenuBtn.Position(4);
            obj.hDialogPanel.Position = [x y w h];
            
            uicontrol(obj.hDialogPanel, 'style', 'text', ...
                'String', 'Baseline Nodes', 'Position', [0 0 100 h], ...
                ... %'HorizontalAlignment', 'right', ...
                'BackgroundColor', [0 0 0], ...
                'ForegroundColor', [1 1 1]);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'Cancel', 'Position', [100 0 40 h], ...
                'BackgroundColor', [1 .6 .6], ...
                'Callback', @cancel_);
            uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
                'String', 'OK', 'Position', [140 0 40 h], ...
                'BackgroundColor', [.6 .9 .6], ...
                'Callback', @ok_);
            
            t = obj.visibleTsIndices(1);
            originalOffset = obj.ts(t).offset;
            
            obj.hROI = images.roi.Polyline(obj.hTraceAxes, 'Position', nodesXY);
            obj.isShowBaseline = 1;
            roiEvent_();
            listeners(1) = addlistener(obj.hROI, 'ROIMoved', @roiEvent_);
            
            function roiEvent_(varargin)
                try
                    ptsx = obj.hROI.Position(:,1);
                    ptsy = obj.hROI.Position(:,2);
                    t = obj.visibleTsIndices(1);
                    baseline = interp1(ptsx, ptsy, obj.ts(t).time, 'makima');
                    if obj.isShowRaw
                        obj.ts(t).offset = -baseline;
                    else
                        obj.ts(t).offset = obj.ts(t).offset - baseline;
                        obj.hROI.Position(:,2) = 0;
                    end
                    obj.updateUI();
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
            delete(obj.hDialogPanel);
            delete(obj.hROI);
        end
        function baselineSplineGMM(obj, numGauss, numSplineSegments, hScatter)
%             try
%             t = obj.visibleTsIndices(1);
%             xdata = reshape(obj.hTraceLine(t).XData, [], 1);
%             ydata = reshape(obj.hTraceLine(t).YData, [], 1);
%             gmm = fitgmdist(ydata, numGauss);
%             [~, k0] = min(gmm.mu);
%             P = posterior(gmm, ydata); % P(i,j) = prob ydata(i) in gauss j
%             [~,k] = max(P, [], 2);
%             idx = k == k0;
%             xdata0 = xdata(idx);
%             ydata0 = ydata(idx);
%             pp = splinefit(xdata0, ydata0, numSplineSegments);
%             time = obj.ts(t).time;
%             if obj.isShowRaw
%                 obj.ts(t).offset = -ppval(pp, time);
%             else
%                 obj.ts(t).offset = obj.ts(t).offset - ppval(pp, time);
%             end
%             obj.updateUI();
%             if exist('hScatter', 'var') && isvalid(hScatter)
%                 hScatter.XData = obj.hTraceLine(t).XData;
%                 hScatter.YData = obj.hTraceLine(t).YData;
%                 cdata = zeros(length(hScatter.YData), 3);
%                 cmap = lines(numGauss);
%                 for i = 1:numGauss
%                     idx = find(k == i);
%                     cdata(idx,:) = repmat(cmap(i,:), length(idx), 1);
%                 end
%                 hScatter.CData = cdata;
%             end
%             catch e
%                 e.message
%             end
        end
        function baselineSplineGMMDialog(obj)
%             hScatter = scatter(obj.hTraceAxes, [], [], 'filled');
%             
%             dlg = dialog('Name', 'GMM Baseline Spline');
%             dlg.Position(3) = 300;
%             dlg.Position(4) = 110;
%             uicontrol(dlg, 'style', 'text', ...
%                 'String', '# Gaussians ', 'Position', [10 80 140 20], ...
%                 'HorizontalAlignment', 'right');
%             numGaussEdit = uicontrol(dlg, 'style', 'edit', ...
%                 'String', '2', 'Position', [150 80 140 20]);
%             uicontrol(dlg, 'style', 'text', ...
%                 'String', '# Spline Segments ', 'Position', [10 60 140 20], ...
%                 'HorizontalAlignment', 'right');
%             numSegmentsEdit = uicontrol(dlg, 'style', 'edit', ...
%                 'String', '3', 'Position', [150 60 140 20]);
%             uicontrol(dlg, 'style', 'pushbutton', ...
%                 'String', 'Close', 'Position', [100 10 60 40], ...
%                 'Callback', 'close(gcf)');
%             uicontrol(dlg, 'style', 'pushbutton', ...
%                 'String', 'Fit', 'Position', [160 10 60 40], ...
%                 'Callback', @(varargin) obj.baselineSplineGMM( ...
%                 str2num(numGaussEdit.String), ...
%                 str2num(numSegmentsEdit.String), ...
%                 hScatter));
%             
%             uiwait(dlg);
%             delete(hScatter);
        end
        function baselineToSelectedGaussLevel(obj)
%             obj.hDialogPanel = uipanel(obj.hPanel, ...
%                 'BorderType', 'line', ...
%                 'AutoResizeChildren', 'off', ...
%                 'Units', 'pixels');
%             x = 2;%obj.hMenuBtn.Position(1) + 2 * obj.hMenuBtn.Position(3);
%             y = obj.hMenuBtn.Position(2);
%             w = 380;
%             h = obj.hMenuBtn.Position(4);
%             obj.hDialogPanel.Position = [x y w h];
%             
%             uicontrol(obj.hDialogPanel, 'style', 'text', ...
%                 'String', 'Baseline To Gauss Level', 'Position', [0 0 150 h], ...
%                 ... %'HorizontalAlignment', 'right', ...
%                 'BackgroundColor', [0 0 0], ...
%                 'ForegroundColor', [1 1 1]);
%             uicontrol(obj.hDialogPanel, 'style', 'text', ...
%                 'String', '# Spline Segments:', 'Position', [150 0 100 h], ...
%                 'HorizontalAlignment', 'right');
%             numSegsEdit = uicontrol(obj.hDialogPanel, 'style', 'edit', ...
%                 'String', '10', 'Position', [250 0 50 h], ...
%                 'Callback', @(varargin) roiEvent_());
%             uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
%                 'String', 'Fit', 'Position', [300 0 40 h], ...
%                 'Callback', @fit_);
%             uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
%                 'String', 'Done', 'Position', [340 0 40 h], ...
%                 'BackgroundColor', [.6 .9 .6], ...
%                 'Callback', @ok_);
%             busyText = uicontrol(obj.hDialogPanel, 'style', 'text', ...
%                 'String', 'busy...', 'Position', [300 0 40 h], ...
%                 'ForegroundColor', [1 0 0], ...
%                 'Visible', 'off');
% %             uicontrol(obj.hDialogPanel, 'style', 'pushbutton', ...
% %                 'String', 'Cancel', 'Position', [msgWidth+160 0 40 h], ...
% %                 'BackgroundColor', [1 .6 .6], ...
% %                 'Callback', 'uiresume()');
%             
%             obj.hROI = drawrectangle(obj.hTraceAxes, ...
%                 'LineWidth', 1);
%             obj.hROI.Position(1) = obj.hTraceAxes.XLim(1);
%             obj.hROI.Position(3) = diff(obj.hTraceAxes.XLim);
%             obj.isShowBaseline = 1;
%             roiEvent_();
%             listeners(1) = addlistener(obj.hROI, 'ROIMoved', @roiEvent_);
%             
%             function roiEvent_(varargin)
%                 obj.hROI.Position(1) = obj.hTraceAxes.XLim(1);
%                 obj.hROI.Position(3) = diff(obj.hTraceAxes.XLim);
%             end
%             function fit_(varargin)
%                 try
%                     busyText.Visible = 'on';
%                     obj.hROI.Position(1) = obj.hTraceAxes.XLim(1);
%                     obj.hROI.Position(3) = diff(obj.hTraceAxes.XLim);
%                     ymin = obj.hROI.Position(2);
%                     ymax = obj.hROI.Position(2) + obj.hROI.Position(4);
%                     xdata = obj.hTraceLine.XData;
%                     ydata = obj.hTraceLine.YData;
%                     idx = ydata < ymin;
%                     xdata(idx) = [];
%                     ydata(idx) = [];
%                     idx = ydata > ymax;
%                     xdata(idx) = [];
%                     ydata(idx) = [];
%                     [mu, sigma] = normfit(ydata);
%                     % center ROI on mu
%                     if ymax - mu <= mu - ymin
%                         ymin = mu - (ymax - mu);
%                     else
%                         ymax = mu + (mu - ymin);
%                     end
%                     obj.hROI.Position(2) = ymin;
%                     obj.hROI.Position(4) = ymax - ymin;
%                     drawnow;
%                     % fit spline to level
%                     numSegments = str2num(numSegsEdit.String);
%                     pp = splinefit(xdata, ydata, numSegments);
%                     t = obj.visibleTsIndices(1);
%                     if obj.isShowRaw
%                         obj.ts(t).offset = -ppval(pp, obj.ts(t).time);
%                     else
%                         obj.ts(t).offset = obj.ts(t).offset - ppval(pp, obj.ts(t).time);
%                         obj.hROI.Position(2) = -(ymax - ymin) / 2;
%                     end
%                     busyText.Visible = 'off';
%                     % show fit
%                     obj.updateUI();
%                 catch
%                 end
%             end
%             function ok_(varargin)
%                 uiresume();
%             end
%             
%             uiwait();
%             delete(listeners);
%             delete(obj.hDialogPanel);
%             delete(obj.hROI);
        end
        function baselineSlidingLognormalPeak(obj, windowPts, stepPts)%, numSplineSegments)
            if ~exist('windowPts', 'var') || ~exist('stepPts', 'var')
                answer = inputdlg({'Window (pts):', 'Step (pts):'}, ...
                    'DISC', 1, {'1000', '100'});
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
        
        function setGaussianFilter(obj, windowPts)
            if ~exist('windowPts', 'var')
                answer = inputdlg({'# Window Pts:'}, ...
                    'Gaussian Filter', 1, {'10'});
                if isempty(answer)
                    return
                end
                windowPts = str2num(answer{1});
            end
            
            win = gausswin(windowPts);
            obj.filterObj = win ./ sum(win); % y = filter(win, 1, x);
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
        
        function xrange = selectXRange(obj, msg, initialXRange)
            xrange = [];
            if ~exist('msg', 'var') || isempty(msg)
                msg = 'X Range:';
            end
            msgWidth = 20 + 5 * length(msg);
            
            h = obj.hMenuBtn.Position(4);
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels', ...
                'Position', [2 obj.hMenuBtn.Position(2) obj.hPrevTsBtn.Position(1)-4 h]);
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
            
            h = obj.hMenuBtn.Position(4);
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels', ...
                'Position', [2 obj.hMenuBtn.Position(2) obj.hPrevTsBtn.Position(1)-4 h]);
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
                return
            end
        end
        
        function fitGMM(obj, numGauss)
            if ~exist('numGauss', 'var')
                answer = inputdlg({'# Gaussians:'}, ...
                    'Fit GMM', 1, {'2'});
                if isempty(answer)
                    return
                end
                numGauss = str2num(answer{1});
            end
            
            wb = waitbar(0, 'GMM fit...');
            
            t = obj.visibleTsIndices(1);
            ydata = reshape(obj.hTraceLine(t).YData, [], 1);
            obj.ts(t).model.gmm = fitgmdist(ydata, numGauss);
            
            P = posterior(obj.ts(t).model.gmm, obj.ts(t).data); % P(i,j) = prob ydata(i) in gauss j
            [~,k] = max(P, [], 2);
            
            for i = 1:numGauss
                name  = sprintf('GMM %d', i);
                obj.ts(t).selections(name) = k == i;
            end
            
            close(wb);
        end
        function fitSKM(obj, numStates)
        end
        
        function subtractCapacitiveArtifacts(obj)
            hVerticalLine = line(obj.hTraceAxes, [0 0], obj.hTraceAxes.YLim, ...
                'LineStyle', '--', 'color', [0 0 0], ...
                'HitTest', 'off', 'PickableParts', 'none');
            hFitLine = line(obj.hTraceAxes, nan, nan, ...
                'LineStyle', '-', 'color', [1 0 0], ...
                'HitTest', 'off', 'PickableParts', 'none');
            hPreviewLine = line(obj.hTraceAxes, nan, nan, ...
                'LineStyle', '-', 'color', [.5 .5 .5], ...
                'HitTest', 'off', 'PickableParts', 'none');
            
            h = obj.hMenuBtn.Position(4);
            hDialogPanel = uipanel(obj.hPanel, ...
                'BorderType', 'line', ...
                'AutoResizeChildren', 'off', ...
                'Units', 'pixels', ...
                'Position', [2 obj.hMenuBtn.Position(2) obj.hPrevTsBtn.Position(1)-4 h]);
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
                        xwindow = 0.05;%diff(obj.hTraceAxes.XLim);
                        obj.hTraceAxes.XLim = [-.5 .5] .* xwindow + x;
                        xrange = obj.selectXRange('', [-.02 .08] .* xwindow + x);
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
                obj.ts(t).offset(idx) = obj.ts(t).offset(idx) - (capFit - capFit(end));
                obj.updateUI();
                uiresume();
            end
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
%         function sse = capacitiveTransientSSE(params, x, y)
%             fit = TimeSeriesExtViewer.capacitiveTransient(params, x);
%             idx = ~isnan(fit);
%             sse = sum((y(idx) - fit(idx)).^2);
%         end
    end
end

