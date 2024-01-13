import ggplotnim, unchained

# The data file `chameleon-spectrum.dat` contains the spectrum in units of
# `keV⁻¹•16mm⁻²•h⁻¹` at β_m = β_m^sun = 6.457e10 or 10^10.81.
# See fig. 11.2 in Christoph's thesis
defUnit(keV⁻¹•mm⁻²•h⁻¹)
defUnit(keV⁻¹•cm⁻²•s⁻¹)
func conversionProbabilityChameleon(B: Tesla, L: Meter): float =
  const M_pl = sqrt(((hp_bar * c) / G_Newton).toDef(kg²)).toNaturalUnit.to(GeV) / sqrt(8 * π) # reduced Planck mass in natural units
  const βγsun = pow(10, 10.81)
  let M_γ = M_pl / βγsun
  result = (B.toNaturalUnit * L.toNaturalUnit / (2 * M_γ))^2  
proc convertChameleon(x: float): float =
  # divide by 16 to get from  /16mm² to /1mm². Input f
  # idiotic flux has already taken conversion probability into account.
  let P = conversionProbabilityChameleon(9.0.T, 9.26.m) # used values by Christop!
  result = (x.keV⁻¹•mm⁻²•h⁻¹ / 16.0 / P).to(keV⁻¹•cm⁻²•s⁻¹).float

let df = readCsv("~/phd/resources/chameleon-spectrum.dat", sep = '\t', header = "#")
  .mutate(f{"Flux" ~ convertChameleon(idx("I[/16mm2/hour/keV]"))},
          f{"Energy [keV]" ~ `energy` / 1000.0})
ggplot(df, aes("Energy [keV]", "Flux")) +
  geom_line() +
  ylab(r"Flux [$\si{keV⁻¹.cm⁻².s⁻¹}$]") +
  margin(left = 4.5) +
  ggtitle(r"Chameleon flux at $β^{\text{sun}}_γ = \num{6.46e10}$") +
  #xlim(0.0, 15.0) + 
  themeLatex(fWidth = 0.5, width = 600, baseTheme = sideBySide) +
  ggsave("~/phd/Figs/axions/differential_chameleon_flux.pdf")
