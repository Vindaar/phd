import std / strutils
import xrayAttenuation, ggplotnim
# generate a compound of silicon and nitrogen with correct number of atoms
let Si₃N₄ = compound((Si, 3), (N, 4))
let al = Aluminium.init()

# define energies in which to compute the transmission
# (we don't start at 0, as at 0 energy the parameters are not well defined)
let energies = linspace(0.03, 10.0, 1000)

# instantiate an Argon instance
let ar = Argon.init()
# and isobutane
let iso = compound((C, 4), (H, 10))

proc compTrans[T: AnyCompound](el: T, ρ: g•cm⁻³, length: Meter): Column =
  let df = toDf({ "Energy [keV]" : energies })
    .mutate(f{float: "μ" ~ el.attenuationCoefficient(idx("Energy [keV]").keV).float},
            f{float: "Trans" ~ transmission(`μ`.cm²•g⁻¹, ρ, length).float},
            f{"Compound" <- el.name()})
  result = df["Trans"]
    
var df = toDf({ "Energy [keV]" : energies })
# compute transmission for Si₃N₄ (known density and desired length)
df[Si₃N₄.name()] = Si₃N₄.compTrans(3.44.g•cm⁻³, 300.nm.to(Meter))
# and aluminum coating
df[al.name()] = al.compTrans(2.7.g•cm⁻³, 20.nm.to(Meter))

# and now for the gas mixture.
# first compute partial pressures
const fracAr = 0.977
const fracIso = 0.023
# using it we can compute the density of each by partial pressure theorem (Dalton's law)
let ρ_Ar = density(1050.mbar.to(Pascal) * fracAr, 293.K, ar.molarMass)
let ρ_Iso = density(1050.mbar.to(Pascal) * fracIso, 293.K, iso.molarWeight)

# now add transmission of argon and iso
df[ar.name()] = ar.compTrans(ρ_Ar, 3.cm.to(Meter))
df[iso.name()] = iso.compTrans(ρ_Iso, 3.cm.to(Meter))

let nSiN = r"$\SI{300}{nm}$ $\ce{Si_3 N_4}$"
let nAl = r"$\SI{20}{nm}$ $\ce{Al}$"
let nAr = r"$\SI{3}{cm}$ $\ce{Ar}$ Absorption"
let nIso = r"$\SI{3}{cm}$ $\ce{iC_4 H_{10}}$ Absorption"
let nArIso = r"$\SI{3}{cm}$ $\SI{97.7}{\percent} \ce{Ar} / \SI{2.3}{\percent} \ce{iC_4 H_{10}}$"

# finally just need to combine all of them in useful ways
# - argon + iso
df = df.mutate(f{"Trans_ArIso" ~ `Argon` * `C4H10`},
               f{"Abs ArIso" ~ 1.0 - `Trans_ArIso`},
               f{"Abs Ar" ~ 1.0 - `Argon`},
               f{"Abs Iso" ~ 1.0 - `C4H10`},
               f{"Efficiency" ~ idx("Abs ArIso") * `Si3N4` * `Aluminium`})
  .rename(f{nSiN <- "Si3N4"},
          f{nAl <- "Aluminium"},
          f{nAr <- "Abs Ar"},
          f{nIso <- "Abs Iso"},
          f{nArIso <- "Abs ArIso"}) # ,                    
  .gather([nSiN, nAl, nAr, nIso, nArIso, "Efficiency"], "Material", "Efficiency")

echo "Mean efficiency 0-3  keV = ", df.filter(f{idx("Energy [keV]") < 3.0})["Efficiency", float].mean  
echo "Mean efficiency 0-5  keV = ", df.filter(f{idx("Energy [keV]") < 5.0})["Efficiency", float].mean
echo "Mean efficiency 0-10 keV = ", df.filter(f{idx("Energy [keV]") < 10.0})["Efficiency", float].mean

ggplot(df, aes("Energy [keV]", "Efficiency", color = "Material")) +
  geom_line() +
  xlab("Energy [keV]") + ylab("Efficiency") +
  xlim(0.0, 10.0) + 
  ggtitle(r"Transmission (absorption for gases) of relevant detector materials and combined \\" &
    "detection efficiency of the Septemboard detector",
    titleFont = font(12.0)) +
  margin(top = 1.5, right = 2.0) +
  titlePosition(0.0, 0.8) + 
  legendPosition(0.42, 0.15) + 
  ggsave("/home/basti/phd/Figs/detector/detector_efficiency.pdf",
         width = 600, height = 400,
         #width = 800, height = 600,
         useTex = true, standalone = true) 
