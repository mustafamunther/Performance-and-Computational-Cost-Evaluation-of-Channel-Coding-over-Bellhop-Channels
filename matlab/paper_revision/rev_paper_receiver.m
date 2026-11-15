function pbs = rev_paper_receiver(pbs)
% Switches the receiver to the settings of the original paper pipeline
% (get_system_params.m): 8 pilots/symbol, linear-interpolated MMSE channel estimation,
% MMSE equalisation. Use together with gate=false to reproduce residual-ISI operation.
    sc = fieldnames(pbs);
    for i = 1:numel(sc)
        p = pbs.(sc{i});
        p.N_pilot          = 8;
        p.data_subs_per_sym= p.N_used - p.N_pilot;      % 40 data subcarriers
        p.bits_per_ofdm    = p.data_subs_per_sym * p.bits_per_sym;
        p.est_method       = 'MMSE';
        p.eq_method        = 'MMSE';
        pbs.(sc{i}) = p;
    end
end
