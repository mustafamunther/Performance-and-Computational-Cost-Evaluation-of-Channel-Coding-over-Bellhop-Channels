function [h_g, info] = gate_cir_to_cp(h, N_cp)
%GATE_CIR_TO_CP  Keep only the part of a sparse channel impulse response
%  that the OFDM cyclic prefix can actually absorb, so the simulated link
%  is free of inter-symbol interference (ISI) by construction.
%
%  [h_g, info] = gate_cir_to_cp(h, N_cp)
%
%  WHY THIS EXISTS (found by inspecting the real taps, not assumed):
%  shorten_cir(h,5) keeps the 5 STRONGEST arrivals wherever they are in
%  time. For UWA_10kHz_Complex.arr they sit at sample offsets
%  [-127 -10 -8 0 +240] around the strongest one -- a 367-sample spread
%  against N_fft=64 / N_cp=16, i.e. the delay spread is ~23x the CP.
%  Worse, the receiver synchronized to the STRONGEST tap, although two
%  strong taps arrive EARLIER, which breaks the cyclic-prefix assumption
%  even for taps only 8-10 samples away. The result was a self-
%  interference floor (post-equalization SINR stuck near ~2 dB for any
%  true SNR, and BER floors of 1e-3..5e-2 in the fixed-scheme curves)
%  that no coding/modulation choice can remove -- the same CP-vs-delay-
%  spread mismatch found earlier in the large OFDM_Project.
%
%  METHOD: slide a window of N_cp+1 samples (offsets 0..N_cp, which is
%  exactly the range a CP of N_cp samples can absorb when the FFT window
%  is aligned to the window's first tap), pick the start tap that
%  captures the most energy, drop everything outside it, trim the
%  leading delay (absolute propagation delay is irrelevant to
%  communication), and renormalize to unit energy.
%
%  MODELING NOTE (state this in the thesis): the energy outside the
%  window is EXCLUDED from the simulated channel (info.energy_kept
%  reports what fraction survives). This is equivalent to assuming the
%  CP/numerology is sized to the dominant arrival cluster; it is a
%  simplification, not a claim that the discarded arrivals do not exist.
%
%  Inputs
%    h     - sparse CIR (complex column vector), e.g. from shorten_cir
%    N_cp  - cyclic prefix length in samples
%
%  Outputs
%    h_g  - gated CIR; first nonzero tap is at index 1 (delay 0)
%    info - struct: .energy_kept (0..1), .n_taps_kept, .start_idx
%           (0-based position of the window start in the original h),
%           .orig_spread (samples between first and last nonzero tap
%           of the input), .kept_offsets (tap offsets kept, samples)

    h = h(:);
    tap_idx = find(abs(h) > 0);
    total_E = sum(abs(h).^2);

    best_E = -1;
    best_s = tap_idx(1);
    for k = 1:numel(tap_idx)
        s = tap_idx(k);
        e = min(s + N_cp, numel(h));
        E = sum(abs(h(s:e)).^2);
        if E > best_E + 1e-12
            best_E = E;
            best_s = s;
        end
    end

    e = min(best_s + N_cp, numel(h));
    h_g = h(best_s:e);
    last = find(abs(h_g) > 0, 1, 'last');
    h_g = h_g(1:last);
    h_g = h_g / norm(h_g);

    info.energy_kept  = best_E / total_E;
    info.n_taps_kept  = nnz(abs(h_g) > 0);
    info.start_idx    = best_s - 1;
    info.orig_spread  = tap_idx(end) - tap_idx(1);
    info.kept_offsets = (find(abs(h_g) > 0) - 1).';

end
