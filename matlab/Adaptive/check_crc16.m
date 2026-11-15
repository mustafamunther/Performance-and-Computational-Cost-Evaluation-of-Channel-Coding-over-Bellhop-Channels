function [ok, payload_bits] = check_crc16(decoded_bits_with_crc)
%CHECK_CRC16  Receiver-side CRC-16 check: recompute the CRC over the
%  decoded payload and compare to the decoded CRC bits. This is how a
%  REAL receiver determines ACK/NACK -- it never has the true
%  transmitted bits to compare against (that was this module's previous,
%  unrealistic "BER feedback" shortcut).
%
%  [ok, payload_bits] = check_crc16(decoded_bits_with_crc)
%
%  Input
%    decoded_bits_with_crc - decoder output: [payload_bits; crc_bits]
%                            (same total length add_crc16.m produced)
%
%  Outputs
%    ok           - true if the recomputed CRC matches (block accepted),
%                   false otherwise (NACK) -- this is what a real link
%                   layer reports back, frame by frame
%    payload_bits - the payload portion (decoded_bits_with_crc minus the
%                   last 16 CRC bits), for whatever further use the
%                   caller has (e.g. this module's OWN true-BER logging
%                   for plots, which is a privilege of the SIMULATION,
%                   not something a real receiver could do)

    decoded_bits_with_crc = decoded_bits_with_crc(:);
    n = length(decoded_bits_with_crc);

    if n <= 16
        ok = false;
        payload_bits = decoded_bits_with_crc;
        return;
    end

    payload_bits = decoded_bits_with_crc(1:end-16);
    rx_crc = decoded_bits_with_crc(end-15:end);

    expected_crc = crc16_bits_local(payload_bits);

    ok = isequal(rx_crc, expected_crc);

end


function crc_bits = crc16_bits_local(bits)
%  Identical computation to add_crc16.m's internal crc16_bits -- kept as
%  a local copy so this file has no dependency ordering requirement on
%  add_crc16.m being on the path first.

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
