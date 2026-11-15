function r = rev_run_frame(scheme, rk, modulation, pbs, h, snr_db, fd, Fs, sync)
% One full frame: payload+CRC -> encode -> OFDM -> channel -> demod -> decode.
% Returns coded/uncoded error counts, CRC status, decoder-only and end-to-end time,
% and the LDPC iteration count (NaN for other schemes).
    if nargin < 9 || isempty(sync), sync = 'first'; end
    t_all = tic;
    p0      = apply_coding_rate(pbs, scheme, rk);
    payload = randi([0 1], p0.K - 16, 1);
    info    = add_crc16(payload);
    [coded, p, N, K] = adaptive_encode(info, scheme, rk, modulation, pbs);
    tx = ofdm_modulate(coded, p);
    [rx, delay] = uwa_channel_apply_doppler(tx, h, snr_db, fd, Fs);
    if strcmpi(sync, 'max')      % synchronise on the strongest tap (as uwa_channel_apply does)
        delay = find(abs(h) == max(abs(h)), 1) - 1;
    end
    llr = ofdm_demodulate(rx, tx, p, delay);
    llr = llr(:);
    if numel(llr) < N, llr = [llr; zeros(N - numel(llr), 1)]; end
    llr = llr(1:N);

    r.err_pre   = sum((llr < 0) ~= (coded(1:N) > 0));      % uncoded (pre-decoding) hard-decision errors
    r.n_pre     = N;
    r.iters     = NaN;
    t_dec = tic;
    if strcmp(scheme, 'LDPC')
        [dec, it] = ldpcDecode(llr, p.decCfg, p.ldpc_max_iter);
        r.iters = double(it);
        dec = double(dec(:));
    else
        dec = adaptive_decode(llr, scheme, rk, pbs);
    end
    r.t_dec = toc(t_dec);
    dec = dec(1:K);
    r.err_post = sum(dec ~= info(1:K));
    r.n_post   = K;
    r.crc_ok   = check_crc16(dec);
    r.t_total  = toc(t_all);
    r.N = N; r.K = K; r.n_ofdm_syms = p.num_ofdm_syms;
end
