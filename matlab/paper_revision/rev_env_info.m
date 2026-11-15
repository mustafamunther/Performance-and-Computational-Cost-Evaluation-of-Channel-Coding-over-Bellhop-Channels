function info = rev_env_info(out_file)
% Hardware / software log requested by the reviewer (R1-6).
    info.date      = datestr(now);
    info.matlab    = version;
    info.release   = version('-release');
    info.computer  = computer;
    info.threads   = maxNumCompThreads;
    try, info.cpu = strtrim(evalc('system(''wmic cpu get name /value'')')); catch, info.cpu = 'n/a'; end
    v = ver; info.toolboxes = strjoin(strcat({v.Name}, {' '}, {v.Version}), '; ');
    fprintf('MATLAB %s | %s | threads=%d\n', info.release, info.computer, info.threads);
    if nargin > 0, save(out_file, 'info'); end
end
