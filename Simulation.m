classdef Simulation < handle
    %SIMULATION Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static)
        function [x, y, ideal] = simulateTimeSeries(nruns, nseries, npts, dt, model, nsites)
            if nargin < 5
                % dialog
                answer = inputdlg( ...
                    {'# runs', '# series/run', '# samples/series', 'sample interval (sec)', ...
                    'starting probabilities', 'transition rates (/sec)', ...
                    'emission means', 'emission sigmas', ...
                    '# sites/series'}, ...
                    'Simulation', 1, ...
                    {'1', '100', '1000', '0.1', ...
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
                model.p0 = Simulation.str2mat(answer{5});
                Q = Simulation.str2mat(answer{6});
                Q = Q - diag(diag(Q));
                Q = Q - diag(sum(Q, 2));
                nstates = size(Q, 1);
                model.A = ones(nstates, nstates) - exp(-Q .* dt); 
                if isempty(model.p0)
                    % equilibrium
                    S = [Q ones(nstates, 1)];
                    model.p0 = ones(1, nstates) / (S * (S'));        
                end
                mu = Simulation.str2mat(answer{7});
                sigma = Simulation.str2mat(answer{8});
                for k = 1:nstates
                    model.pd(k) = makedist('Normal', 'mu', mu(k), 'sigma', sigma(k));
                end
                nsites = str2num(answer{9});
                % model sanity
                model.p0 = model.p0 ./ sum(model.p0);
                model.A = model.A - diag(diag(model.A));
                model.A = model.A + diag(1 - sum(model.A, 2));
            end
            % allocate memory
            x = reshape([0:npts-1] .* dt, [], 1);
            y = zeros(npts, nseries, nsites, nruns);
            ideal = zeros(npts, nseries, nsites, nruns);
            % states
            states = zeros(npts, nseries, nsites, nruns, 'uint8');
            cump0 = cumsum(model.p0);
            cumA = cumsum(model.A, 2);
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
            for k = 1:numel(model.pd)
                idx = states == k;
                y(idx) = random(model.pd(k), nnz(idx), 1);
                ideal(idx) = mean(model.pd(k));
            end
            % add sites together
            if nsites > 1
                y = sum(y, 3);
                ideal = sum(ideal, 3);
            end
            y = squeeze(y);
            ideal = squeeze(ideal);
        end
        
        function mat = str2mat(str)
            str = strtrim(str);
            if startsWith(str, '[')
                str = strip(str, 'left', '[');
            end
            if endsWith(str, ']')
                str = strip(str, 'right', ']');
            end
            rows = split(str, ';');
            nrows = numel(rows);
            for i = 1:nrows
                cols = split(rows{i}, ',');
                if i == 1
                    ncols = numel(cols);
                    mat = zeros(nrows, ncols);
                end
                for j = 1:ncols
                    mat(i, j) = str2num(cols{j});
                end
            end
        end
    end
end

