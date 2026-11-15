function [h, info] = rev_make_channel(arr_file, Fs, Ntap, N_cp, do_gate)
% Channel construction with explicit control of the number of retained taps
% (Ntap = Inf keeps the full discretised response) and of CP gating.
%   do_gate = true : response cut to the CP window (ISI-free link, thesis pipeline)
%   do_gate = false: response kept as is (residual ISI beyond the CP, paper-like)
    [Arr, Pos] = read_arrivals_asc(arr_file);
    h_full = arrivals_to_cir(Arr, Fs);
    n_nz   = nnz(abs(h_full) > 0);
    if isinf(Ntap) || Ntap >= n_nz
        h_s = h_full / norm(h_full);  Ntap_eff = n_nz;
    else
        h_s = shorten_cir(h_full, Ntap);  Ntap_eff = Ntap;
    end
    if do_gate
        [h, g] = gate_cir_to_cp(h_s, N_cp);
        info.energy_kept_by_gate = g.energy_kept;
    else
        h = h_s;  info.energy_kept_by_gate = 1;
    end
    P = abs(h_full).^2;
    info.power_kept_by_taps = sum(P(abs(h_s) > 0)) / sum(P);
    info.n_taps      = nnz(abs(h) > 0);
    info.Ntap_eff    = Ntap_eff;
    info.span_samples= find(abs(h) > 0, 1, 'last') - find(abs(h) > 0, 1, 'first');
    info.range_km    = Pos.r.r(1) / 1000;
end
