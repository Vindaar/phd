import std / [os, strutils]
import ingrid / ingrid_types
import ingrid / private / [cdl_utils, cdl_cuts, hdf5_utils, likelihood_utils]
import pkg / [ggplotnim, nimhdf5]


const TpxDir = "/home/basti/CastData/ExternCode/TimepixAnalysis"
const cdl_runs_file = TpxDir / "resources/cdl_runs_2019.org"
const fname = "/home/basti/CastData/data/CDL_2019/CDL_2019_Reco.h5"
const cdlFile = "/home/basti/CastData/data/CDL_2019/calibration-cdl-2018.h5"
const dsets = @["totalCharge", "eccentricity", "lengthDivRmsTrans", "fractionInTransverseRms"]

proc calcEnergyFromFits(df: DataFrame, fit_μ: float, tfKind: TargetFilterKind): DataFrame =
  ## Given the fit result of this data type & target/filter combination compute the energy
  ## of each cluster by using the mean position of the main peak and its known energy
  result = df
  result["Target"] = $tfKind
  let invTab = getInverseXrayRefTable()
  let energies = getXrayFluorescenceLines()
  let lineEnergy = energies[invTab[$tfKind]]
  result = result.mutate(f{float: "energy" ~ `totalCharge` / fit_μ * lineEnergy})

let h5f = H5open(fname, "r")
var df = newDataFrame()
for tfKind in TargetFilterKind:
  for (run, grp) in tfRuns(h5f, tfKind, cdl_runs_file):
    var dfLoc = newDataFrame()
    for dset in dsets:
      if dfLoc.len == 0:
        dfLoc = toDf({ dset : h5f.readCutCDL(run, 3, dset, tfKind, float64) })
      else:
        dfLoc[dset] = h5f.readCutCDL(run, 3, dset, tfKind, float64)
    dfLoc["runNumber"] = run
    dfLoc["tfKind"] = $tfKind
    # calculate energy from fit
    let fit_μ = grp.attrs["fit_μ", float]
    dfLoc = dfLoc.calcEnergyFromFits(fit_μ, tfKind)
    df.add dfLoc

proc calcInterp(ctx: LikelihoodContext, df: DataFrame): DataFrame =
  # walk all rows
  # feed ecc, ldiv, frac into logL and return a DF with
  result = df.mutate(f{float: "logL" ~ ctx.calcLikelihoodForEvent(`energy`,
                                                            `eccentricity`,
                                                            `lengthDivRmsTrans`,
                                                            `fractionInTransverseRms`)
  })

# first make plots of 3 logL variables to see their correlations  
ggplot(df, aes("eccentricity", "lengthDivRmsTrans", color = "fractionInTransverseRms")) +
  geom_point(size = 1.0) +
  ggtitle("lnL variables of all (cleaned) CDL data for correlations") + 
  ggsave("/home/basti/phd/Figs/background/correlation_ecc_ldiv_frac.pdf")

ggplot(df, aes("eccentricity", "fractionInTransverseRms", color = "lengthDivRmsTrans")) +
  geom_point(size = 1.0) +
  ggtitle("lnL variables of all (cleaned) CDL data for correlations") +   
  ggsave("/home/basti/phd/Figs/background/correlation_ecc_frac_ldiv.pdf")

ggplot(df, aes("lengthDivRmsTrans", "fractionInTransverseRms", color = "eccentricity")) +
  geom_point(size = 1.0) +
  ggtitle("lnL variables of all (cleaned) CDL data for correlations") +   
  ggsave("/home/basti/phd/Figs/background/correlation_ldiv_frac_ecc.pdf")


df = df.filter(f{`eccentricity` < 2.5})
ggplot(df, aes("eccentricity", "lengthDivRmsTrans", color = "fractionInTransverseRms")) +
  geom_point(size = 1.0) +
  ggtitle("lnL variables of all (cleaned) CDL data for correlations (ε < 2.5)") +   
  ggsave("/home/basti/phd/Figs/background/correlation_ecc_ldiv_frac_ecc_smaller_2_5.pdf")

ggplot(df, aes("eccentricity", "fractionInTransverseRms", color = "lengthDivRmsTrans")) +
  geom_point(size = 1.0) +
  ggtitle("lnL variables of all (cleaned) CDL data for correlations (ε < 2.5)") +   
  ggsave("/home/basti/phd/Figs/background/correlation_ecc_frac_ldiv_ecc_smaller_2_5.pdf")

ggplot(df, aes("lengthDivRmsTrans", "fractionInTransverseRms", color = "eccentricity")) +
  geom_point(size = 1.0) +
  ggtitle("lnL variables of all (cleaned) CDL data for correlations (ε < 2.5)") +   
  ggsave("/home/basti/phd/Figs/background/correlation_ldiv_frac_ecc_ecc_smaller_2_5.pdf")


from std/sequtils import concat
# now generate the plot of the logL values for all cleaned CDL data. We will compare the
# case of no morphing with the linear morphing case
proc getLogL(df: DataFrame, mk: MorphingKind): (DataFrame, DataFrame) = 
  let ctx = initLikelihoodContext(cdlFile, yr2018, crGold, igEnergyFromCharge, Timepix1, mk)
  var dfMorph = ctx.calcInterp(df)
  dfMorph["Morphing?"] = $mk
  let cutVals = ctx.calcCutValueTab()
  case cutVals.kind
  of mkNone:
    let lineEnergies = getEnergyBinning()
    let tab = getInverseXrayRefTable()
    var cuts = newSeq[float]()
    var energies = @[0.0]
    var lastCut = Inf
    var lastE = Inf
    for k, v in tab:
      let cut = cutVals[k]
      if classify(lastCut) != fcInf:
        cuts.add lastCut
        energies.add lastE
      cuts.add cut
      lastCut = cut
      let E = lineEnergies[v]
      energies.add E
      lastE = E
    cuts.add cuts[^1] # add last value again to draw line up 
    echo energies.len, " vs ", cuts.len
    let dfCuts = toDf({energies, cuts, "Morphing?" : $cutVals.kind})
    result = (dfCuts, dfMorph)
  of mkLinear:
    let energies = concat(@[0.0], cutVals.cutEnergies, @[20.0])
    let cutsSeq = cutVals.cutValues.toSeq1D
    let cuts = concat(@[cutVals.cutValues[0]], cutsSeq, @[cutsSeq[^1]])
    let dfCuts = toDf({"energies" : energies, "cuts" : cuts, "Morphing?" : $cutVals.kind})
    result = (dfCuts, dfMorph)

var dfMorph = newDataFrame()
let (dfCutsNone, dfNone) = getLogL(df, mkNone)
let (dfCutsLinear, dfLinear) = getLogL(df, mkLinear)
dfMorph.add dfNone
dfMorph.add dfLinear

var dfCuts = newDataFrame()
dfCuts.add dfCutsNone
dfCuts.add dfCutsLinear

ggplot(dfMorph, aes("logL", "energy", color = factor("Target"))) +
  facet_wrap("Morphing?") +
  geom_point(size = 1.0) +
  geom_line(data = dfCuts, aes = aes("cuts", "energies")) + # , color = "Morphing?")) + 
  ggtitle("lnL values of all (cleaned) CDL data against energy") + 
  ggsave("/home/basti/phd/Figs/background/logL_of_CDL_vs_energy.pdf", width = 1000, height = 600)
