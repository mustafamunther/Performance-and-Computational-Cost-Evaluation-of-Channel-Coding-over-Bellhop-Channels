function [rx,delay] = uwa_channel_apply(tx,h,SNR)

rx = conv(tx,h);

rx = awgn(rx,SNR,'measured');

delay = find(abs(h)==max(abs(h)),1)-1;

end