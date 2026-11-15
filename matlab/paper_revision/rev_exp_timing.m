function out = rev_exp_timing(cfg)
% Reviewer items R1-1, R1-2, R1-6, R2-4: decoder-only timing with repeated trials,
% normalisation per information kbit and per OFDM symbol (channel use),
% LDPC iteration-count distribution and the 15 dB outlier rerun.
    if nargin < 1, cfg = struct(); end
    d = struct('arr', 'UWA_Communication.arr', 'snr_time', 12, 'n_rep', 30, ...
               'cases', {{'LDPC','r1_3';'Polar','r1_3';'Turbo','r1_3';'Conv','r1_3'; ...
                          'LDPC','r1_2';'Polar','r1_2';'Conv','r1_2'}}, ...
               'iter_snr', [5 10 15 20], 'iter_frames', 50, 'outlier_reps', 50, ...
               'Fs', 10000, 'paper_rx', false, 'sync', 'first', 'seed', 1, 'out_dir', 'paper_revision_results');
    f = fieldnames(d); for i = 1:numel(f), if ~isfield(cfg, f{i}), cfg.(f{i}) = d.(f{i}); end, end
    if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
    pbs = rev_setup();  if cfg.paper_rx, pbs = rev_paper_receiver(pbs); end
    rev_env_info(fullfile(cfg.out_dir, 'env_info.mat'));
    h = rev_make_channel(cfg.arr, cfg.Fs, 5, pbs.LDPC.N_cp, true);
    rng(cfg.seed);
    % ---- (1) decoder-only timing, repeated, with warm-up ----
    rows = {};
    for k = 1:size(cfg.cases,1)
        sch = cfg.cases{k,1}; rk = cfg.cases{k,2};
        p0 = apply_coding_rate(pbs, sch, rk);
        info = add_crc16(randi([0 1], p0.K-16, 1));
        [coded, p, N, K] = adaptive_encode(info, sch, rk, 'QPSK', pbs);
        tx = ofdm_modulate(coded, p);
        [rx, dl] = uwa_channel_apply_doppler(tx, h, cfg.snr_time, 0, cfg.Fs);
        llr = ofdm_demodulate(rx, tx, p, dl); llr = llr(1:N);
        adaptive_decode(llr, sch, rk, pbs);                                  % warm-up
        t = zeros(cfg.n_rep,1);
        for r = 1:cfg.n_rep, tic; adaptive_decode(llr, sch, rk, pbs); t(r) = toc; end
        q = quantile(t, [0.25 0.5 0.75]);
        rows(end+1,:) = {sch, rk, N, K, p.num_ofdm_syms, q(2), q(1), q(3), min(t), max(t), ...
                         1e3*q(2)/(K/1e3), 1e3*q(2)/p.num_ofdm_syms}; %#ok<AGROW>
        fprintf('%-6s %s N=%6d K=%6d syms=%4d  median %.4f s  IQR [%.4f %.4f]  %.2f ms/kbit\n', ...
                sch, rk, N, K, p.num_ofdm_syms, q(2), q(1), q(3), 1e3*q(2)/(K/1e3));
    end
    Tt = cell2table(rows, 'VariableNames', {'scheme','rate','N','K','ofdm_symbols','median_s','q25_s','q75_s','min_s','max_s','ms_per_info_kbit','ms_per_ofdm_symbol'});
    writetable(Tt, fullfile(cfg.out_dir, 'timing_decoder_only.csv'));
    % ---- (2) LDPC iteration distribution and stopping status ----
    rows = {};
    for rk = {'r1_3','r1_2'}
        for s = cfg.iter_snr
            it = zeros(cfg.iter_frames,1); okf = it; td = it;
            for fr = 1:cfg.iter_frames
                r = rev_run_frame('LDPC', rk{1}, 'QPSK', pbs, h, s, 0, cfg.Fs, cfg.sync);
                it(fr) = r.iters; okf(fr) = r.crc_ok; td(fr) = r.t_dec;
            end
            pmax = pbs.LDPC.ldpc_max_iter;
            rows(end+1,:) = {rk{1}, s, mean(it), median(it), max(it), mean(it >= pmax), mean(1-okf), median(td), max(td)}; %#ok<AGROW>
            fprintf('LDPC %s %2d dB: iters mean %.1f median %.0f max %d, hit-max %.2f, BLER %.2f, dec time median %.3f max %.3f\n', ...
                    rk{1}, s, rows{end,3:9});
        end
    end
    Ti = cell2table(rows, 'VariableNames', {'rate','snr_dB','iters_mean','iters_median','iters_max','frac_hit_max_iter','BLER','dec_median_s','dec_max_s'});
    writetable(Ti, fullfile(cfg.out_dir, 'ldpc_iterations.csv'));
    % ---- (3) the 15 dB outlier rerun (end-to-end timing, repeated) ----
    te = zeros(cfg.outlier_reps,1);
    for r = 1:cfg.outlier_reps
        x = rev_run_frame('LDPC', 'r1_2', 'QPSK', pbs, h, 15, 0, cfg.Fs, cfg.sync); te(r) = x.t_total;
    end
    q = quantile(te, [0.25 0.5 0.75]);
    fprintf('LDPC r1/2 @15 dB end-to-end over %d reps: median %.3f s, IQR [%.3f %.3f], max %.3f s\n', cfg.outlier_reps, q(2), q(1), q(3), max(te));
    save(fullfile(cfg.out_dir, 'timing_results.mat'), 'Tt', 'Ti', 'te', 'cfg');
    out = struct('decoder_only', Tt, 'ldpc_iters', Ti, 'outlier_e2e', te);
end
