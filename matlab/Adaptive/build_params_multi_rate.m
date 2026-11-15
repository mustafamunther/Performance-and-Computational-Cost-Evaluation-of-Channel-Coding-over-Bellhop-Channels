function params_by_scheme = build_params_multi_rate()
%BUILD_PARAMS_MULTI_RATE  Precompute every (scheme, rate) variant this
%  module actually supports, verified safe (see rate_support_notes.md /
%  README.md for the reasoning behind which rates were included/excluded).
%
%  params_by_scheme = build_params_multi_rate()
%
%  Supported rates, and WHY:
%    LDPC  : {1/3, 1/2, 2/3} -- dvbs2ldpc() natively supports these
%            (and other) DVB-S2 rates; N is FIXED at 64800 for all of
%            them (only K changes), so OFDM framing (num_ofdm_syms etc.)
%            does not need to change with rate.
%    Polar : {1/3, 1/2, 2/3} -- polar_construct(N,K,design_snr) already
%            takes K as a free parameter; N is fixed at 65536, so again
%            OFDM framing is unaffected by rate.
%    Conv  : {1/3, 1/2} -- realized as two DIFFERENT NATIVE trellises
%            (3 generator polynomials for 1/3, 2 for 1/2), NOT via
%            puncturing. This changes N (since N=(K+tail)/rate with K
%            fixed), so OFDM framing IS recomputed per rate here
%            (same recomputation set_modulation_order.m already does
%            for modulation changes).
%            A rate-2/3 option via puncturing was deliberately NOT
%            implemented: a correct puncture/depuncture implementation
%            requires exact block-length arithmetic (K+tail here is
%            ODD, so a puncture group of 4 does not divide it evenly --
%            exactly the kind of off-by-one alignment bug this project
%            spent an enormous debugging effort on earlier). Two solid,
%            exactly-verified native rates were judged more valuable
%            than three rates where one carries real, untested risk.
%    Turbo : {1/3} only -- comm.TurboEncoder's exact internal output bit
%            ordering (systematic/parity interleaving) was not something
%            that could be verified without live execution, and getting
%            this wrong in a puncture pattern would silently corrupt the
%            systematic bits the decoder depends on. Left at its single
%            native rate rather than risk a confidently-wrong puncturing
%            scheme (the first thing sanity_test_rates.m confirms is
%            that every variant actually included here round-trips
%            correctly -- do the same before trusting any future Turbo
%            rate extension).
%
%  Output: struct with fields .LDPC, .Polar, .Conv, .Turbo. Each of
%  .LDPC/.Polar/.Conv additionally has a .rates struct with one field
%  per supported rate key ('r1_3', 'r1_2', 'r2_3'), holding that rate's
%  N/K/(encCfg,decCfg | frozen | trellis). apply_coding_rate.m reads
%  from here; nothing else should call dvbs2ldpc/polar_construct/
%  poly2trellis directly for rate switching.

    %% ---- LDPC: N fixed at 64800, K varies with rate ----
    params_by_scheme.LDPC = get_params_ldpc();   % base struct (modulation, OFDM, etc.)
    ldpc_rates = struct('r1_3', 1/3, 'r1_2', 1/2, 'r2_3', 2/3);
    rate_keys = fieldnames(ldpc_rates);
    for i = 1:numel(rate_keys)
        key = rate_keys{i};
        rate = ldpc_rates.(key);
        H = dvbs2ldpc(rate);
        encCfg = ldpcEncoderConfig(H);
        decCfg = ldpcDecoderConfig(H);
        params_by_scheme.LDPC.rates.(key).rate = rate;
        params_by_scheme.LDPC.rates.(key).N = encCfg.BlockLength;
        params_by_scheme.LDPC.rates.(key).K = encCfg.NumInformationBits;
        params_by_scheme.LDPC.rates.(key).encCfg = encCfg;
        params_by_scheme.LDPC.rates.(key).decCfg = decCfg;
        fprintf('[build_params_multi_rate] LDPC %s: rate=%.3f N=%d K=%d\n', ...
            key, rate, encCfg.BlockLength, encCfg.NumInformationBits);
    end

    %% ---- Polar: N fixed at 65536, K varies with rate ----
    params_by_scheme.Polar = get_params_polar();
    N_polar = params_by_scheme.Polar.N;
    design_snr = params_by_scheme.Polar.polar_design_snr;
    polar_rates = struct('r1_3', 1/3, 'r1_2', 1/2, 'r2_3', 2/3);
    for i = 1:numel(rate_keys)
        key = rate_keys{i};
        rate = polar_rates.(key);
        K = round(rate * N_polar);
        frozen = polar_construct(N_polar, K, design_snr);
        params_by_scheme.Polar.rates.(key).rate = rate;
        params_by_scheme.Polar.rates.(key).N = N_polar;
        params_by_scheme.Polar.rates.(key).K = K;
        params_by_scheme.Polar.rates.(key).frozen = frozen;
        fprintf('[build_params_multi_rate] Polar %s: rate=%.3f N=%d K=%d\n', ...
            key, rate, N_polar, K);
    end

    %% ---- Conv: two NATIVE trellises (no puncturing) ----
    params_by_scheme.Conv = get_params_conv();
    K_conv = params_by_scheme.Conv.conv.K;   % 21845, fixed across both rates
    constraint = params_by_scheme.Conv.conv.constraint;
    tail = constraint - 1;

    params_by_scheme.Conv.rates.r1_3.rate = 1/3;
    params_by_scheme.Conv.rates.r1_3.generator = [171 133 165];
    params_by_scheme.Conv.rates.r1_3.trellis = poly2trellis(constraint, [171 133 165]);
    params_by_scheme.Conv.rates.r1_3.K = K_conv;
    params_by_scheme.Conv.rates.r1_3.N = (K_conv + tail) / (1/3);

    params_by_scheme.Conv.rates.r1_2.rate = 1/2;
    params_by_scheme.Conv.rates.r1_2.generator = [171 133];
    params_by_scheme.Conv.rates.r1_2.trellis = poly2trellis(constraint, [171 133]);
    params_by_scheme.Conv.rates.r1_2.K = K_conv;
    params_by_scheme.Conv.rates.r1_2.N = (K_conv + tail) / (1/2);

    fprintf('[build_params_multi_rate] Conv r1_3: N=%d K=%d\n', ...
        params_by_scheme.Conv.rates.r1_3.N, K_conv);
    fprintf('[build_params_multi_rate] Conv r1_2: N=%d K=%d\n', ...
        params_by_scheme.Conv.rates.r1_2.N, K_conv);

    %% ---- Turbo: single native rate only (see header) ----
    params_by_scheme.Turbo = get_params_turbo();
    params_by_scheme.Turbo.rates.r1_3.rate = params_by_scheme.Turbo.K / params_by_scheme.Turbo.N;
    params_by_scheme.Turbo.rates.r1_3.N = params_by_scheme.Turbo.N;
    params_by_scheme.Turbo.rates.r1_3.K = params_by_scheme.Turbo.K;
    fprintf('[build_params_multi_rate] Turbo r1_3 (native, only option): N=%d K=%d\n', ...
        params_by_scheme.Turbo.N, params_by_scheme.Turbo.K);

end
