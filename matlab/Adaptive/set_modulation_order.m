function params = set_modulation_order(params, modType)
%SET_MODULATION_ORDER  Override a scheme's modulation order at runtime,
%  recomputing everything in params that depends on bits_per_sym.
%
%  params = set_modulation_order(params, modType)
%
%  Each get_params_*.m file hard-codes params.modulation = 'QPSK' and
%  params.bits_per_sym = 2 at config-build time, with params.num_ofdm_syms
%  / params.bits_per_ofdm / params.frame_bits precomputed for THAT
%  modulation. For adaptive modulation, the FEC scheme's N (coded-bit
%  count) stays fixed, but a higher-order constellation packs those N
%  bits into FEWER OFDM symbols -- so switching modulation requires
%  recomputing the OFDM frame sizing fields, or ofdm_modulate.m /
%  ofdm_demodulate.m will mis-size the frame (symptom: garbage/short
%  codewords, not an obvious crash -- the same class of silent
%  TX/RX-disagreement bug this project's other files explicitly guard
%  against, e.g. the frozen-bit-mask and turbo-interleaver notes in
%  polar_encode.m / turbo_encode.m).
%
%  Inputs
%    params  - a scheme's params struct (from get_params_ldpc.m / _polar.m
%              / _turbo.m / _conv.m), with .N already set to that
%              scheme's native codeword length
%    modType - 'BPSK' | 'QPSK' | '16QAM' | '64QAM'
%
%  Output
%    params - same struct with .modulation, .bits_per_sym,
%             .bits_per_ofdm, .num_ofdm_syms, .frame_bits updated
%             consistently for modType, at the SAME coded-bit length N

    switch modType
        case 'BPSK',  bps = 1;
        case 'QPSK',  bps = 2;
        case '16QAM', bps = 4;
        case '64QAM', bps = 6;
        otherwise
            error('set_modulation_order: unknown modulation "%s".', modType);
    end

    params.modulation   = modType;
    params.bits_per_sym = bps;

    % data_subs_per_sym does not depend on modulation (it's a subcarrier
    % count), so it is NOT recomputed here -- only the modulation-dependent
    % derived fields are:
    params.bits_per_ofdm = params.data_subs_per_sym * bps;
    params.num_ofdm_syms = ceil(params.N / params.bits_per_ofdm);
    params.frame_bits    = params.num_ofdm_syms * params.bits_per_ofdm;

end
