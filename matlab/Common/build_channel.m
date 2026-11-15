function [h, distance_km, info] = build_channel(arr_file, Fs, N_cp, Ntap)
%BUILD_CHANNEL  Build the static multipath channel from a Bellhop
%  arrivals file: read arrivals -> CIR -> keep the Ntap strongest taps ->
%  gate to the CP window (see gate_cir_to_cp.m for why).
%
%  [h, distance_km, info] = build_channel(arr_file, Fs, N_cp, Ntap)
%
%  This is the ONE place the channel is constructed. Both
%  generate_adaptive_training_data.m (training) and main_adaptive_test.m
%  (evaluation) call it, so they can never silently use different
%  channels -- the kind of train/deploy mismatch that already cost
%  several debugging rounds in this project.
%
%  Inputs
%    arr_file - Bellhop .arr file (ASCII)
%    Fs       - sampling rate (Hz)
%    N_cp     - OFDM cyclic prefix length (samples), e.g. params.N_cp
%    Ntap     - number of strongest arrivals to keep before gating
%
%  Outputs
%    h            - gated, unit-energy CIR (first tap at delay 0)
%    distance_km  - link range from the arrivals file (Pos.r.r)
%    info         - gating info (see gate_cir_to_cp.m)

    [Arr, Pos] = read_arrivals_asc(arr_file);
    distance_km = Pos.r.r(1) / 1000;

    h_full  = arrivals_to_cir(Arr, Fs);
    h_short = shorten_cir(h_full, Ntap);
    [h, info] = gate_cir_to_cp(h_short, N_cp);

    fprintf('[build_channel] %s | range = %.3f km\n', arr_file, distance_km);
    fprintf('[build_channel] %d strongest taps spanned %d samples (N_cp = %d)\n', ...
        Ntap, info.orig_spread, N_cp);
    fprintf('[build_channel] gated to CP window: %d taps kept at offsets [%s], %.1f%% of energy\n', ...
        info.n_taps_kept, num2str(info.kept_offsets), 100*info.energy_kept);

end
