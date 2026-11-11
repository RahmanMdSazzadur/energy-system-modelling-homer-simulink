# HOMER cost inputs (2025 prices, Finland) - Lappeenranta hybrid PV-wind
Researched 11 Nov 2026. Values marked (assumption) have no direct 2025 Finnish source.

| Component | HOMER input | Basis / source |
|---|---|---|
| Solar PV | 800 EUR/kW capital, 800 replacement, 15 EUR/kW/yr O&M, 25 yr | Motiva market survey 1/2025: 7 kWp system median 7,000 EUR installed (~1,000 EUR/kWp incl. inverter); inverter split out below. https://ilmastoinfo.hsy.fi/wp-content/uploads/2025/05/Aurinkosahkoa-pientaloon-Motiva.pdf |
| Converter (inverter) | 200 EUR/kW capital and replacement, 0 O&M, 15 yr life, 95% efficiency (HOMER default life/efficiency) | Part of the ~1,000 EUR/kWp above (assumption on the split) |
| Small wind turbine (10 kW class) | 5,000 EUR/kW capital, 4,000 replacement, 2% of capital/yr O&M, 20 yr | European small wind 5-15 kW installed ~4,000-7,000 EUR/kW (web price guides, low-quality sources; use as range). https://content.luvside.de/wind-turbine-for-home-cost-setup-guide |
| Li-ion battery | 700 EUR/kWh capital, 600 replacement, 10 EUR/kWh/yr O&M, 15 yr | EUPD Research: average residential storage price 711 EUR/kWh, H1 2025. https://info.aea-al.org/?p=1042845 |
| Diesel generator | 500 EUR/kW capital (assumption), O&M 0.03 EUR/kW/op.hour (assumption), 15,000 h | No 2025 Finnish source found |
| Diesel fuel | 1.69 EUR/L | Statistics Finland: 2025 average diesel price 1.69 EUR/L (reported by Verkkouutiset). https://www.verkkouutiset.fi/a/dieselin-hinta-nousi-28-senttia-toiseksi-suurin-kuukausinousu-2000-luvulla/ |
| Grid purchase | 0.156 EUR/kWh | Residential electricity price Finland, Sept 2025 (energy+transfer+taxes). https://www.globalpetrolprices.com/Finland/electricity_prices/ |
| Grid sellback | 0.04 EUR/kWh | Finland day-ahead average 2025: 0.0407 EUR/kWh. https://euenergy.live/finland/2025 |
| Discount / inflation | 6% nominal / 2% | Assumption (real rate ~3.9%) |
| Project lifetime | 25 yr | HOMER default, matches PV life |

## Other HOMER settings entered
- PV: generic flat plate, DC bus, derating 80% (snow/soiling), slope 45 deg, azimuth 0 (south), ground reflectance 20%
- PV temperature effects: -0.35 %/C, NOCT 45 C, STC efficiency 21% (modern mono-Si, assumption)
- Temperature resource: monthly averages from the 2023 PVGIS file (HOMER 3.18 greyed out hourly import): Jan -3.5, Feb -4.3, Mar -3.2, Apr 3.1, May 10.8, Jun 16.7, Jul 17.3, Aug 17.9, Sep 14.8, Oct 3.7, Nov -1.4, Dec -6.3 (annual 5.47 C)
- Wind resource: hourly 10 m file, anemometer 10 m, altitude 99 m, logarithmic profile, roughness 0.1 m
- Wind turbine: HOMER "Generic 10 kW", AC bus, hub height 24 m, 20 yr. Per turbine: capital 50,000 EUR (=5,000 EUR/kW), replacement 40,000, O&M 1,000 EUR/yr. Sensitivity on capital multiplier: 0.8 / 1.0 / 1.4 (= 4,000 / 5,000 / 7,000 EUR/kW). Quantity sized by HOMER Optimizer.
- Grid: simple rates, buy 0.156 EUR/kWh, sell 0.04 EUR/kWh, no net metering (Finland settles hourly, no net metering).
- Battery: HOMER "Generic 100kWh Li-Ion" (idealized model, 90% round trip, min SOC 20%, 15 yr / 300 MWh throughput), DC bus. Per 100 kWh unit: capital 70,000 (=700 EUR/kWh), replacement 60,000, O&M 1,000 EUR/yr. Sized in 100 kWh steps by HOMER Optimizer.
- Diesel generator (Case B only): HOMER "Autosize Genset", AC, 500 EUR/kW capital and replacement, 0.03 EUR/kW/op.hour, 15,000 h, min load 25%, fuel 1.69 EUR/L. "Simulate with and without" so HOMER also tests 100% renewable off-grid.

## HOMER files (this folder)
- Lappeenranta_hybrid_PV_wind_2025.homer = Case A: grid + PV + wind + converter + battery
- CaseB_offgrid_PV_wind_battery_diesel_2025.homer = Case B: PV + wind + converter + battery + diesel, no grid
