function bits_hat = bpsk_demod(rx)

bits_hat = rx < 0;

bits_hat = double(bits_hat);

end