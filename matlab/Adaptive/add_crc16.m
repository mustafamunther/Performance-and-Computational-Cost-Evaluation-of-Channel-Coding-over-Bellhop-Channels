function bits_with_crc = add_crc16(payload_bits)
%ADD_CRC16  Append a CRC-16-CCITT (polynomial 0x1021) to payload bits.
%
%  bits_with_crc = add_crc16(payload_bits)
%
%  This is deliberately independent of, and applied BEFORE, any FEC
%  scheme: a real receiver never has access to the true transmitted
%  information bits to measure "actual BER" against (that was the
%  unrealistic shortcut this module previously took for its feedback
%  signal). A CRC is the standard, scheme-agnostic way a real receiver
%  checks whether a decoded block is (very likely) correct -- it can
%  then report ACK/NACK, and a recent-frames NACK rate (BLER), as
%  genuine feedback -- see check_crc16.m / estimate_link_quality.m.
%
%  Input
%    payload_bits - column vector of 0/1 information bits
%
%  Output
%    bits_with_crc - [payload_bits; crc_bits] (16 extra bits appended)

    payload_bits = payload_bits(:);
    crc_bits = crc16_bits(payload_bits);
    bits_with_crc = [payload_bits; crc_bits];

end


function crc_bits = crc16_bits(bits)
%CRC16_BITS  Standard bitwise CRC-16-CCITT (poly 0x1021, init 0xFFFF).

    poly = uint16(hex2dec('1021'));
    crc  = uint16(hex2dec('FFFF'));

    for i = 1:length(bits)
        bitIn = uint16(bits(i));
        crc = bitxor(crc, bitshift(bitIn, 15));
        if bitand(crc, uint16(hex2dec('8000'))) ~= 0
            crc = bitxor(bitshift(crc, 1), poly);
        else
            crc = bitshift(crc, 1);
        end
    end

    crc_bits = zeros(16, 1);
    for i = 1:16
        crc_bits(i) = bitget(crc, 17-i);
    end

end
