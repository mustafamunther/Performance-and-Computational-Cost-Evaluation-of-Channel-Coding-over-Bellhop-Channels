function [rx, delay] = uwa_channel_apply_doppler(tx, h, SNR, fd, Fs)
%UWA_CHANNEL_APPLY_DOPPLER  Static multipath (h) + AWGN + a Doppler
%  frequency shift, for a FIXED range/distance link.
%
%  [rx, delay] = uwa_channel_apply_doppler(tx, h, SNR, fd, Fs)
%
%  This project's original uwa_channel_apply.m has NO Doppler at all
%  (just conv(tx,h) + AWGN) -- the adaptive system needs Doppler as a
%  genuine, varying quantity to make decisions about, so this adds it
%  explicitly. Since the LINK DISTANCE is fixed (no large-scale range
%  change), the Doppler modeled here represents small-scale relative
%  motion at that fixed range (platform drift, wave/current-induced
%  motion) as a single per-frame frequency shift -- not the
%  full path-geometry Bellhop Doppler model used in the larger
%  OFDM_Project (that model's per-path angles/delays are not part of
%  this simpler harness's inputs). This is a reasonable, explicitly
%  simplified stand-in sufficient to make Doppler a real decision input
%  for the adaptive system, not a research-grade physical channel model.
%
%  Inputs
%    tx   - transmit time-domain signal (column vector)
%    h    - channel impulse response (static multipath taps)
%    SNR  - SNR in dB ('measured' convention, as in uwa_channel_apply.m)
%    fd   - Doppler shift for this frame (Hz); can be positive or
%           negative, representing closing/opening relative motion
%    Fs   - sampling rate (Hz)
%
%  Outputs
%    rx    - received signal (multipath + Doppler + AWGN)
%    delay - synchronization reference = index (0-based) of the FIRST
%            significant tap (|h| >= 10% of the peak), NOT the strongest
%            one. uwa_channel_apply.m synchronizes to the strongest tap,
%            which is only correct when no strong arrival precedes it:
%            any strong tap EARLIER than the sync point makes the FFT
%            window run into the next symbol (ISI) even when that tap is
%            well inside the cyclic prefix's size. Synchronizing to the
%            earliest significant arrival keeps every later tap inside
%            the CP (see gate_cir_to_cp.m).

    tx = tx(:);
    rx_clean = conv(tx, h);

    t = (0:length(rx_clean)-1).' / Fs;
    rx_clean = rx_clean .* exp(1j*2*pi*fd*t);

    rx = awgn(rx_clean, SNR, 'measured');

    % First significant tap (earliest arrival carrying >= 10% of the
    % peak amplitude) -- see the 'delay' output note in the header.
    delay = find(abs(h) >= 0.1 * max(abs(h)), 1) - 1;

end
