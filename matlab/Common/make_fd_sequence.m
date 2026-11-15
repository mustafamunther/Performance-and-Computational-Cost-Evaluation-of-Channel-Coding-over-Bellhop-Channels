function fd = make_fd_sequence(n, fd_range_hz, rho)
%MAKE_FD_SEQUENCE  Frame-to-frame Doppler sequence with persistence.
%  Gaussian-copula AR(1): the marginal of every fd(k) is UNIFORM on
%  fd_range_hz (same as training), but consecutive frames are correlated
%  with coefficient ~rho, so the fd_hat fed back after frame k is still
%  informative for frame k+1 (as in a real platform-drift scenario).
%  rho <= 0 reproduces the old independent-per-frame behaviour.
%
%  fd = make_fd_sequence(n, fd_range_hz, rho)   % 1 x n

    lo = fd_range_hz(1); hi = fd_range_hz(2);
    if nargin < 3 || isempty(rho) || rho <= 0
        fd = lo + (hi - lo) * rand(1, n);
        return;
    end
    rho = min(rho, 0.999);
    z = zeros(1, n);
    z(1) = randn();
    for k = 2:n
        z(k) = rho * z(k-1) + sqrt(1 - rho^2) * randn();
    end
    u = 0.5 * erfc(-z / sqrt(2));      % standard-normal CDF -> uniform(0,1)
    fd = lo + (hi - lo) * u;
end
