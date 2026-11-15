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

## Raw results
`results/raw_mat/` holds the MATLAB result structs (SNR_dB_range, BER_vs_SNR, ExecutionTime, Throughput) for the four scenarios A (channel 1, rate 1/3), B (channel 1, rate 1/2), C (channel 2, rate 1/2) and D (channel 2, rate 1/3), one file per code (`<scenario>_<code>.mat`); `results/raw_results.csv` collects them. `figures/plot3_from_raw.py` draws Figs. 1-3 from the CSV. ExecutionTime and Throughput are means over 100 frames per SNR point. `figures/data/figure_data_digitised.csv` is the earlier digitised data, kept only for comparison; all curves agree with the raw files to within 0.015 in BER (except the Convolutional tail of scenario D, 0.0028 digitised against 0.0017 raw).

## Per-code MATLAB projects (rate 1/2, channel 1)
`matlab/projects_rate_half/{polar,turbo,conv}/` are the complete project folders as run for the rate-1/2 configuration on channel 1 (`UWA_Communication.arr`/`.env`): `get_system_params.m` sets the code parameters (Polar N = 32768, K = N/2; Turbo K = 32400 punctured to rate 1/2; Convolutional K = 21845, generators [171 133]), `main_channel_test.m` runs the BER sweep, and `main_channel_testWITHTIMEANDTHROUPUT.m` (`main_channel_test_WATHTIMEANDTHROUPUT.m` for Turbo) records per-frame time and throughput and saves the result struct. Their saved outputs are in `results/raw_mat/` (scenario B). The rate-1/3 and channel-2 runs use the same scripts with the parameters changed in `get_system_params.m` as listed in the paper (Table 2).

## LDPC project (rate 1/3, channel 1)
`matlab/projects_rate_third/ldpc/` is the complete LDPC project as run for scenario A: `get_system_params.m` sets `params.ldpc_rate = 1/3` (DVB-S2, N = 64800, K = 21600, belief propagation), `main_channel_test.m` runs the BER sweep on channel 1. It contains no per-frame timing script; the timing/throughput outputs of scenario A are in `results/raw_mat/A_ch1_r13_LDPC.mat`, and the timing wrapper used for the other codes is `main_channel_testWITHTIMEANDTHROUPUT.m` in `matlab/projects_rate_half/`.
