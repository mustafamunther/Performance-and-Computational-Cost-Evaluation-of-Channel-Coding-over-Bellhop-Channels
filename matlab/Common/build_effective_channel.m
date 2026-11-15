 function h_short = build_effective_channel(h, cp_len)

% Find significant taps
thr = 0.01 * max(abs(h));
idx = find(abs(h) >= thr);

if isempty(idx)
    h_short = h;
    return;
end

% First significant path
firstTap = idx(1);

% Keep only taps inside CP window
lastTap = min(firstTap + cp_len - 1, length(h));

h_short = h(firstTap:lastTap);

% Normalize energy
h_short = h_short / norm(h_short);
end  