import std / strutils
import xrayAttenuation, ggplotnim
# generate a compound of silicon and nitrogen with correct number of atoms
let Si₃N₄ = compound((Si, 3), (N, 4))
# instantiate an Argon instance
let ar = Argon.init()
# compute the density using ideal gas law at 1 atm
let ρ_Ar = density(1013.mbar.to(Pascal), 293.K, ar.molarMass)

# define energies in which to compute the transmission
# (we don't start at 0, as at 0 energy the parameters are not well defined)
let energies = linspace(1e-2, 10.0, 1000)

proc compTrans[T: AnyCompound](el: T, ρ: g•cm⁻³, length: Meter): DataFrame =
  result = toDf({ "Energy [keV]" : energies })
    .mutate(f{float: "μ" ~ el.attenuationCoefficient(idx("Energy [keV]").keV).float},
            f{float: "Trans" ~ transmission(`μ`.cm²•g⁻¹, ρ, length).float},
            f{"Compound" <- el.name})
var df = newDataFrame()
# compute transmission for Si₃N₄ (known density and desired length)
df.add Si₃N₄.compTrans(3.44.g•cm⁻³, 300.nm.to(Meter))
# and for argon 
df.add ar.compTrans(ρ_Ar, 3.cm.to(Meter))
# create a plot for the transmissions
echo df
let dS = pretty(300.nm, 3, short = true)
let dA = pretty(3.cm, 1, short = true)
let si = r"$\mathrm{Si}₃\mathrm{N}₄$"
ggplot(df, aes("Energy [keV]", "Trans", color = "Element")) +
  geom_line() +
  xlab("Energy [keV]") + ylab("Transmission") +
  ggtitle("Transmission examples of $# $# and $# Argon" % [dS, si, dA]) +
  ggsave("/home/basti/phd/Figs/theory/transmission_example.pdf",
         #width = 800, height = 600,
         useTex = true, standalone = true) 
