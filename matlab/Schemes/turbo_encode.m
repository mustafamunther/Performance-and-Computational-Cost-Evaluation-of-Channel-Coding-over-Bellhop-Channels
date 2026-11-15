function coded = turbo_encode(bits, params)
%TURBO_ENCODE  Parallel-concatenated (turbo) encoder via comm.TurboEncoder.
%
%  coded = turbo_encode(bits, params)
%
%  Inputs
%    bits   — information bits (column vector, 0/1)
%    params — get_system_params() structure
%             uses: params.K, params.N, params.turbo.trellis,
%                   params.turbo.interleaver
%
%  Output
%    coded  — turbo codeword(s), column vector length n_blocks*N
%             (natural rate ~1/3: systematic + 2 parity streams + tails,
%              N = 3*K + 4*m, m = trellis memory)
%
%  IMPORTANT: params.turbo.interleaver is computed ONCE in
%  get_system_params.m and must be the SAME object passed to
%  turbo_decode.m — a mismatched interleaver silently produces garbage,
%  the same class of bug found earlier in the hand-rolled LDPC G/H code.

bits = bits(:);
K = params.K;
N = params.N;

encObj = comm.TurboEncoder('TrellisStructure',  params.turbo.trellis, ...
                            'InterleaverIndices', params.turbo.interleaver);

%% ---- Pad info bits to a multiple of K ----
pad    = mod(-length(bits), K);
bits_p = [bits; zeros(pad,1)];
n_blk  = length(bits_p) / K;

coded = zeros(n_blk * N, 1);

for b = 1:n_blk
    d  = bits_p((b-1)*K + 1 : b*K);
    cw = encObj(d);              % length = N
    coded((b-1)*N + 1 : b*N) = cw;
end

coded = coded(:);
end
