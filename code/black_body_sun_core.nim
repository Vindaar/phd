import ggplotnim, unchained, sequtils

#defUnit(s⁻¹)
#defUnit(μs⁻¹)
defUnit(Watt•Steradian⁻¹•Meter⁻²•NanoMeter⁻¹)
defUnit(Joule•Meter⁻²•Steradian⁻¹)

let T_sun = 15.MegaKelvin.to(Kelvin)

proc blackBody(ν: s⁻¹, T: Kelvin): Joule•Meter⁻²•Steradian⁻¹ =
  result = (2 * hp * ν^3 / c^2 / (exp(hp * ν / (k_B * T)) - 1)).to(Joule•Meter⁻²•Steradian⁻¹)

proc xrayEnergyToFreq(E: keV): s⁻¹ = 
  ## converts the input energy in keV to a correct frequency
  result = E.to(Joule) / hp
echo 1.keV.xrayEnergyToFreq
echo "Solar core temperature ", T_Sun, " in keV : ", T_Sun.toNaturalUnit().to(keV)
echo blackBody(1.μHz.to(Hz), T_sun)
echo blackBody(1.keV.xrayEnergyToFreq, T_sun)

let energies = linspace(0.01, 15.0, 1000)
let radiance = energies.mapIt(blackBody(it.keV.xrayEnergyToFreq, T_sun).float)
let df = seqsToDf(energies, radiance)
ggplot(df, aes("energies", "radiance")) + 
  geom_line() + 
  ggtitle(r"Black body radiation @ $T = \SI{15e6}{K}$") +
  xlab(r"Energy [ $\si{keV}$ ]", margin = 1.25) +
  ylab(r"Radiance [ $\si{J.m^{-2}.sr^{-1}$ ]", margin = 1.75) +
  xlim(0, 15) + 
  ggsave("/home/basti/phd/Figs/blackbody_spectrum_solar_core.pdf", useTeX = true, standalone = true, width = 800, height = 480)
