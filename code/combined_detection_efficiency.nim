import std / strutils
import xrayAttenuation, ggplotnim

proc initCASTGasMixture*(): GasMixture =
  ## Returns the absorption length for the given energy in keV for CAST
  ## gas conditions:
  ## - Argon / Isobutane 97.7 / 2.3 %
  ## - 20°C ( for this difference in temperature barely matters)
  # define Argon
  let arC = compound((Ar, 1)) # need Argon gas as a Compound
  let isobutane = compound((C, 4), (H, 10))
  # define the gas mixture
  result = initGasMixture(293.K, 1050.mbar, [(arC, 0.977), (isobutane, 0.023)])


# generate a compound of silicon and nitrogen with correct number of atoms
let Si₃N₄ = compound((Si, 3), (N, 4))
# And the aluminium coating of 20nm.
let Al = Aluminium.init(2.7.g•cm⁻³)
# instaniate the CAST gas mixture
let gas = initCASTGasMixture()

echo Si₃N₄.ρ
echo Al.ρ
echo gas.ρ

# define energies in which to compute the transmission
# (we don't start at 0, as at 0 energy the parameters are not well defined)
let energies = linspace(0.0, 10.0, 1000)
let AlS = r"$\SI{20}{nm}\,\ce{Al}$"
let SiNS = r"$\SI{300}{nm}\,\ce{Si3 N4}$"
let GasS = r"$\SI{3}{cm}\,\ce{Ar}/\ce{Iso}$"
var df = toDf({"E" : energies})
  .mutate(f{float: GasS ~ transmission(gas, 3.cm, `E`.keV).float },
          f{float: GasS ~ 1.0 - idx(GasS)},
          f{float: AlS ~ transmission(Al, Al.ρ, 20.nm, `E`.keV).float },
          f{float: SiNS ~ transmission(Si₃N₄, Si₃N₄.ρ, 300.nm, `E`.keV).float })
let dfLLNL = readCsv("/home/basti/org/resources/llnl_xray_telescope_cast_effective_area_extended.csv")
  .mutate(f{"Efficiency" ~ (idx("EffectiveArea[cm²]").cm² / (2.15.cm * 2.15.cm * π)).float})
import numericalnim, sequtils
let interp = newLinear1D(dfLLNL["Energy[keV]", float].toSeq1D,
                         dfLLNL["Efficiency", float].toSeq1D)
df["LLNL"] = energies.mapIt(interp.eval(it))
df = df.mutate(f{"Combined" ~ idx(GasS) * idx(AlS) * idx(SiNS) * `LLNL`})
df = df.gather([GasS, AlS, SiNS, "LLNL", "Combined"], "Type", "Efficiency")
df = df.dropNaN()

echo df
#proc compTrans[T: AnyCompound](el: T, ρ: g•cm⁻³, length: Meter): DataFrame =
#  result = toDf({ "Energy [keV]" : energies })
#    .mutate(f{float: "μ" ~ el.attenuationCoefficient(idx("Energy [keV]").keV).float},
#            f{float: "Trans" ~ transmission(`μ`.cm²•g⁻¹, ρ, length).float},
#            f{"Compound" <- el.name})
#var df = newDataFrame()
## compute transmission for Si₃N₄ (known density and desired length)
#df.add Si₃N₄.compTrans(3.44.g•cm⁻³, 300.nm.to(Meter))
## and for argon 
#df.add ar.compTrans(ρ_Ar, 3.cm.to(Meter))
## create a plot for the transmissions
#echo df
#let dS = pretty(300.nm, 3, short = true)
#let dA = pretty(3.cm, 1, short = true)
#let si = r"$\mathrm{Si}₃\mathrm{N}₄$"
ggplot(df, aes("E", "Efficiency", color = "Type")) +
  geom_line() +
  xlab("Energy [keV]") + ylab("Efficiency") +
  ggtitle("Combined detection efficiency and constituents") + 
  ggsave("/home/basti/phd/Figs/limit/combined_detection_efficiency.pdf",
         width = 800, height = 600,
         useTex = true, standalone = true)
