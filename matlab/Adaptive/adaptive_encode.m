function [codedBits, p, N, K] = adaptive_encode(infoBits, scheme, rate_key, modulation, params_by_scheme)
%ADAPTIVE_ENCODE  Dispatch to the chosen FEC scheme's own encoder, with
%  the chosen CODING RATE and MODULATION ORDER both applied (full
%  Adaptive Modulation AND Coding, including rate selection).
%
%  [codedBits, p, N, K] = adaptive_encode(infoBits, scheme, rate_key, modulation, params_by_scheme)
%
%  Inputs
%    infoBits         - information bits (column vector, 0/1), length
%                        should be this (scheme,rate)'s K (see
%                        apply_coding_rate.m); the scheme's own encoder
%                        pads to a multiple of K internally regardless.
%    scheme            - 'LDPC' | 'Polar' | 'Turbo' | 'Conv'
%    rate_key          - 'r1_3' | 'r1_2' | 'r2_3' (see
%                        build_params_multi_rate.m for which rates each
%                        scheme actually supports)
%    modulation         - 'BPSK' | 'QPSK' | '16QAM' | '64QAM'
%    params_by_scheme  - output of build_params_multi_rate.m
%
%  Outputs
%    codedBits - encoded bitstream for this scheme at this rate
%    p         - the fully-resolved (rate + modulation adjusted) params
%                 struct used for this frame -- the CALLER MUST pass
%                 this same struct to ofdm_modulate.m / ofdm_demodulate.m
%    N, K      - this (scheme,rate)'s codeword/info-block length

    p = apply_coding_rate(params_by_scheme, scheme, rate_key);

    switch scheme
        case 'LDPC'
            codedBits = ldpcEncode(infoBits, p.encCfg);
        case 'Polar'
            codedBits = polar_encode(infoBits, p);
        case 'Turbo'
            codedBits = turbo_encode(infoBits, p);
        case 'Conv'
            codedBits = conv_encode(infoBits, p);
        otherwise
            error('adaptive_encode: unknown scheme "%s". Use LDPC | Polar | Turbo | Conv.', scheme);
    end

    N = p.N;
    K = p.K;

    p = set_modulation_order(p, modulation);

end
