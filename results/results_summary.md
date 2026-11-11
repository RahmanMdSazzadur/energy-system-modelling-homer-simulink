# HOMER results (run 11 Nov 2026, HOMER Pro 3.18.4). Currency: EUR (HOMER labels show $)

## Case A - grid-connected (optimal, same for wind capital multiplier 0.8 / 1.0 / 1.4)
| System | NPC | LCOE /kWh | Operating cost /yr | Initial capital | Renewable fraction |
|---|---|---|---|---|---|
| PV 20.4 kW + converter 12.7 kW + grid (OPTIMAL) | 213,113 | 0.141 | 12,334 | 18,824 | 18.9% |
| Grid only (base case) | 224,235 | 0.156 | 14,235 | 0 | 0% |
| PV 19.9 kW + 1 x 10 kW wind + grid | 272,500 | 0.180 | 13,589 | 58,443 | 20.1% |
| 1 x 10 kW wind + grid | 283,228 | 0.197 | 15,441 | 40,000 | 1.7% |
| PV 20.3 kW + 100 kWh Li-ion + grid | 324,917 | 0.215 | 14,989 | 88,804 | 18.9% |
Optimal PV system: IRR 9.0%, simple payback 9.5 yr vs grid only.

## Case B - off-grid (optimal, same for all wind multipliers)
| System | NPC | LCOE /kWh | Operating cost /yr | Initial capital | Ren. fraction | Diesel L/yr | Gen hours |
|---|---|---|---|---|---|---|---|
| PV 80.8 kW + 28 kW diesel + 200 kWh Li-ion + 18.6 kW conv (OPTIMAL) | 860,814 | 0.599 | 40,532 | 222,340 | 34.2% | 17,695 | 2,252 |
| PV 100 kW + 1 x 10 kW wind + 28 kW diesel + 200 kWh Li-ion | 913,186 | 0.635 | 40,348 | 277,608 | 37.9% | 16,738 | 2,153 |
| PV 119 kW + 28 kW diesel (no battery) | 1.18 M | 0.820 | 67,719 | 112,164 | 10.0% | 31,270 | 7,597 |
| Diesel only 28 kW (base case) | 1.23 M | 0.854 | 77,021 | 14,000 | 0% | 36,649 | 8,760 |
No feasible 100% renewable (no-diesel) system appeared in the optimisation results.

## Key findings
- Grid-connected PV is cheapest: LCOE 0.141 EUR/kWh, 4x cheaper than the best off-grid system (0.599).
- Off-grid costs ~650 kEUR more over 25 years (NPC 861k vs 213k).
- Wind never enters the optimal system, even at 4,000 EUR/kW: mean wind 2.65 m/s at 10 m is too low for a small turbine.
- A battery does not pay off on-grid (sellback 0.04 vs buy 0.156 is not enough spread); off-grid it cuts diesel hours from 8,760 to 2,252.

## MATLAB/Simulink: off-grid microgrid load step (Simscape Electrical, phasor mode)
Model: offgrid_microgrid.slx, built by build_offgrid_microgrid.m (MATLAB R2024b). 28 kW (35 kVA) diesel generator, H = 1 s, 5% droop governor (Tg 0.05 s, Te 0.5 s), integral AVR; 10 kW base load; 15 kW evening load switched in at t = 5 s; PV/battery inverter modelled as a controlled dynamic load with 2% frequency droop, 0.05 s response, 18.6 kW limit.
| Result (load step 10 -> 25 kW) | Diesel only | Diesel + battery |
|---|---|---|
| Frequency nadir | 47.14 Hz | 49.40 Hz |
| Frequency after step, steady | 48.94 Hz | 49.69 Hz |
| Voltage minimum (after first 10 ms) | 0.977 pu | 0.979 pu |
| Diesel power, steady | 24.8 kW | 14.3 kW |
| Battery power, steady | 0 kW | 10.7 kW |
Hand check of steady frequency drop: 1.07 Hz (diesel only) and 0.31 Hz (with battery) -> simulation gives 1.06 and 0.31 Hz.
Checks (re-run 11.11.2026): start-up 0-5 s is flat (f 49.985-50.008 Hz, V 1.000 pu, diesel 10.06 kW for a 10 kW load); power balance after the step 14.3 + 10.7 = 25.0 kW; battery peak about 18 kW, inside the 18.6 kW rating; battery block stored as Po = 0 W, Qo = 10 var, [np, nq] = [0 0], Vo = [1 0].
Notes: a one-sample voltage spike at the breaker switching instant is a phasor-solver artefact and is excluded. Diesel alone would dip below a typical 47.5 Hz under-frequency trip setting; the battery keeps the frequency within +-1 Hz.
