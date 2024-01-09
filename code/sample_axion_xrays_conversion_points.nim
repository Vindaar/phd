import helpers / sampling_helper # sampling distributions
import unchained                 # sane units
import ggplotnim                 # see something!
import xrayAttenuation           # window efficiencies
import math, sequtils

from os import `/`, expandTilde
const ResourcePath = "~/org/resources".expandTilde
const OutputPath = "~/phd/Figs/axion_conversion_point_sampling/".expandTilde

proc thm(): Theme =
  ## A shorthand to define a `ggplotnim` theme that looks nice 
  ## in the thesis
  result = themeLatex(fWidth = 0.9, width = 600, baseTheme = singlePlot)

let flux = "solar_axion_flux_differential_g_ae_1e-13_g_ag_1e-12_g_aN_1e-15.csv"
let dfAx = readCsv(ResourcePath / flux)
  .filter(f{`type` == "Total flux"})
let llnl = "llnl_xray_telescope_cast_effective_area_parallel_light_DTU_thesis.csv"
let dfLLNL = readCsv(ResourcePath / llnl)
  .mutate(f{"Efficiency" ~ idx("EffectiveArea[cm²]") / (PI * 2.15 * 2.15)})

let Si₃N₄ = compound((Si, 3), (N, 4)) # actual window
const ρSiN = 3.44.g•cm⁻³
const lSiN = 300.nm                  # window thickness
let Al = Aluminium.init()            # aluminium coating
const ρAl = 2.7.g•cm⁻³
const lAl = 20.nm                    # coating thickness

from numericalnim import newLinear1D, eval
let axInterp = newLinear1D(dfAx["Energy", float].toSeq1D,
                           dfAx["diffFlux", float].toSeq1D)
let llnlInterp = newLinear1D(dfLLNL["Energy[keV]", float].toSeq1D,
                             dfLLNL["Efficiency", float].toSeq1D)

proc I(E: keV): float =
  ## Compute the intensity of the axion flux after telescope & window eff.
  ##
  ## Axion flux and LLNL efficiency can be disabled by compiling with
  ## `-d:noAxionFlux` and `-d:noLLNL`, respectively.
  result = transmission(Si₃N₄, ρSiN, lSiN, E) * transmission(Al, ρAl, lAl, E)
  when not defined(noAxionFlux):
    result *= axInterp.eval(E.float)
  when not defined(noLLNL):
    result *= llnlInterp.eval(E.float)
  

echo I(1.keV)

let energies = linspace(0.01, 10.0, 1000).mapIt(it.keV)
let Is = energies.mapIt(I(it))
block PlotI:
  let df = toDf({ "E [keV]" : energies.mapIt(it.float),
                  "I" : Is })
  ggplot(df, aes("E [keV]", "I")) +
    geom_line() +
    ggtitle("Intensity entering the detector gas") +
    margin(left = 3.0) + thm() + 
    ggsave(OutputPath / "intensity_axion_conversion_point_simulation.pdf")

let Isampler = sampler(
  (proc(x: float): float = I(x.keV)), # wrap `I(E)` to take `float`
  0.01, 10.0, num = 1000 # use 1000 points for EDF & sample in 0.01 to 10 keV
)

import random
var rnd = initRand(0x42)

block ISampled:
  const nmc = 100_000
  let df = toDf( {"E [keV]" : toSeq(0 ..< nmc).mapIt(rnd.sample(Isampler)) })
  ggplot(df, aes("E [keV]")) +
    geom_histogram(bins = 200, hdKind = hdOutline) +
    ggtitle("Energies sampled from I(E)") +
    thm() + 
    ggsave(OutputPath / "energies_intensity_sampled.pdf")

