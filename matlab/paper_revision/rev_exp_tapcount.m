function out = rev_exp_tapcount(cfg)
% Reviewer items R1-3, R1-4, R1-5, R2-3, R1-9, R2-6, R1-10.
% Sweeps: channel x CP-gating (ISI-free vs residual ISI) x number of retained taps
% x scheme/rate x SNR.  Records coded BER, UNCODED BER, block errors, per-frame raw data,
% and 95% Clopper-Pearson intervals / rule-of-three bounds.
% Usage (from the project root):  out = rev_exp_tapcount();   or pass a cfg struct.
    if nargin < 1, cfg = struct(); end
    d = struct('channels', {{'UWA_Communication.arr','UWA_10kHz_Complex.arr'}}, ...
               'ch_names', {{'Channel1_10km','Channel2_Complex'}}, ...
               'Ntaps', [5 10 15 30 Inf], 'gate', [true false], ...
               'cases', {{'LDPC','r1_3';'Polar','r1_3';'Turbo','r1_3';'Conv','r1_3'; ...
                          'LDPC','r1_2';'Polar','r1_2';'Conv','r1_2'}}, ...
               'modulation','QPSK', 'snr', [5 10 15 20], 'frames', 20, ...
               'fd', 0, 'Fs', 10000, 'paper_rx', false, 'sync', 'first', 'seed', 1, 'out_dir', 'paper_revision_results');
    f = fieldnames(d); for i = 1:numel(f), if ~isfield(cfg, f{i}), cfg.(f{i}) = d.(f{i}); end, end
    if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
    pbs = rev_setup();
    if cfg.paper_rx, pbs = rev_paper_receiver(pbs); end
    rev_env_info(fullfile(cfg.out_dir, 'env_info.mat'));
    N_cp = pbs.LDPC.N_cp;
    rows = {}; raw = struct('key', {}, 'err_post', {}, 'err_pre', {}, 'crc_ok', {}, 't_dec', {}, 'iters', {});
    for ci = 1:numel(cfg.channels)
      for gi = 1:numel(cfg.gate)
        for ti = 1:numel(cfg.Ntaps)
          [h, hi] = rev_make_channel(cfg.channels{ci}, cfg.Fs, cfg.Ntaps(ti), N_cp, cfg.gate(gi));
          for k = 1:size(cfg.cases, 1)
            sch = cfg.cases{k,1}; rk = cfg.cases{k,2};
            for si = 1:numel(cfg.snr)
              rng(cfg.seed*100003 + 1000*ci + 100*gi + 10*ti + k + si*7919);
              ep = zeros(cfg.frames,1); eq = ep; ok = ep; td = ep; it = ep; K = 0; N = 0;
              for fr = 1:cfg.frames
                r = rev_run_frame(sch, rk, cfg.modulation, pbs, h, cfg.snr(si), cfg.fd, cfg.Fs, cfg.sync);
                ep(fr) = r.err_post; eq(fr) = r.err_pre; ok(fr) = r.crc_ok; td(fr) = r.t_dec; it(fr) = r.iters;
                K = r.K; N = r.N;
              end
              nb = K*cfg.frames; nq = N*cfg.frames;
              [lo, hi_, r3] = rev_ci(sum(ep), nb);
              [lq, hq] = rev_ci(sum(eq), nq);
              rows(end+1,:) = {cfg.ch_names{ci}, cfg.gate(gi), cfg.Ntaps(ti), hi.power_kept_by_taps, hi.span_samples, ...
                  sch, rk, cfg.snr(si), cfg.frames, nb, sum(ep), sum(ep)/nb, lo, hi_, r3, ...
                  sum(eq)/nq, lq, hq, mean(1-ok), median(td), mean(it,'omitnan')}; %#ok<AGROW>
              raw(end+1) = struct('key', sprintf('%s|g%d|N%g|%s|%s|%g', cfg.ch_names{ci}, cfg.gate(gi), cfg.Ntaps(ti), sch, rk, cfg.snr(si)), ...
                  'err_post', ep, 'err_pre', eq, 'crc_ok', ok, 't_dec', td, 'iters', it); %#ok<AGROW>
              fprintf('%s gate=%d N=%g %s-%s %2d dB: BER=%.2e (95%%CI %.1e-%.1e) uncoded=%.2e BLER=%.2f\n', ...
                  cfg.ch_names{ci}, cfg.gate(gi), cfg.Ntaps(ti), sch, rk, cfg.snr(si), sum(ep)/nb, lo, hi_, sum(eq)/nq, mean(1-ok));
            end
          end
        end
        save(fullfile(cfg.out_dir, 'tapcount_partial.mat'), 'rows', 'raw', 'cfg');   % checkpoint
      end
    end
    T = cell2table(rows, 'VariableNames', {'channel','gated','Ntap','power_kept','span_samples', ...
        'scheme','rate','snr_dB','frames','info_bits','bit_errors','BER','BER_lo95','BER_hi95','rule_of_three', ...
        'BER_uncoded','unc_lo95','unc_hi95','BLER','median_dec_s','mean_ldpc_iters'});
    writetable(T, fullfile(cfg.out_dir, 'tapcount_results.csv'));
    save(fullfile(cfg.out_dir, 'tapcount_results.mat'), 'T', 'raw', 'cfg');
    out = T;
end
