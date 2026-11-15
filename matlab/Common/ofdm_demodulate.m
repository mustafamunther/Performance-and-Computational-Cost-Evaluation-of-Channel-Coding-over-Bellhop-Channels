function rx_llr = ofdm_demodulate(rx_signal, tx_signal, params, delay)
%OFDM_DEMODULATE  Remove CP → FFT → Channel Estimation → Equalization → Soft LLR.
%
%  Output:
%    rx_llr – soft LLR column vector (real-valued).
%             Convention: positive LLR → bit likely 0, negative → bit likely 1.
%             Length = N_data * N_sym * bps
%
%  -------- Channel-Weighted Soft LLR Design --------
%  For each data subcarrier k, the soft LLR is:
%
%      LLR_b0[k] = 2√2 · |H_LS[k]| · Re(ŷ_eq[k])
%      LLR_b1[k] = 2√2 · |H_LS[k]| · Im(ŷ_eq[k])
%
%  where H_LS[k] is the RAW LEAST-SQUARES channel estimate (NOT MMSE-smoothed).
%
%  WHY LS (not MMSE) for the LLR weights:
%    - MMSE channel estimator requires a noise_var estimate (σ²).
%    - The naive σ² = var(H_LS_pilots) measures CHANNEL SPREAD, not noise power,
%      so it is nearly constant with SNR → MMSE always over-smooths.
%    - Over-smoothing collapses |Ĥ[k]| to a near-uniform value across subcarriers.
%    - Uniform |Ĥ[k]| → uniform |LLR[k]| → polar SC g-function evaluates to
%      EXACTLY ZERO on every other butterfly → systematic BER = 0.5.
%    - LS estimates preserve the true Rayleigh-distributed amplitude variation
%      of |H[k]|: exponentially-distributed instantaneous SNR per subcarrier.
%    - Natural LLR magnitude variation (≈ 0.5 – 4×) makes g-function zeros
%      vanishingly rare, enabling correct polar SC decoding.
%
%  MMSE is still used for EQUALIZATION (not for LLR weights):
%    - noise_init is estimated from the ROUGHNESS of LS pilot estimates.
%      For a smooth channel: var(diff(H_LS_pilots)) ≈ 2 × noise_power.
%      This estimate correctly decreases with SNR, avoiding over-smoothing.
%    - MMSE equalization suppresses inter-symbol noise at low SNR.
%
%  LLR scale: sqrt(2) × |H_LS[k]| (NO noise_var divisor).
%    - At high SNR: Re(ŷ_eq) ≈ ±1/√2 → LLR ≈ ±2|H_LS[k]| ∈ [0.5, 4].
%      tanh(2) ≈ 0.96: well inside the log-sum-exp f-function's linear region.
%    - At low SNR: ŷ_eq is noisier → smaller effective LLR magnitude → correct
%      (less reliable signal → lower confidence → smaller |LLR|).
%    - No clamping required: LLRs are naturally bounded by Rayleigh amplitude.

N_fft   = params.N_fft;
N_cp    = params.N_cp;
N_used  = params.N_used;
N_pilot = params.N_pilot;
N_data  = N_used - N_pilot;
N_sym   = params.num_ofdm_syms;
bps     = params.bits_per_sym;
mod_type = params.modulation;

sym_len   = N_fft + N_cp;
guard_low = floor((N_fft - N_used) / 2);
used_idx  = guard_low + (1:N_used);
pilot_idx = round(linspace(1, N_used, N_pilot));
data_idx  = setdiff(1:N_used, pilot_idx);

%% ---- Per-OFDM-Symbol Processing ----
all_data_syms   = [];
all_chan_weights = [];
all_noise_vars  = [];

