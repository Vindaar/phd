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

echo blackBody(1.μHz.to(Hz), T_sun)
echo blackBody(1.keV.xrayEnergyToFreq, T_sun)

let energies = linspace(0.01, 16.0, 1000)
let radiance = energies.mapIt(blackBody(it.keV.xrayEnergyToFreq, T_sun).float)
let df = seqsToDf(energies, radiance)
ggplot(df, aes("energies", "radiance")) + 
  geom_line() + 
  ggtitle("Black body radiation @ T = 15 Mio. K") +
  xlab("Energy [keV]") + ylab("Radiance [J•m⁻²•sr⁻¹]") + 
  ggsave("/tmp/blackbody_sun.pdf")
