function [lo, hi, rule3] = rev_ci(k, n)
% 95% Clopper-Pearson interval for k errors in n bits (base MATLAB only),
% plus the rule-of-three bound 3/n that applies when k == 0.
    a = 0.05;
    if k == 0, lo = 0; else, lo = betaincinv(a/2, k, n-k+1); end
    if k == n, hi = 1; else, hi = betaincinv(1-a/2, k+1, n-k); end
    rule3 = 3 / n;
end
