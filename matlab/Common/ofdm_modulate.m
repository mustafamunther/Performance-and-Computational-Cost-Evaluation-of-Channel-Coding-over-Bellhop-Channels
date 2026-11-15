function tx_signal = ofdm_modulate(coded_bits, params)
%OFDM_MODULATE  Map coded bits → QAM symbols → OFDM time-domain signal.
%
%  Inputs:
%    coded_bits  – column vector of bits (length = params.num_coded_bits)
%    params      – system parameter struct (from get_system_params)
%
%  Output:
%    tx_signal   – complex baseband time-domain signal (column vector)

%% ---- Bit-to-Symbol Mapping ----
syms = bits_to_symbols(coded_bits, params.modulation, params.bits_per_sym);

%% ---- Build OFDM Frame ----
% Subcarrier indices: data + pilot interleaved on N_used subcarriers.
% We use fixed pilot positions for simplicity (LS channel estimation).
N_used   = params.N_used;
N_pilot  = params.N_pilot;
N_data   = N_used - N_pilot;   % = params.data_subs_per_sym
N_sym    = params.num_ofdm_syms;
N_fft    = params.N_fft;
N_cp     = params.N_cp;

pilot_idx = round(linspace(1, N_used, N_pilot));   % evenly spaced pilots
data_idx  = setdiff(1:N_used, pilot_idx);           % remaining = data

pilot_val = 1 + 1j*0;   % BPSK pilot known sequence

% Reshape data symbols into [N_data × N_sym]
needed = N_data * N_sym;
if length(syms) < needed
    syms = [syms; zeros(needed - length(syms), 1)];
else
    syms = syms(1:needed);
end
sym_matrix = reshape(syms, N_data, N_sym);

%% ---- IFFT Per Symbol ----
tx_signal = [];
guard_low  = floor((N_fft - N_used) / 2);   % lower guard bands

for s = 1 : N_sym
    freq_vec = zeros(N_fft, 1);

    % Map to subcarrier positions (center-zero ordering, skip DC)
    used_indices = guard_low + (1:N_used);
    freq_used = zeros(N_used, 1);
    freq_used(data_idx)  = sym_matrix(:, s);
    freq_used(pilot_idx) = pilot_val;

    freq_vec(used_indices) = freq_used;

    % IFFT + cyclic prefix
    td_sym = ifft(ifftshift(freq_vec), N_fft);
    cp     = td_sym(end - N_cp + 1 : end);
    tx_signal = [tx_signal; cp; td_sym];  %#ok<AGROW>
end

end

%% ---- Helper: bits → QAM symbols ----
function syms = bits_to_symbols(bits, mod_type, bps)
    bits = bits(:);
    % Pad to multiple of bps
    rem_bits = mod(length(bits), bps);
    if rem_bits ~= 0
        bits = [bits; zeros(bps - rem_bits, 1)];
    end
    n_syms = length(bits) / bps;
    syms   = zeros(n_syms, 1);

    switch mod_type
        case 'BPSK'
            syms = 1 - 2*bits;   % +1 / -1

        case 'QPSK'
            b = reshape(bits, 2, n_syms);
            % Gray-coded QPSK
            syms = (1 - 2*b(1,:)).' / sqrt(2) + 1j*(1 - 2*b(2,:)).' / sqrt(2);

        case '16QAM'
            b = reshape(bits, 4, n_syms);
            I = (1 - 2*b(1,:)) .* (2 - (1 - 2*b(2,:)));
            Q = (1 - 2*b(3,:)) .* (2 - (1 - 2*b(4,:)));
            syms = (I + 1j*Q).' / sqrt(10);

        case '64QAM'
            b   = reshape(bits, 6, n_syms);
            map = @(x3) (1-2*x3(1,:)).*(4-(1-2*x3(2,:)).*(2-(1-2*x3(3,:))));
            I   = map(b(1:3,:));
            Q   = map(b(4:6,:));
            syms = (I + 1j*Q).' / sqrt(42);

        otherwise
            error('Unknown modulation: %s', mod_type);
    end
end