for s = 1 : N_sym

    %% Step 1 — Remove CP and FFT
    start_rx = delay + (s-1)*sym_len + N_cp + 1;
    if start_rx + N_fft - 1 > length(rx_signal)
        break;
    end
    td_rx   = rx_signal(start_rx : start_rx + N_fft - 1);
    fd_rx   = fftshift(fft(td_rx, N_fft));
    rx_used = fd_rx(used_idx);

    %% Step 2 — TX reference in frequency domain
    start_tx = (s-1)*sym_len + N_cp + 1;
    td_tx   = tx_signal(start_tx : start_tx + N_fft - 1);
    fd_tx   = fftshift(fft(td_tx, N_fft));
    tx_used = fd_tx(used_idx);

    %% Step 3 — LS channel estimate at pilot positions
    tx_pilot = tx_used(pilot_idx);
    rx_pilot = rx_used(pilot_idx);
    H_ls_pil = rx_pilot ./ (tx_pilot + 1e-12);

    %% Step 4 — Noise variance from pilot ROUGHNESS (not channel spread!)
    %
    %  For a smooth channel between adjacent pilots:
    %    diff(H_LS_pilots) ≈ diff(H_true) + diff(noise_pilots)
    %  If H_true is smooth: |diff(H_true)| << |diff(noise_pilots)|, so
    %    E[|diff(H_LS)|²] ≈ E[|diff(noise)|²] = 2 × noise_power
    %
    %  → noise_init ≈ mean(|diff(H_LS_pilots)|²) / 2
    %
    %  This correctly decreases with SNR (unlike the old channel-spread formula
    %  which was approximately constant with SNR).
    use_dft = isfield(params, 'est_method') && strcmpi(params.est_method, 'DFT');

    if use_dft
        % Time-domain least-squares estimate (see estimate_channel_dft.m):
        % channel AND noise variance come from the SAME pilot fit, so the
        % noise estimate keeps falling with SNR instead of saturating on
        % genuine channel variation (the failure of the roughness formula
        % below under real multipath).
        k_used = used_idx(:) - 1 - N_fft/2;
        [H_dft, noise_init] = estimate_channel_dft(rx_used, tx_used, pilot_idx, ...
                                                   k_used, N_fft, params.chan_est_taps);
        noise_init = max(noise_init, 1e-6);
    elseif length(H_ls_pil) >= 2
        noise_init = max(mean(abs(diff(H_ls_pil)).^2) / 2, 1e-4);
    else
        noise_init = 1e-2;
    end

    %% Step 5 — Channel estimation for EQUALIZATION (MMSE or LS per user setting)
    if use_dft
        H_full_eq = H_dft;
    else
        H_full_eq = channel_estimation(rx_used, tx_used, pilot_idx, ...
                                       N_used, params.est_method, noise_init);
    end

    %% Step 6 — Equalization
    eq_syms = equalizer(rx_used, H_full_eq, params.eq_method, noise_init);

    %% Step 7 — LS channel estimate for LLR WEIGHTS (always LS, never MMSE-smoothed)
    %  MMSE smoothing with imperfect noise_init homogenizes |H[k]| → uniform LLRs.
    %  LS estimate (interpolated from noisy pilots) preserves the true |H[k]|
    %  amplitude variation required by the polar SC decoder.
    if use_dft
        H_ls_full = H_dft;          % same time-domain estimate drives the LLR weights
    else
        H_ls_full = channel_estimation(rx_used, tx_used, pilot_idx, N_used, 'LS', 0);
    end
    H_ls_data   = H_ls_full(data_idx);
    chan_weights = abs(H_ls_data);   % Rayleigh-distributed: |H_LS[k]| ∈ [0.1, 4]

    %% Step 8 — Data symbols and noise estimate (diagnostic only)
    eq_data    = eq_syms(data_idx);
    ideal_syms = nearest_const_point(eq_data, mod_type);
    noise_var  = max(mean(abs(eq_data - ideal_syms).^2), 1e-4);

    %% Collect
    all_data_syms   = [all_data_syms;   eq_data];        %#ok<AGROW>
    all_chan_weights = [all_chan_weights; chan_weights];   %#ok<AGROW>
    all_noise_vars  = [all_noise_vars;  repmat(noise_var, N_data, 1)];   %#ok<AGROW>
end

%% ---- LS-Weighted Soft LLR ----
rx_llr = symbols_to_llr(all_data_syms, all_chan_weights, all_noise_vars, mod_type, bps);
% NOTE: the earlier per-call "LLR min/max/mean" print (useful while
% tracking down the 64QAM LLR-formula bug and the xcorr-delay crash) is
% removed here -- with those issues resolved and this function now
% called thousands of times per training run (36 actions x many
% realizations x SNR sweep), it produced an overwhelming amount of
% console output with real performance cost. If similar diagnostics are
% needed again, re-add them temporarily rather than leaving them on by
% default.
end


%% ================================================================
%  Helper: snap to nearest ideal constellation point
%% ================================================================
function ideal = nearest_const_point(syms, mod_type)
    syms = syms(:);
    switch mod_type
        case 'BPSK'
            ideal = sign(real(syms));
        case 'QPSK'
            ideal = (sign(real(syms)) + 1j*sign(imag(syms))) / sqrt(2);
        case '16QAM'
            I = real(syms)*sqrt(10);
            Q = imag(syms)*sqrt(10);
            I = sign(I).*(2*(abs(I)>2)+1);
            Q = sign(Q).*(2*(abs(Q)>2)+1);
            ideal = (I + 1j*Q)/sqrt(10);
        otherwise
            ideal = syms;
    end
end


