function h = arrivals_to_cir(Arr, Fs)
%ARRIVALS_TO_CIR Convert Bellhop arrivals to discrete-time CIR
%
% Input:
%   Arr : structure returned by read_arrivals_asc
%   Fs  : Sampling frequency (Hz)
%
% Output:
%   h   : Complex discrete-time channel impulse response

A = Arr.A(:);          % Complex amplitudes
tau = Arr.delay(:);    % Arrival delays (seconds)

% جعل أول مسار عند الزمن صفر
tau = tau - min(tau);

% تحويل التأخير إلى رقم عينة
sampleDelay = round(tau * Fs);

% طول القناة
L = max(sampleDelay) + 1;

% إنشاء CIR
h = zeros(L,1);

for k = 1:length(A)
    h(sampleDelay(k)+1) = h(sampleDelay(k)+1) + A(k);
end

% تطبيع الطاقة
if norm(h) > 0
    h = h / norm(h);
end

end