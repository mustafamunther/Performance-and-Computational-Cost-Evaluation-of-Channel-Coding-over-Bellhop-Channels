function pbs = rev_setup()
% Adds the project folders to the path and builds the multi-rate parameter set.
% The project root is located from THIS file's location (parent of paper_revision/),
% falling back to the current folder, so it works wherever MATLAB was started.
    here = fileparts(mfilename('fullpath'));
    roots = {fileparts(here), pwd, fullfile(pwd, '..')};
    ok = false;
    for i = 1:numel(roots)
        if exist(fullfile(roots{i}, 'Adaptive', 'build_params_multi_rate.m'), 'file')
            addpath(genpath(roots{i}));  cd(roots{i});  ok = true;  break;
        end
    end
    if ~ok
        error(['rev_setup: could not find Adaptive/build_params_multi_rate.m. ' ...
               'Put the paper_revision folder inside the project root (next to Adaptive, Common, Schemes).']);
    end
    pbs = build_params_multi_rate();
end
