function bits = turbo_decode(llr, params)
%TURBO_DECODE  Iterative (BCJR/APP) turbo decoder via comm.TurboDecoder.
%
%  bits = turbo_decode(llr, params)
%
%  Inputs
%    llr    — channel LLRs, N per block (column vector)
%             sign convention: LLR > 0 -> bit likely 0, LLR < 0 -> bit likely 1
%             (this project's convention — matches ofdm_demodulate.m /
%              symbols_to_llr.m and the vitdec 'unquant' calls elsewhere)
%    params — get_system_params() structure
%             uses: params.N, params.K, params.turbo.trellis,
%                   params.turbo.interleaver, params.turbo.num_iter
%
%  Output
%    bits   — hard-decoded information bits (K bits per block x n_blocks)
%
%  *** LLR SIGN CONVENTION WARNING ***
%  comm.TurboDecoder expects the OPPOSITE convention from the rest of
%  this project (confirmed against MathWorks documentation, which
%  explicitly negates the demodulator LLR before calling the turbo
%  decoder: "the decoder input must use the inverse of the demodulated
%  signal", i.e. turbodec(-demodSignal) in their own reference example).
%  This function negates the incoming LLR internally so callers can keep
%  using the project's normal convention everywhere else.

llr = llr(:);
N = params.N;
K = params.K;

decObj = comm.TurboDecoder('TrellisStructure',  params.turbo.trellis, ...
                            'InterleaverIndices', params.turbo.interleaver, ...
                            'NumIterations',      params.turbo.num_iter);

%% ---- Pad LLR to a multiple of N ----
pad   = mod(-length(llr), N);
llr_p = [llr; zeros(pad,1)];
n_blk = length(llr_p) / N;

bits = zeros(n_blk * K, 1);

for b = 1:n_blk
    L = llr_p((b-1)*N + 1 : b*N);
    d = decObj(-L);     % <-- sign flip required by comm.TurboDecoder, see warning above
    bits((b-1)*K + 1 : b*K) = d;
end

bits = bits(:);
end
