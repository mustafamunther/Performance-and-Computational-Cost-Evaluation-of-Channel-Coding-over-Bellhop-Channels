function [encCfg, decCfg, N, K] = ldpc_setup(params)

H = dvbs2ldpc(params.ldpc_rate);

encCfg = ldpcEncoderConfig(H);
decCfg = ldpcDecoderConfig(H);

N = encCfg.BlockLength;
K = encCfg.NumInformationBits;

fprintf('LDPC setup: N=%d K=%d Rate=%.2f\n',N,K,K/N);

end