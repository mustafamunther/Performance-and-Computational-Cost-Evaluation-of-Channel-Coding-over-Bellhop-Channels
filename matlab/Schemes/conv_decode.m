function bits = conv_decode(llr, params)
%CONV_DECODE  Soft-decision Viterbi decoder matching conv_encode.m.
%
%  bits = conv_decode(llr, params)
%
%  Inputs
%    llr    — channel LLRs, N per block (column vector)
%             sign convention: LLR > 0 -> bit likely 0, LLR < 0 -> bit likely 1
%             (matches the convention already used by ofdm_demodulate.m)
%    params — get_system_params() structure
%             uses: params.N, params.K, params.conv.trellis,
%                   params.conv.constraint, params.conv.tbdepth
%
%  Output
%    bits   — hard-decoded information bits (K bits per block x n_blocks)
%             (the constraint-1 known-zero tail bits are stripped before
%              returning, so the output lines up 1:1 with conv_encode.m's
%              input)
%
%  Uses vitdec() in 'term' (terminated) mode with unquantized
%  soft-decision input — 'term' matches conv_encode.m's zero-tail
%  termination (decoder knows the trellis starts AND ends at state 0).

llr = llr(:);
N       = params.N;
K       = params.K;
tail    = params.conv.constraint - 1;
trellis = params.conv.trellis;
tbdepth = params.conv.tbdepth;

%% ---- Pad LLR to a multiple of N ----
pad   = mod(-length(llr), N);
llr_p = [llr; zeros(pad,1)];
n_blk = length(llr_p) / N;

bits = zeros(n_blk * K, 1);

for b = 1:n_blk
    L        = llr_p((b-1)*N + 1 : b*N);
    dec_full = vitdec(L, trellis, tbdepth, 'term', 'unquant');
    % dec_full is K+tail bits long; keep only the K real info bits
    bits((b-1)*K + 1 : b*K) = dec_full(1:K);
end

bits = bits(:);
end