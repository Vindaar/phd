import std / strutils
import xrayAttenuation, ggplotnim
# generate a compound of silicon and nitrogen with correct number of atoms
let Si₃N₄ = compound((Si, 3), (N, 4))
#Si₃N₄.plotTransmission(3.44.g•cm⁻³, 300.nm.to(Meter))
# instantiate Mylar
let mylar = compound((C, 10), (H, 8), (O, 4))
# mylar.plotTransmission(1.4.g•cm⁻³, 2.μm.to(Meter), energyMax = 3.0)

echo mylar.name()
echo Si₃N₄.name()
# define energies in which to compute the transmission
# (we don't start at 0, as at 0 energy the parameters are not well defined)
let energies = linspace(1e-2, 3.0, 1000)

proc compTrans[T: AnyCompound](el: T, ρ: g•cm⁻³, length: Meter): DataFrame =
  result = toDf({ "Energy [keV]" : energies })
    .mutate(f{float: "μ" ~ el.attenuationCoefficient(idx("Energy [keV]").keV).float},
            f{float: "Trans" ~ transmission(`μ`.cm²•g⁻¹, ρ, length).float},
            f{"Compound" <- el.name()})
var df = newDataFrame()
# compute transmission for Si₃N₄ (known density and desired length)
df.add Si₃N₄.compTrans(3.44.g•cm⁻³, 300.nm.to(Meter))
# and for 2μm of mylar
df.add mylar.compTrans(1.4.g•cm⁻³, 2.μm.to(Meter))
# create a plot for the transmissions
echo df
let dS = r"$\SI{300}{nm}$" #pretty(300.nm, 3, short = true)
let dM = r"$\SI{2}{\micro\meter}$" #pretty(2.μm, 1, short = true)
let si = r"$\mathrm{Si}₃\mathrm{N}₄$"
ggplot(df, aes("Energy [keV]", "Trans", color = "Compound")) +
  geom_line() +
  xlab("Energy [keV]") + ylab("Transmission") +
  xlim(0.0, 3.0) + 
  ggtitle(r"Transmission examples of $# $# and $# Mylar" % [dS, si, dM]) +
  ggsave("/home/basti/phd/Figs/detector/window_transmisson_comparison.pdf",
         #width = 800, height = 600,
         useTex = true, standalone = true) 
