function p = apply_coding_rate(params_by_scheme, scheme, rate_key)
%APPLY_CODING_RATE  Produce the per-frame params struct for a chosen
%  (scheme, rate) pair, using the variants precomputed ONCE by
%  build_params_multi_rate.m (rebuilding dvbs2ldpc/polar_construct every
%  frame would be far too slow, and risks the encoder/decoder silently
%  drifting out of sync if rebuilt independently on each side).
%
%  p = apply_coding_rate(params_by_scheme, scheme, rate_key)
%
%  Inputs
%    params_by_scheme - output of build_params_multi_rate.m
%    scheme            - 'LDPC' | 'Polar' | 'Turbo' | 'Conv'
%    rate_key           - 'r1_3' | 'r1_2' | 'r2_3' (Conv only has r1_3/r1_2;
%                         Turbo only has r1_3 -- see build_params_multi_rate.m
%                         header for why)
%
%  Output
%    p - params struct for this scheme at this rate, with .N, .K set,
%        plus (for LDPC) .encCfg/.decCfg, (for Polar) .polar_frozen,
%        (for Conv) .conv.trellis/.conv.generator -- and, for Conv ONLY
%        (since N changes with rate here, unlike LDPC/Polar where N is
%        fixed), .bits_per_ofdm/.num_ofdm_syms/.frame_bits recomputed
%        for the new N (same recomputation set_modulation_order.m does
%        for modulation changes)

    base = params_by_scheme.(scheme);

    if ~isfield(base.rates, rate_key)
        error('apply_coding_rate: scheme "%s" has no rate variant "%s". Supported: %s', ...
            scheme, rate_key, strjoin(fieldnames(base.rates), ', '));
    end
    rv = base.rates.(rate_key);

    p = base;

    switch scheme
        case 'LDPC'
            p.N = rv.N;
            p.K = rv.K;
            p.encCfg = rv.encCfg;
            p.decCfg = rv.decCfg;
            p.ldpc_rate = rv.rate;
            % N is fixed across LDPC rates -> OFDM framing unchanged.

        case 'Polar'
            p.N = rv.N;
            p.K = rv.K;
            p.polar_frozen = rv.frozen;
            p.polar_rate = rv.rate;
            % N is fixed across Polar rates -> OFDM framing unchanged.

        case 'Conv'
            p.N = rv.N;
            p.K = rv.K;
            p.conv.trellis = rv.trellis;
            p.conv.generator = rv.generator;
            p.conv.rate = rv.rate;
            % N DOES change with rate here (different native trellis) ->
            % recompute OFDM frame sizing, same formula
            % set_modulation_order.m uses for a modulation change.
            p.bits_per_ofdm = p.data_subs_per_sym * p.bits_per_sym;
            p.num_ofdm_syms = ceil(p.N / p.bits_per_ofdm);
            p.frame_bits    = p.num_ofdm_syms * p.bits_per_ofdm;

        case 'Turbo'
            p.N = rv.N;
            p.K = rv.K;
            % Single supported rate; nothing else to set.

        otherwise
            error('apply_coding_rate: unknown scheme "%s".', scheme);
    end

end
