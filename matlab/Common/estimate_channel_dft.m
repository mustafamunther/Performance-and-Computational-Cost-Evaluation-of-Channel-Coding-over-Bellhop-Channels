function [H_full, noise_var, h_taps] = estimate_channel_dft(rx_used, tx_used, pilot_idx, k_used, N_fft, L)
%ESTIMATE_CHANNEL_DFT  Pilot-based channel estimation in the TIME domain.
%
%  [H_full, noise_var, h_taps] = estimate_channel_dft(rx_used, tx_used, ...
%                                      pilot_idx, k_used, N_fft, L)
%
%  WHY (verified by simulation before being written -- see README):
%  the previous estimator interpolated pilot LS values LINEARLY across
%  frequency. With 8 pilots over 48 subcarriers (spacing ~6.7) and a
%  multipath channel whose frequency response oscillates with a period of
%  only ~N_fft/delay_spread (~6 subcarriers here), that is aliased: even
%  with NO noise the raw QPSK BER was ~0.18, and no modulation above
%  BPSK/QPSK-rate-1/3 could ever succeed, whatever the SNR.
%
%  A CIR that fits inside the cyclic prefix has at most L = N_cp taps, so
%  the frequency response across ALL subcarriers is determined by L
%  complex numbers. We fit those L taps to the pilot LS estimates by
%  (slightly regularized) least squares and evaluate the model at every
%  used subcarrier. This needs N_pilot > L to be over-determined; with
%  20 pilots and L = 16 simulation gave raw QPSK BER ~3e-4 at 20 dB.
%
%  NOISE VARIANCE (replaces the pilot-"roughness" estimate): the fit
%  residual over the pilots contains only noise once the model covers the
%  channel, so  noise_var = ||H_ls_pilot - F*h||^2 / (N_pilot - L)  is an
%  unbiased estimate of the per-subcarrier noise power (pilot power = 1)
%  that keeps shrinking as SNR grows -- unlike the roughness estimate,
%  which is dominated by genuine channel variation and saturates.
%
%  Inputs
%    rx_used, tx_used - received / known-transmitted frequency-domain
%                       vectors on the N_used active subcarriers
%    pilot_idx        - pilot positions within the N_used grid
%    k_used           - signed frequency index (relative to DC) of each
%                       active subcarrier, N_used x 1, e.g. for the
%                       fftshift layout used here:
%                       k_used = used_idx(:) - 1 - N_fft/2
%    N_fft            - FFT size
%    L                - number of time-domain taps to estimate (use N_cp)
%
%  Outputs
%    H_full    - channel estimate on all N_used subcarriers (column)
%    noise_var - per-subcarrier noise variance estimate (scalar)
%    h_taps    - the L estimated time-domain taps (column), useful for a
%                delay-spread estimate

    rx_used   = rx_used(:);
    tx_used   = tx_used(:);
    pilot_idx = pilot_idx(:);
    k_used    = k_used(:);

    H_ls_pil = rx_used(pilot_idx) ./ (tx_used(pilot_idx) + 1e-12);

    m = 0:L-1;
    F_pil = exp(-1j*2*pi*k_used(pilot_idx)*m / N_fft);     % N_pilot x L
    F_all = exp(-1j*2*pi*k_used*m / N_fft);                % N_used  x L

    lambda = 1e-3;                                         % tiny ridge for conditioning
    h_taps = (F_pil' * F_pil + lambda*eye(L)) \ (F_pil' * H_ls_pil);

    H_full = F_all * h_taps;

    dof = max(numel(pilot_idx) - L, 1);
    noise_var = sum(abs(H_ls_pil - F_pil*h_taps).^2) / dof;
    noise_var = max(noise_var, 1e-9);

end
