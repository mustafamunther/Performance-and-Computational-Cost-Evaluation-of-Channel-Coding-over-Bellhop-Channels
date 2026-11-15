function tx = bpsk_mod(bits)

bits = bits(:);
sps = 8;

tx = repelem(bits,sps);
%tx = 1 - 2*bits;

end