%% ================================================================
%  Helper: LS-channel-weighted soft LLR demapper
%
%  LLR_b0[k] = 2√2 · |H_LS[k]| · Re(y_eq[k])      (no noise_var divisor)
%  LLR_b1[k] = 2√2 · |H_LS[k]| · Im(y_eq[k])
%
%  Scale = sqrt(2) × |H_LS[k]|.
%  At high SNR: Re(y_eq) ≈ ±1/√2 → |LLR| ≈ 2|H_LS| ∈ [0.2, 8].
%  tanh(4) ≈ 0.9993: still in the non-saturating region of the exact f-fn.
%  At low SNR: y_eq noisy → |LLR| reduced → less confident → correct.
%
%  KEY: dropping noise_var from the denominator prevents LLR saturation.
%  With noise_var → 1e-6 at high SNR, the old scale = |H|/1e-6 = 1e6 →
%  all LLRs clamped to ±25 → identical magnitude → Polar BER = 0.5.
%% ================================================================
function llr = symbols_to_llr(syms, weights, ~, mod_type, bps)
    %  Third argument (noise_vars) is intentionally ignored.
    %  LLR scale = sqrt(2) × |H_LS| (bounded, non-saturating).
    syms    = syms(:);
    weights = max(weights(:), 1e-4);   % |H_LS[k]|: avoid exact zero
    n       = length(syms);

    switch mod_type
        case 'BPSK'
            llr = 2 * weights .* real(syms);

        case 'QPSK'
            scale  = sqrt(2) * weights;        % per subcarrier
            b      = zeros(2, n);
            b(1,:) = 2 * real(syms).' .* scale.';
            b(2,:) = 2 * imag(syms).' .* scale.';
            llr    = b(:);

        case '16QAM'
            % FIX: the bit-2/bit-4 formulas (2-|A|) compare against the
            % NOMINAL constellation amplitudes (+-1,+-3). The previous
            % code built I = Re(sym)*sqrt(10)*|H|, i.e. it scaled the
            % amplitude by the channel weight BEFORE thresholding, so the
            % decision threshold moved to 2/|H| -- wrong whenever |H| != 1
            % (verified: 25% of bits wrong for |H| < ~0.67 even with
            % perfectly equalized, noiseless symbols). The perfect-channel
            % sanity test could not catch it because it has |H| = 1.
            % Correct form: evaluate on the unit-gain amplitude A and let
            % the reliability weight multiply the whole LLR.
            A      = real(syms) * sqrt(10);
            B      = imag(syms) * sqrt(10);
            w      = weights(:).';
            b      = zeros(4, n);
            b(1,:) =  w .* (2 * A.');
            b(2,:) =  w .* (2 - abs(A.'));
            b(3,:) =  w .* (2 * B.');
            b(4,:) =  w .* (2 - abs(B.'));
            llr    = b(:);

        case '64QAM'
            % FIX (found by sanity_test_rates.m: BER up to ~0.5 for
            % certain scheme/rate combos with 64QAM, even over a
            % PERFECT noiseless channel -- this modulation had never
            % actually been exercised in this project before, since
            % every original scheme folder defaulted to QPSK).
            %
            % This project's bits_to_symbols() 64QAM encoder maps the
            % 3 I-branch bits (x1,x2,x3) to amplitude |I| as:
            %   (x2,x3)=(0,0)->|I|=3   (0,1)->|I|=1
            %   (x2,x3)=(1,0)->|I|=5   (1,1)->|I|=7
            % (verified directly from bits_to_symbols' actual formula,
            % not assumed from a textbook mapping). For bit x3, the
            % correct (positive=0,negative=1) decision boundary is a
            % "tent" that is positive for |I| in {3,5} and negative for
            % |I| in {1,7}: f(|I|) = 2 - |#I#-4| gives f(1)=-1, f(3)=+1,
            % f(5)=+1, f(7)=-1 -- matching (x3=1,0,0,1) exactly, verified
            % by hand against all 4 cases. The previous formula used
            % "-6" instead of "-4", which is wrong for |I|=3 and |I|=7
            % (exactly half the constellation points) -- an always-wrong
            % LLR sign at a fixed bit position across an ENTIRE codeword,
            % which only a strong, low-rate code could fully correct
            % (matches the exact pattern seen in sanity_test_rates.m:
            % full failure for Polar's sequential SC decoder at every
            % rate, partial failure for LDPC/Conv only at their weaker,
            % higher-rate variants, and no failure anywhere at rate 1/3).
            % Same correction applies symmetrically to the Q-branch (b6).
            % Same weight-vs-threshold fix as 16QAM above: thresholds are
            % applied to the unit-gain amplitude, the weight multiplies
            % the LLR afterwards.
            A      = real(syms) * sqrt(42);
            B      = imag(syms) * sqrt(42);
            w      = weights(:).';
            b      = zeros(6, n);
            b(1,:) =  w .* (2 * A.');
            b(2,:) =  w .* (4 - abs(A.'));
            b(3,:) =  w .* (2 - abs(abs(A.') - 4));
            b(4,:) =  w .* (2 * B.');
            b(5,:) =  w .* (4 - abs(B.'));
            b(6,:) =  w .* (2 - abs(abs(B.') - 4));
            llr    = b(:);

        otherwise
            error('Unknown modulation: %s', mod_type);
    end

    llr = llr(:);
    
end
