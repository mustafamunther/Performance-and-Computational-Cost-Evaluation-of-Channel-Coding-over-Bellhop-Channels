function params = get_params_ldpc()
%GET_SYSTEM_PARAMS  Returns all system-level parameters for the OFDM simulation.
%
%  All functions in this project read from this single structure so that
%  changing one value propagates consistently everywhere.
params.fbnet_train_frames = 1000;

%params.fbnet_train_snr = 10;
%% ---- OFDM Core Parameters ----
params.N_fft        = 64;       % FFT size (total subcarriers)
params.N_used       = 48;       % Data-bearing subcarriers (rest are guard / DC)
params.N_cp         = 16;       % Cyclic-prefix length (samples)
params.N_pilot      = 20;       % Pilot subcarriers per symbol. Was 8: too sparse to track a frequency-selective
                                % channel (pilot spacing must be <= N_fft/(2*delay_spread)); 20 > N_cp=16 taps
                                % so the time-domain estimator (est_method='DFT') is over-determined.
params.modulation   = 'QPSK';   % Constellation: 'BPSK' | 'QPSK' | '16QAM' | '64QAM'
params.bits_per_sym = 2;        % Bits per constellation symbol (QPSK → 2)

params.receiver = 'Baseline';    % choose :     'Baseline'    |'FBNet'| 'FBGRU'
%% LDPC Parameters
params.ldpc_rate = 1/3;
params.ldpc_max_iter = 50;

H = dvbs2ldpc(params.ldpc_rate);

params.N = size(H,2);
params.K = params.N - size(H,1);

%% ---- Channel Estimation & Equalization ----
% est_method  : 'LS'   – Least Squares (fast, no noise stats needed)
%               'MMSE' – Min. Mean Square Error (better at low SNR)
params.est_method  = 'DFT';    % time-domain LS fit (see Common/estimate_channel_dft.m); 'LS'/'MMSE' = old linear-interp paths
params.chan_est_taps = params.N_cp;   % taps estimated by 'DFT' = the most the CP can absorb (assumes nothing else about h)

% eq_method   : 'ZF'   – Zero Forcing  (simple inversion)
%               'MMSE' – Min. Mean Square Error (noise-aware)
%               'MRC'  – Maximum Ratio Combining (matched filter)
params.eq_method   = 'ZF';     % unbiased per-subcarrier equalization (biased MMSE shrinks 16/64QAM amplitudes);
                                % noise robustness comes from the |H|-weighted LLRs in ofdm_demodulate.m

%% ---- Doppler Compensation ----
% enable: set true to run doppler_compensation() before OFDM demodulation
params.doppler.enable = true;

%% ---- Advanced Doppler Channel Model ----
% use_advanced : true  → use advanced_doppler.m  (WSSUS for UAC, extended Jakes for RF)
%                false → use original apply_uac_channel / apply_rf_channel
params.adv_doppler.enable         = true;
params.adv_doppler.n_oscillators  = 32;     % Jakes oscillator count (higher = smoother PSD)
params.adv_doppler.K_rice         = 0;      % Rician K-factor for RF (0 = pure Rayleigh)

%% ---- Interleaver ----
% enable : true to insert bit interleaving between FEC encoder and OFDM mapper
% scheme : 'block' | 'random' | 'diagonal'
params.interleaver.enable      = true;
params.interleaver.scheme      = 'block';      % 'block'|'random'|'diagonal'
% block_cols = N_sym (14) NOT N_data (48).
% Rule: columns must span the TIME axis, rows span the FREQUENCY axis.
% With cols=N_sym: consecutive output bits come from the same subcarrier
% across all 14 OFDM symbols → a single-frequency deep fade hits at most
% 1 bit per N_sym-bit run in the decoded stream.
% cols=N_data=48 would group same-subcarrier bits TOGETHER — the opposite.
params.interleaver.block_cols  = 14;    % = num_ofdm_syms (time-axis interleaving)
params.interleaver.seed        = 1234;  % fixed seed for random interleaver

%% ---- CP Optimisation ----
% safety_margin : extra samples added on top of max channel delay spread
% N_cp_min / N_cp_max : hard limits (samples)
% round_pow2    : round result up to nearest power-of-2 for FFT alignment
params.cp.safety_margin = 4;
params.cp.N_cp_min      = 4;
params.cp.N_cp_max      = params.N_fft / 2;   % never exceed half the FFT size
params.cp.round_pow2    = false;




