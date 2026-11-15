function decodedBits = adaptive_decode(llr, scheme, rate_key, params_by_scheme)
%ADAPTIVE_DECODE  Dispatch to the chosen FEC scheme's own decoder, for
%  the (scheme, rate) pair the frame was actually encoded with.
%
%  decodedBits = adaptive_decode(llr, scheme, rate_key, params_by_scheme)
%
%  Inputs
%    llr               - channel LLRs for ONE codeword block (length =
%                         that (scheme,rate)'s N). Sign convention
%                         throughout this project: LLR > 0 -> bit likely
%                         0, LLR < 0 -> bit likely 1.
%    scheme            - 'LDPC' | 'Polar' | 'Turbo' | 'Conv'
%    rate_key          - MUST match the rate_key adaptive_encode.m used
%                         for this frame (see apply_coding_rate.m) --
%                         decoding at the wrong rate silently produces
%                         garbage rather than an error, exactly like a
%                         mismatched interleaver or frozen-bit mask.
%    params_by_scheme  - output of build_params_multi_rate.m
%
%  Output
%    decodedBits - hard-decoded information bits (this (scheme,rate)'s K bits)

    p = apply_coding_rate(params_by_scheme, scheme, rate_key);

    switch scheme
        case 'LDPC'
            decodedBits = ldpcDecode(llr, p.decCfg, p.ldpc_max_iter);
        case 'Polar'
            decodedBits = polar_decode(llr, p);
        case 'Turbo'
            decodedBits = turbo_decode(llr, p);
        case 'Conv'
            decodedBits = conv_decode(llr, p);
        otherwise
            error('adaptive_decode: unknown scheme "%s". Use LDPC | Polar | Turbo | Conv.', scheme);
    end

    decodedBits = double(decodedBits(:));

end