proc initCASTGasMixture(): GasMixture =
  ## Returns the absorption length for the given energy in keV for CAST
  ## gas conditions:
  ## - Argon / Isobutane 97.7 / 2.3 %
  ## - 20°C ( for this difference in temperature barely matters)
  let arC = compound((Ar, 1)) # need Argon gas as a Compound
  let isobutane = compound((C, 4), (H, 10))
  # define the gas mixture
  result = initGasMixture(293.K, 1050.mbar, [(arC, 0.977), (isobutane, 0.023)])
let gm = initCASTGasMixture()  

proc generateSampler(gm: GasMixture, targetEnergy: keV): Sampler =
  ## Generate the exponential distribution to sample from based on the
  ## given absorption length
  # `xrayAttenuation` `absorptionLength` returns number in meter!
  let λ = absorptionLength(gm, targetEnergy).to(cm)
  let fnSample = (proc(x: float): float =
                    result = expFn(x, λ.float) # expFn = 1/λ · exp(-x/λ)
  )
  const SampleTo {.intdefine.} = 20 ## `SampleTo`, set via `-d:SampleTo=<int>`
  let num = (SampleTo.float / 3.0 * 1000).round.int # # of points to sample at
  result = sampler(fnSample, 0.0, SampleTo, num = num)

block GasAbs:
  let Es = linspace(0.03, 10.0, 1000)
  let lAbs = Es.mapIt(absorptionLength(gm, it.keV).m.to(cm).float)
  let df = toDf({ "E [keV]" : Es,
                  "l_abs [cm]" : lAbs })
  ggplot(df, aes("E [keV]", "l_abs [cm]")) +
    geom_line() +
    ggtitle(r"Absorption length of X-rays in CAST gas mixture: \\" & $gm) +
    margin(top = 1.5) +
    thm() + 
    ggsave(OutputPath / "cast_gas_absorption_length.pdf")

const nmc = 500_000 # start with 100k samples
var Es = newSeqOfCap[keV](nmc)
var zs = newSeqOfCap[cm](nmc)
while zs.len < nmc:
  # 1. sample an energy according to `I(E)`
  let E = rnd.sample(Isampler).keV
  # 2. get the sampler for this energy
  let distSampler = generateSampler(gm, E) 
  # 3. sample from it
  var z = Inf.cm
  when defined(Equiv3cmSampling): ## To get the same result as directly sampling
                                  ## only up to 3 cm use the following code
    while z > 3.0.cm:
      z = rnd.sample(distSampler).cm 
  elif defined(UnboundedVolume): ## This branch pretends the detection volume
                                 ## is unbounded if we sample within 20cm
    z = rnd.sample(distSampler).cm 
  else: ## This branch is the physically correct one. If an X-ray reaches the
        ## readout plane it is _not_ recorded, but it was still part of the
        ## incoming flux!
    z = rnd.sample(distSampler).cm
    if z > 3.0.cm: continue # just drop this X-ray
  zs.add z
  Es.add E

import stats, seqmath # mean, variance and percentile
let zsF = zs.mapIt(it.float) # for math
echo "Mean conversion position = ", zsF.mean().cm
echo "Median conversion position = ", zsF.percentile(50).cm
echo "Variance of conversion position = ", zsF.variance().cm

let dfZ = toDf({ "E [keV]" : Es.mapIt(it.float),
                 "z [cm]"  : zs.mapIt(it.float) })
ggplot(dfZ, aes("z [cm]")) +
  geom_histogram(bins = 200, hdKind = hdOutline) +
  ggtitle("Conversion points of all sampled X-rays according to I(E)") +
  thm() + 
  ggsave(OutputPath / "sampled_axion_conversion_points.pdf")
ggplot(dfZ, aes("E [keV]", "z [cm]")) +
  geom_point(size = 0.5, alpha = 0.2) + 
  ggtitle("Conversion points of all sampled X-rays according to I(E) " &
    "against their energy") +
  thm() + 
  ggsave(OutputPath / "sampled_axion_conversion_points_vs_energy.pdf",
         dataAsBitmap = true)
