Energy system modelling in HOMER Pro and MATLAB/Simulink - input data
Site: Lappeenranta, Finland (61.058 N, 28.186 E, 99 m)
Source: PVGIS 5.3, European Commission JRC (radiation: PVGIS-SARAH3, weather: ERA5), year 2023
Downloaded: 11 Nov 2026
Time: hourly, 8760 values, Finnish standard time (UTC+2), starting 1 Jan 00:00

lappeenranta_2023_solar_GHI_kWm2.txt   global horizontal irradiance, kW/m2   (annual 975 kWh/m2)
lappeenranta_2023_temperature_C.txt    air temperature at 2 m, deg C
lappeenranta_2023_wind_10m_ms.txt      wind speed at 10 m, m/s (mean 2.65) -> set anemometer height 10 m in HOMER

HOMER: Resources > Solar GHI / Temperature / Wind > "Import time series data file"

lappeenranta_2023_load_10houses_kW.txt  electric load of 10 rural houses, kW, hourly (built 11 Nov 2026)
  Annual 91.2 MWh (250 kWh/day average), peak 25.1 kW, load factor 0.42
  50% household electricity: daily pattern with morning/evening peaks, more lighting in dark months, random noise (seed 2025)
  50% space heating (heat-pump houses): proportional to heating degree hours, base 17 C, from the 2023 temperature file
  Monthly average: Dec 389 kWh/day, Jul 119 kWh/day (winter about 3x summer)
  HOMER: Electric load > "Import a load from a time series file"
