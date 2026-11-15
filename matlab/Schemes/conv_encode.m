function coded = conv_encode(bits, params)
%CONV_ENCODE  Rate-1/2 convolutional encoder (zero-tail terminated).
%
%  coded = conv_encode(bits, params)
%
%  Inputs
%    bits   — information bits (column vector, 0/1)
%    params — get_system_params() structure
%             uses: params.K, params.N, params.conv.trellis,
%                   params.conv.constraint
%
%  Output
%    coded  — convolutional codeword(s), column vector length n_blocks*N
%
%  Each K-bit info block has (constraint-1) zero "tail" bits appended so
%  the trellis is forced back to the all-zero state, then it is encoded
%  at rate 1/2 via convenc(). N = (K + constraint-1) / rate coded bits
%  come out per block — this matches params.N as set in get_system_params.m.

bits = bits(:);
K       = params.K;
N       = params.N;
tail    = params.conv.constraint - 1;
trellis = params.conv.trellis;

%% ---- Pad info bits to a multiple of K ----
pad    = mod(-length(bits), K);
bits_p = [bits; zeros(pad,1)];
n_blk  = length(bits_p) / K;

coded = zeros(n_blk * N, 1);

for b = 1:n_blk
    d     = bits_p((b-1)*K + 1 : b*K);
    d_ext = [d; zeros(tail,1)];       % force trellis back to the zero state
    cw    = convenc(d_ext, trellis);  % length = (K+tail)/rate = N
    coded((b-1)*N + 1 : b*N) = cw;
end

coded = coded(:);
end