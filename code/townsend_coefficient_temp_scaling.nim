import unchained, math, ggplotnim, sequtils

const V_i = 15.7.V # Lucian gives this ionization potential next to fig. 5.4
defUnit(kV•cm⁻¹)
defUnit(cm⁻¹)
proc townsend[P: Pressure; A: Area](p: P, σ: A, T: Kelvin, E: kV•cm⁻¹): cm⁻¹ =
  let arg = (V_i * p * σ) / (E * k_B * T)
  echo arg
  result = (p * σ / (k_B * T) * exp( -arg )).to(cm⁻¹)
echo townsend(1013.25.mbar, 500.MegaBarn, 273.15.K, 60.kV•cm⁻¹)

let temps = linspace(0.0, 100.0, 1000) # 0 to 100 °C
#let temps = linspace(-273.15, 10000.0, 1000) # all of da range!
var αs = temps.mapIt(townsend(1013.25.mbar, 500.MegaBarn, (273.15 + it).K, 60.kV•cm⁻¹).float)
let df = toDf(temps, αs)
ggplot(df, aes("temps", "αs")) +
  geom_line() +
  xlab("Gas temperature [°C]") +
  ylab("Townsend coefficient [cm⁻¹]") +
  theme_font_scale(1.0, family = "serif") +
  ggsave("~/phd/Figs/gas_physics/townsend_coefficient_temperature_scaling_lucian.pdf")
