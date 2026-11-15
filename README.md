# Performance and Computational Cost Evaluation of Representative Channel Coding Configurations over Bellhop Channels

Supporting material for the manuscript (International Journal of Intelligent Engineering and Systems, ID 20265939)
by Mustafa M. Mashkour and Ammar E. Abdelkareem, Al-Nahrain University.

The study benchmarks LDPC (DVB-S2), Polar (plain SC), Turbo and Convolutional (K = 7) codes in an OFDM link over two
ray-traced Bellhop channels, at code rates 1/3 and 1/2, using BER, per-frame execution time and throughput.

## Repository layout

| Path | Content |
|---|---|
| `channels/channel1/` | Bellhop arrivals file of Channel 1 (`UWA_Communication.arr`, 76 arrivals) |
| `channels/channel2/` | Bellhop environment, print and arrivals files of Channel 2 (`UWA_10kHz_Complex.*`, 143 arrivals) |
| `channels/CHANNELS.md` | Channel parameters, arrival statistics and tap-selection procedure |
| `channels/analyse_channels.py` | Python script that reads the `.arr` files, discretises delays to the 10 kHz grid, merges same-sample arrivals and reports retained-tap power |
| `matlab/Common/`, `matlab/Schemes/`, `matlab/Adaptive/` | OFDM chain, channel application, code implementations and parameter sets (only the files the experiments call) |
| `matlab/paper_revision/` | Experiment scripts: tap-count sensitivity (`rev_exp_tapcount.m`), decoder-only timing and LDPC iterations (`rev_exp_timing.m`), confidence intervals (`rev_ci.m`), environment logging (`rev_env_info.m`) |
| `matlab/*.arr` | Copies of the two arrivals files at the MATLAB project root, where the scripts expect them |
| `results/` | Data behind Table 4 (tap sensitivity) and the channel statistics |
| `figures/` | Plot script and the per-SNR curve data used for Figs. 1-3 (see "Known limitations") |

## Code configurations (Table 2 of the paper)

| Scheme | Rate | N | K |
|---|---|---|---|
| LDPC (DVB-S2, BP, <= 50 it.) | 1/3, 1/2 | 64,800 | 21,600, 32,400 |
| Polar (SC) | 1/3, 1/2 | 65,536, 32,768 | 21,845, 16,384 |
| Turbo (BCJR, 6 it.) | 1/3, 1/2 | 65,547, 64,812 | 21,845, 32,400 |
| Convolutional (K = 7, Viterbi) | 1/3, 1/2 | 65,553, 43,702 | 21,845, 21,845 |

Block lengths are native to each code and differ between schemes; only the rate-1/3 configurations are matched in
payload and channel uses (within about 1%). See Section 3.3 of the paper.

## Running the experiments (MATLAB R2024a, Communications Toolbox, Signal Processing Toolbox)

```matlab
cd matlab
addpath('paper_revision');
cfg = struct('frames',2,'snr',[10 20],'Ntaps',[5 Inf]);          % quick smoke test
T = rev_exp_tapcount(cfg);
R = rev_exp_timing(struct('n_rep',3,'iter_frames',3,'outlier_reps',3,'iter_snr',15));
```

Settings used for the paper's sensitivity runs (Section 4.3): the original receiver (8 pilots, MMSE estimation and equalisation),
residual ISI, strongest-tap synchronisation:

```matlab
cfg = struct('paper_rx',true,'gate',false,'sync','max','Ntaps',[5 10 15 30 Inf],'snr',[0 5 10 15 20],'frames',20);
T = rev_exp_tapcount(cfg);
```

Outputs are written to `paper_revision_results/` (CSV, MAT with raw per-frame data, and `env_info.mat`).
Full details of every option are in `matlab/paper_revision/README_paper_revision.txt`.

## Known limitations of this release

* The scripts that produced Table 3 and Figs. 1-3 (the SNR sweeps of the first submission) are not part of this release.
  Figs. 1-3 were redrawn from `figures/data/figure_data_digitised.csv`, which was read from the original figure images and is
  an approximation of the original per-SNR results, not the raw MATLAB output.
* The Bellhop environment file of Channel 1 is not included; its parameters are listed in `channels/CHANNELS.md`.
* Results depend on the MATLAB release, hardware and thread count (timings were measured on an Intel Core i7-4610M laptop,
  Windows 10, MATLAB R2024a Update 4, two computational threads).

## Citation

If you use this material, please cite the manuscript above (a DOI will be added after publication).
