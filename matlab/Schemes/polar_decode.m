function bits = polar_decode(llr, params)
%POLAR_DECODE  Successive-Cancellation (min-sum) polar decoder.
%
%  bits = polar_decode(llr, params)
%
%  Inputs
%    llr    — channel LLRs, N per block (column vector)
%             sign convention: LLR > 0 -> bit likely 0, LLR < 0 -> bit likely 1
%             (matches the convention already used by ofdm_demodulate.m /
%              symbols_to_llr.m in this project)
%    params — get_system_params() structure
%             uses: params.N, params.K, params.polar_frozen
%
%  Output
%    bits   — hard-decoded information bits (K bits per block x n_blocks)
%
%  NOTE: the recursive split here MUST match polar_encode.m's
%  (u1 XOR u2, u2) construction exactly, INCLUDING the re-encoding step
%  used to reconstruct 'a_hat' before the g-function. Skipping that
%  re-encode step is the single most common polar-SC-decoder bug —
%  it was caught and fixed during development of this file via a
%  noiseless round-trip test (encode -> decode must recover the exact
%  input with no frozen bits set, and did not until the fix was applied).

llr = llr(:);
N = params.N;
K = params.K;

if isfield(params, 'polar_frozen') && ~isempty(params.polar_frozen)
    frozen = params.polar_frozen(:)';
else
    frozen = polar_construct(N, K, params.polar_design_snr);
end

pad   = mod(-length(llr), N);
llr_p = [llr; zeros(pad,1)];
n_blk = length(llr_p) / N;

bits = zeros(n_blk * K, 1);

for b = 1:n_blk
    L     = llr_p((b-1)*N + 1 : b*N);
    u_hat = sc_decode(L, frozen(:)');
    bits((b-1)*K + 1 : b*K) = u_hat(~frozen);
end

bits = bits(:);
end


%% ================================================================
%  Recursive min-sum SC decoder (matches the (u1^u2, u2) Plotkin encoder)
%% ================================================================
function u_hat = sc_decode(llr, frozen)
    N = length(llr);
    if N == 1
        if frozen(1)
            u_hat = 0;
        else
            u_hat = double(llr(1) < 0);
        end
        return;
    end
    N2 = N/2;
    a = llr(1:N2);
    b = llr(N2+1:end);

    %% -- f-function: min-sum approximation of box-plus, for the top branch --
    llr_top = sign(a) .* sign(b) .* min(abs(a), abs(b));
    u1 = sc_decode(llr_top, frozen(1:N2));

    %% -- re-encode u1 to reconstruct the codeword bits 'a_hat' --
    %  (u1 itself is NOT the codeword — it must be re-transformed)
    a_hat = polar_transform_local(u1(:));

    %% -- g-function for the bottom branch, using a_hat (not u1) --
    llr_bot = b + (1 - 2*a_hat) .* a;
    u2 = sc_decode(llr_bot, frozen(N2+1:end));

    u_hat = [u1(:); u2(:)];
end


%% ---- local copy of the polar transform (keeps this file self-contained) ----
function x = polar_transform_local(u)
    N = length(u);
    if N == 1
        x = u;
        return;
    end
    N2 = N/2;
    u1 = u(1:N2);
    u2 = u(N2+1:end);
    top = mod(u1 + u2, 2);
    x1  = polar_transform_local(top);
    x2  = polar_transform_local(u2);
    x   = [x1; x2];
end
