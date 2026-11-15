function eq_syms = equalizer(rx_used, H_full, method, noise_var)
%EQUALIZER  Frequency-domain single-tap OFDM equalizer.
%
%  After OFDM demodulation each subcarrier k satisfies:
%       Y(k) = H(k) * X(k) + N(k)
%  A single-tap equalizer estimates X(k) as:
%       X_hat(k) = W(k) * Y(k)
%
%  Methods
%  -------
%  'ZF'    – Zero Forcing
%               W(k) = 1 / H(k)
%               Inverts the channel perfectly but amplifies noise in
%               deep fades (poor performance at low SNR).
%
%  'MMSE'  – Minimum Mean Square Error
%               W(k) = H*(k) / (|H(k)|^2 + sigma^2)
%               Balances channel inversion and noise suppression.
%               Reduces to ZF as SNR → ∞.
%
%  'MRC'   – Maximum Ratio Combining (single-antenna matched filter)
%               W(k) = H*(k) / |H(k)|^2
%               Maximises SNR per subcarrier; equivalent to MF.
%               Same as MMSE when sigma^2 → 0.
%
%  Inputs
%  ------
%    rx_used   – received freq-domain vector on N_used subcarriers (column)
%    H_full    – channel estimate on N_used subcarriers (column)
%    method    – 'ZF' | 'MMSE' | 'MRC'
%    noise_var – noise variance sigma^2 (required for MMSE; ignored for ZF/MRC)
%
%  Output
%  ------
%    eq_syms   – equalized complex symbols (column, same size as rx_used)

    rx_used = rx_used(:);
    H_full  = H_full(:);
    sigma2  = max(noise_var, 1e-9);    % safety floor

    switch upper(method)

        %% --------------------------------------------------------
        case 'ZF'
        % W(k) = 1 / H(k)
        % Regularise with tiny epsilon to avoid divide-by-zero in deep fades
        epsilon = 1e-9;
        W = 1 ./ (H_full + epsilon * sign(real(H_full) + 1e-15));
        eq_syms = W .* rx_used;

        %% --------------------------------------------------------
        case 'MMSE'
        % W(k) = H*(k) / (|H(k)|^2 + sigma^2)
        H_abs2  = abs(H_full).^2;
        W = conj(H_full) ./ (H_abs2 + sigma2);
        eq_syms = W .* rx_used;

        %% --------------------------------------------------------
        case 'MRC'
        % W(k) = H*(k) / |H(k)|^2   (matched filter)
        H_abs2  = abs(H_full).^2;
        W = conj(H_full) ./ (H_abs2 + 1e-9);
        eq_syms = W .* rx_used;

        otherwise
            error('equalizer: unknown method "%s". Use ''ZF'', ''MMSE'', or ''MRC''.', method);
    end
end
