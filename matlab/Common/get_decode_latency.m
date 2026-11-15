function out = get_decode_latency(scheme, rate_key)
%GET_DECODE_LATENCY  Fixed decode latency (seconds) for one (scheme, rate).
%
%  lat = get_decode_latency('LDPC', 'r1_2')
%
%  Returns the latency stored in decode_latency_table.mat (built once by
%  build_latency_table.m from the MEDIAN of several timed decodes), or NaN
%  if no table exists -- callers then fall back to their own tic/toc.
%  Purpose: labels and goodput no longer depend on machine load / wall-clock
%  jitter, which was flipping near-tied winners (e.g. Turbo R1/3 vs LDPC R1/3
%  on the Comm10km channel) between two runs of the same code.
%
%  s = get_decode_latency('signature')  -> a number identifying the table
%  (0 if none); put it in any cache fingerprint.
%
%  NOTE: after (re)building the table call  clear get_decode_latency  (or
%  build_latency_table does it) because the table is cached per session.

    persistent lat_keys lat_vals loaded
    if isempty(loaded)
        loaded = true;
        lat_keys = {}; lat_vals = [];
        f = 'decode_latency_table.mat';
        if exist(f, 'file')
            S = load(f);
            lat_keys = S.keys; lat_vals = S.vals;
            fprintf('[get_decode_latency] using FIXED latency table (%d entries) from %s\n', ...
                    numel(lat_keys), f);
        end
    end

    if nargin == 1 && strcmp(scheme, 'signature')
        out = sum(lat_vals);
        return
    end

    out = NaN;
    k = [scheme '|' rate_key];
    i = find(strcmp(lat_keys, k), 1);
    if ~isempty(i), out = lat_vals(i); end
end
