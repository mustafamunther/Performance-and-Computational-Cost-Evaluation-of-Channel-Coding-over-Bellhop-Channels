function h_short = shorten_cir(h, Ntap)

% اختيار أقوى Ntap مسارات

[~, idx] = sort(abs(h), 'descend');

idx = sort(idx(1:Ntap));

h_short = zeros(max(idx),1);

h_short(idx) = h(idx);

% تطبيع الطاقة
h_short = h_short / norm(h_short);

end