PAPER REVISION EXPERIMENTS (IJIES 20265939)
Copy the folder paper_revision/ into the project root (next to Adaptive/, Common/, Schemes/), cd to the root, then:

  addpath('paper_revision');
  cfg = struct('frames',2,'snr',[10 20],'Ntaps',[5 Inf]);   % quick smoke test (a few minutes)
  T = rev_exp_tapcount(cfg);
  R = rev_exp_timing(struct('n_rep',3,'iter_frames',3,'outlier_reps',3,'iter_snr',15));

Full run (many hours; can be split across two computers with cfg.channels / cfg.ch_names / cfg.gate):
  T = rev_exp_tapcount();      % 2 channels x 2 gating x 5 tap counts x 7 cases x 4 SNR x 20 frames
  R = rev_exp_timing();

Outputs go to paper_revision_results/ (CSV + MAT with raw per-frame data + env_info.mat).
What each answers:
  tapcount_results.csv : R1-3 (BER vs tap count incl. full response), R1-4/R2-1 (both channels),
                         R1-5/R2-3 (uncoded BER; gated=ISI-free vs gated=0 residual-ISI),
                         R1-9/R2-6 (95% Clopper-Pearson CI, rule-of-three), R1-10 (raw per-frame in MAT)
  timing_decoder_only.csv : R1-1/R1-2/R2-4 (decoder-only, median+IQR, per info kbit, per OFDM symbol)
  ldpc_iterations.csv  : R1-6/R2-4 (iteration distribution, stopping status)
  env_info.mat         : R1-6 (MATLAB release, toolboxes, threads, CPU)
NOT covered (need separate work): SCL/CRC Polar baseline, perfect-CSI ablation, long-CP ablation, channel ensemble.
Caveats: uses this project's receiver (DFT estimator, 20 pilots, ZF) and rate-keys; the paper's own receiver
(8 pilots, 5 taps, residual ISI) is reproduced only approximately by gated=0 with Ntap=5. Turbo has only rate 1/3 here.
Matched payload: rate 1/3 has K=21600 (LDPC) vs 21845 (Polar/Conv/Turbo); at rate 1/2 K differs (32400/32768/21845),
so the timing CSV also reports ms per information kbit and per OFDM symbol.

UPDATE v1.1: cfg.paper_rx = true switches to the original paper receiver (8 pilots, MMSE estimation, MMSE equalisation),
taken from get_system_params.m. Intended use: cfg = struct('paper_rx',true,'gate',false,'Ntaps',[5 Inf],'snr',[0 5 10 15 20],'frames',20);

UPDATE v1.2: cfg.sync = 'max' synchronises on the STRONGEST tap (default 'first' = first tap above 10% of the maximum,
which is what uwa_channel_apply_doppler returns). With residual ISI ('gate' = false) 'first' puts the FFT window on a weak
precursor and the link collapses to BER ~0.5; use 'max'. Recommended:
  cfg = struct('paper_rx',true,'gate',false,'sync','max','Ntaps',[5 Inf],'snr',[0 5 10 15 20],'frames',5);
