function H_full = channel_estimation(rx_used, tx_used, pilot_idx, N_used, method, noise_var)
%CHANNEL_ESTIMATION  Pilot-based frequency-domain channel estimation.
%
%  Estimates the channel frequency response H on all used subcarriers
%  from known pilot positions, then interpolates across data subcarriers.
%
%  Methods
%  -------
%  'LS'   – Least Squares
%             H_p = Y_p / X_p   (element-wise division at pilot positions)
%             Simple, no noise statistics needed.
%
%  'MMSE' – Minimum Mean Square Error (linear MMSE)
%             H_mmse = R_hh * (R_hh + (1/SNR)*I)^{-1} * H_LS
%             Exploits channel correlation to suppress noise.
%             Requires noise_var (= sigma^2) estimate.
%
%  Inputs
%  ------
%    rx_used   – received frequency-domain symbols on N_used subcarriers
%    tx_used   – transmitted freq-domain symbols (known at RX)
%    pilot_idx – indices of pilot subcarriers within the N_used grid
%    N_used    – total number of active subcarriers
%    method    – 'LS' or 'MMSE'
%    noise_var – noise variance estimate (required for MMSE; ignored for LS)
%
%  Output
%  ------
%    H_full    – complex channel estimate on all N_used subcarriers (column)

    rx_used   = rx_used(:);
    tx_used   = tx_used(:);
    pilot_idx = pilot_idx(:);
    N_p       = length(pilot_idx);

    %% ---- Step 1: LS estimate at pilot positions ----
    % H_ls(k) = Y(k) / X(k)   for each pilot k
    H_ls_pilot = rx_used(pilot_idx) ./ (tx_used(pilot_idx) + 1e-12);

    %% ---- Step 2: Method-specific refinement ----
    switch upper(method)

        %% --------------------------------------------------------
        case 'LS'
        % No refinement: just interpolate LS pilots to all subcarriers.
        H_pilot_final = H_ls_pilot;

        %% --------------------------------------------------------
        case 'MMSE'
        % Linear MMSE at pilot positions:
        %   H_mmse = R_HH * (R_HH + sigma^2 * (X^H X)^{-1})^{-1} * H_ls
        %
        % For OFDM with uniform pilots we approximate:
        %   R_HH = channel auto-correlation matrix (Sinc-based for uniform PDP)
        %   (X^H X)^{-1} ≈ I  (pilots have unit power |x_p|=1)
        %
        % Result: H_mmse = R_HH * (R_HH + sigma^2 * I)^{-1} * H_ls

        % Build pilot-to-pilot correlation matrix R_pp
        % Using sinc model: R(k,l) = sinc(k-l) * exp(-j*pi*(k-l))
        % (flat PDP approximation — replace with measured PDP for accuracy)
        R_pp = zeros(N_p, N_p);
        for ki = 1 : N_p
            for kj = 1 : N_p
                delta = pilot_idx(ki) - pilot_idx(kj);
                R_pp(ki,kj) = sinc(delta / N_used) * exp(-1j*pi*delta/N_used);
            end
        end
        % Regularized MMSE inversion
        sigma2 = max(noise_var, 1e-6);
        W = R_pp / (R_pp + sigma2 * eye(N_p));
        H_pilot_final = W * H_ls_pilot;

        otherwise
            error('channel_estimation: unknown method "%s". Use ''LS'' or ''MMSE''.', method);
    end

    %% ---- Step 3: Interpolate to all used subcarriers ----
    % Linear interpolation with nearest-neighbour extrapolation at edges
    all_idx  = (1 : N_used).';
    H_full   = interp1(double(pilot_idx), H_pilot_final, all_idx, ...
                       'linear', 'extrap');
    H_full   = H_full(:);
end
