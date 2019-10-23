function [A, B] = makeStructArraysCompatible(A, B)

% Adds default empty fields to struct arrays A and B as needed so that they
% have identical fieldnames.

% Created by Marcel Goldschen-Ohm
% <goldschen-ohm@utexas.edu, marcel.goldschen@gmail.com>

fa = fieldnames(A);
fb = fieldnames(B);
fab = union(fa, fb);
for k = 1:numel(fab)
    if ~isfield(A, fab{k})
        bk = B(1).(fab{k});
        if isobject(bk)
            [A.(fab{k})] = deal(eval(class(bk)));
        else
            [A.(fab{k})] = deal([]);
        end
    elseif ~isfield(B, fab{k})
        ak = A(1).(fab{k});
        if isobject(ak)
            [B.(fab{k})] = deal(eval(class(ak)));
        else
            [B.(fab{k})] = deal([]);
        end
    end
end

end