%% ---- Frame Structure ----
%params.num_ofdm_syms  = 14;     % OFDM symbols per frame (like LTE slot)
% Data subcarriers per frame (excluding pilots per symbol)
params.data_subs_per_sym = params.N_used - params.N_pilot;
params.bits_per_ofdm = params.data_subs_per_sym * params.bits_per_sym;
params.num_ofdm_syms = ceil(params.N / params.bits_per_ofdm);
params.coded_bits_per_frame = params.data_subs_per_sym * params.num_ofdm_syms ...
                               * params.bits_per_sym;
params.frame_bits = params.num_ofdm_syms * params.bits_per_ofdm;

fprintf('LDPC N = %d\n',params.N);
fprintf('LDPC K = %d\n',params.K);
fprintf('Bits/OFDM = %d\n',params.bits_per_ofdm);
fprintf('OFDM Symbols = %d\n',params.num_ofdm_syms);
fprintf('Frame Bits = %d\n',params.frame_bits);
%% ---- FEC Parameters ----
% --- Convolutional ---
params.conv.rate        = 1/2;          % Code rate
params.conv.constraint  = 7;            % Constraint length
params.conv.generator   = [171 133];    % Generator polynomials (octal, rate-1/2, K=7)
params.conv.tbdepth     = 5 * params.conv.constraint;  % Viterbi traceback depth

% --- Polar ---
params.polar.rate        = 1/2;
params.polar.design_snr  = 0;           % Design SNR (dB) for reliability ordering
% Code length is next power-of-2 >= 2*num_info_bits (set after info bits calculated)

% --- LDPC ---
%params.ldpc.rate         = 1/2;
% Use MATLAB's built-in DVB-S2 LDPC parity check matrix (648 × 324 at rate 1/2)
params.ldpc.block_length = 648;
params.ldpc.info_length  = 324;
% Decoder iterations
%params.ldpc.max_iter     = 50;

%% ---- Derived: num_info_bits ----
% Compute info bits based on the tightest constraint (LDPC block size).
% We pick a chunk size that is an integer multiple of all code block sizes.
params.ldpc_info   = params.ldpc.info_length;   % 324 bits per LDPC block

% How many LDPC blocks fit in one frame?
params.ldpc_blocks = floor(params.coded_bits_per_frame / params.ldpc.block_length);
if params.ldpc_blocks < 1
    params.ldpc_blocks = 1;
end
params.num_info_bits = params.ldpc_blocks * params.ldpc.info_length;

% Recompute coded bits to match exactly (pad/truncate later in FEC functions)
params.num_coded_bits = params.num_info_bits * 2;   % rate-1/2 for all schemes

%% ---- Channel: Underwater Acoustic (UAC) ----
%params.uac.sound_speed      = 1500;     % m/s
%params.uac.max_range_m      = 1000;     % Scenario range (m)
% Multipath taps (relative delays in samples, gains)
%params.uac.tap_delays       = [0, 8, 15, 22];   % samples
%params.uac.tap_gains        = [1, 0.6, 0.35, 0.2];
%params.uac.tap_gains        = params.uac.tap_gains / norm(params.uac.tap_gains);
% Doppler: slow platform motion ~2 knots → very small
%params.uac.doppler_fd       = 1;        % Hz (normalized, applied as freq offset)
%params.uac.sample_rate      = 24e3;     % Hz  (typical UAC system)
% Frequency-dependent attenuation factor (Thorp's formula approximation)
%params.uac.freq_atten       = true;

%% ---- Channel: RF (Rayleigh multipath) ----
%params.rf.sample_rate       = 20e6;        % Hz  (20 MHz LTE-like)
%params.rf.carrier_freq      = 2.4e9;       % Hz  (2.4 GHz ISM)
%params.rf.vehicle_speed_mps = 30;          % m/s (~108 km/h)
% Clarke's model Doppler
%params.rf.fd = params.rf.carrier_freq * params.rf.vehicle_speed_mps / 3e8;
% Multipath tap profile (ITU Pedestrian-B like, adapted)
%params.rf.tap_delays        = [0, 1, 3, 5];    % samples
%params.rf.tap_powers_dB     = [0, -1, -9, -10]; % dB
%params.rf.tap_gains         = 10.^(params.rf.tap_powers_dB / 20);
%params.rf.tap_gains         = params.rf.tap_gains / norm(params.rf.tap_gains);

end
