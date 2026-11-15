function coded = polar_encode(bits, params)
%POLAR_ENCODE  Arikan polar encoder (non-systematic codeword).
%
%  coded = polar_encode(bits, params)
%
%  Inputs
%    bits   — information bits (column vector, 0/1)
%    params — get_system_params() structure
%             uses: params.N, params.K, params.polar_frozen
%             (params.polar_frozen is precomputed once in get_system_params.m
%              so encode and decode are guaranteed to use the identical mask)
%
%  Output
%    coded  — polar codeword(s), column vector of length n_blocks*N
%
%  Each K-bit info block is placed into the information positions of an
%  N-bit vector (frozen positions = 0), then transformed by the
%  recursive (u1 XOR u2, u2) Plotkin construction — equivalent to
%  multiplying by G_N = F^{\otimes n}, F = [1 0; 1 1].

bits = bits(:);
N = params.N;
K = params.K;

if isfield(params, 'polar_frozen') && ~isempty(params.polar_frozen)
    frozen = params.polar_frozen(:)';
else
    frozen = polar_construct(N, K, params.polar_design_snr);
end

%% ---- Pad info bits to a multiple of K ----
pad    = mod(-length(bits), K);
bits_p = [bits; zeros(pad,1)];
n_blk  = length(bits_p) / K;

coded  = zeros(n_blk * N, 1);

for b = 1:n_blk
    d = bits_p((b-1)*K + 1 : b*K);
    u = zeros(N,1);
    u(~frozen) = d;
    x = polar_transform(u);
    coded((b-1)*N + 1 : b*N) = x;
end

coded = coded(:);
end


%% ================================================================
%  Recursive Arikan polar transform: (u1 XOR u2, u2) Plotkin construction
%% ================================================================
function x = polar_transform(u)
    N = length(u);
    if N == 1
        x = u;
        return;
    end
    N2 = N/2;
    u1 = u(1:N2);
    u2 = u(N2+1:end);
    top = mod(u1 + u2, 2);
    x1  = polar_transform(top);
    x2  = polar_transform(u2);
    x   = [x1; x2];
end
