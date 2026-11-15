function frozen_flag = polar_construct(N, K, design_snr_dB)
%POLAR_CONSTRUCT  Reliability-based frozen-bit mask via Bhattacharyya recursion.
%
%  frozen_flag = polar_construct(N, K, design_snr_dB)
%
%  Inputs
%    N              — codeword length (must be a power of 2)
%    K              — number of information bits (K <= N)
%    design_snr_dB  — design SNR (dB) used to seed the Bhattacharyya
%                      parameter of the base BPSK-AWGN channel
%
%  Output
%    frozen_flag — logical row vector, length N.
%                  true  = frozen bit (fixed to 0)
%                  false = information bit
%
%  Method: Arikan's Bhattacharyya-parameter recursion
%     Z(2i-1) = 2*Z(i) - Z(i)^2      (synthetic channel gets WORSE)
%     Z(2i)   = Z(i)^2               (synthetic channel gets BETTER)
%  Lower Z => more reliable synthetic bit-channel => keep as information.
%
%  IMPORTANT: this ordering is paired with the (u1 XOR u2, u2) "Plotkin"
%  recursive construction used in polar_encode.m / polar_decode.m.
%  Do not change this recursion without updating those files too —
%  they must all agree on the same channel-splitting convention.

    if mod(log2(N), 1) ~= 0
        error('polar_construct: N must be a power of 2 (got N=%d).', N);
    end
    if K > N
        error('polar_construct: K (%d) cannot exceed N (%d).', K, N);
    end

    design_snr = 10^(design_snr_dB/10);
    z0 = exp(-design_snr);   % Bhattacharyya param of the underlying BPSK-AWGN channel

    Z = z0;
    while length(Z) < N
        Zn = zeros(1, 2*length(Z));
        Zn(1:2:end) = 2*Z - Z.^2;   % worse sub-channel
        Zn(2:2:end) = Z.^2;         % better sub-channel
        Z = Zn;
    end

    [~, idx]  = sort(Z);   % ascending: most reliable (lowest Z) first
    info_idx  = idx(1:K);

    frozen_flag = true(1, N);
    frozen_flag(info_idx) = false;
end
