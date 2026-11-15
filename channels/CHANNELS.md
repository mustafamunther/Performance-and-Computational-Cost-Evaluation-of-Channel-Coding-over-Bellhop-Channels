# Channels

Both channels use a 10 kHz carrier, source depth 30 m, receiver depth 40 m and range 10 km. Arrival delays are rounded to the
10 kHz sampling grid, arrivals on the same sample are summed coherently, the five strongest samples are retained and the
response is normalised to unit energy.

| | Channel 1 | Channel 2 |
|---|---|---|
| File | `channel1/UWA_Communication.arr` | `channel2/UWA_10kHz_Complex.arr` (`.env`, `.prt`) |
| Sound-speed profile | 6 points, 0-100 m: 1522, 1518, 1512, 1508, 1505, 1502 m/s | 13 points, about 1522 m/s at the surface decreasing to 1501-1502 m/s |
| Bottom | half-space 1650 m/s, 1.85 g/cm3, 0.90 dB/wavelength | same speed and density, 0.5 dB/wavelength |
| Beams | 181, -45 to +45 deg | 721, -60 to +60 deg |
| Arrivals / distinct samples | 76 / 75 | 143 / 119 |
| Retained tap delays (ms) | 0, 9.2, 11.6, 16.0, 29.6 | 0, 11.7, 11.9, 12.7, 36.7 |
| Power in the five taps | 58.4% | 73.7% |
| Delay span | 29.6 ms | 36.7 ms |

The Bellhop environment file of Channel 1 is not in this release.
