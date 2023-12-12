import nimhdf5, ggplotnim
import std / [strutils, os, sequtils, strformat]
import ingrid / [tos_helpers]
import ingrid / calibration / [calib_fitting, calib_plotting]
import ingrid / calibration 

proc stripPrefix(s, p: string): string =
  result = s
  result.removePrefix(p)

let useTeX = getEnv("USE_TEX", "false").parseBool
let Width = getEnv("WIDTH", "600").parseFloat
let Height = getEnv("HEIGHT", "450").parseFloat

from ginger import transparent

const settings = @["∫: 50 ns, ∂: 50 ns, G: 6x",
                   "∫: 50 ns, ∂: 20 ns, G: 10x",
                   "∫: 100 ns, ∂: 20 ns, G: 10x"]
const runs = @[80, 101, 121]

const riseTimeS = "riseTime [ns]"
const fallTimeS = "fallTime [ns]"

proc fadcSettings(plt: GgPlot, allRuns: seq[int], hideText: bool, minVal, maxVal, margin: float): GgPlot =
  ## This is a bit of a mess, but:
  ## It handles drawing the colored rectangles for the different FADC settings and
  ## adjusting the margin if any given via the R_MARGIN environment variable.
  ## The rectangle drawing is a bit ugly to look at, because we use the numbers initially
  ## intended for the peak position plot, but rescale them to map the completely different
  ## values for the other plots using min/max value and a potential margin.
  let mRight = getEnv("R_MARGIN", "6.0").parseFloat
  let widths = @[101 - 80, 121 - 101, allRuns.max - 121 + 1]
  let Δ = (maxVal - minVal) 
  let min = minVal - Δ * margin
  let ys = @[min, min, min]
  let heights = @[0.25, 0.25, 0.25].mapIt(it / 0.25 * (Δ * (1 + 2 * margin))) 
  let textYs = @[0.325, 0.27, 0.22].mapIt((it - 0.1) / (0.35 - 0.1) * Δ + minVal)
  let dfRects = toDf(settings, ys, textYs, runs, heights, widths)
  echo dfRects
  result = plt +
    geom_tile(data = dfRects, aes = aes(x = "runs", y = "ys", height = "heights", width = "widths", fill = "settings"),
              alpha = 0.3) +
    xlim(80, 200) +
    margin(right = mRight) +
    themeLatex(fWidth = 0.9, width = Width, height = Height, baseTheme = singlePlot) 
  if not hideText:
    result = result + geom_text(data = dfRects, aes = aes(x = f{`runs` + 2}, y = "textYs", text = "settings"), alignKind = taLeft)

proc getSetting(run: int): string =
  result = settings[lowerBound(runs, run) - 1]

proc plotFallTimeRiseTime(df: DataFrame, suffix: string, allRuns: seq[int], hideText: bool) =
  ## Given a full run of FADC data, create the
  ## Note: it may be sensible to compute a truncated mean instead
  let dfG = df.group_by("runNumber").summarize(f{float: riseTimeS << truncMean(col("riseTime").toSeq1D, 0.05)},
                                               f{float: fallTimeS << truncMean(col("fallTime").toSeq1D, 0.05)})
    .mutate(f{int -> string: "settings" ~ getSetting(`runNumber`)})

  let width = getEnv("WIDTH_RT", "600").parseFloat
  let height = getEnv("HEIGHT_RT", "450").parseFloat
  let mRight = getEnv("R_MARGIN", "4.0").parseFloat
  let fontScale = getEnv("FONT_SCALE", "1.0").parseFloat

  let (rMin, rMax) = (dfG[riseTimeS, float].min, dfG[riseTimeS, float].max)
  let perc = 0.025
  let Δr = (rMax - rMin) * perc
  var plt = ggplot(dfG, aes(runNumber, riseTimeS)) + 
    ggtitle("FADC signal rise times in ⁵⁵Fe data for all runs in $#" % suffix) +
    margin(right = mRight) +
    #theme_font_scale(fontScale) +
    themeLatex(fWidth = 0.9, width = width, height = height, baseTheme = singlePlot) +     
    ylim(rMin - Δr, rMax + Δr)
  plt = plt.fadcSettings(allRuns, hideText, rMin, rMax, perc)
  plt + geom_point(aes = aes(color = fallTimeS)) +
    ggsave("Figs/FADC/fadc_mean_riseTime_$#.pdf" % suffix,
               width = width, height = height, useTeX = useTeX, standalone = useTeX)

  let (fMin, fMax) = (dfG[fallTimeS, float].min, dfG[fallTimeS, float].max)
  let Δf = (fMax - fMin) * 1.025
  var plt2 = ggplot(dfG, aes(runNumber, fallTimeS)) + 
    margin(right = mRight) +
    ylim(fMin - Δf, fMax + Δf) + 
    #theme_font_scale(fontScale) +
    ggtitle("FADC signal fall times in ⁵⁵Fe data for all runsin $#" % suffix)
  plt2 = plt2.fadcSettings(allRuns, hideText, fMin, fMax, perc)
  plt2 + geom_point(aes = aes(color = riseTimeS)) +
    ggsave("Figs/FADC/fadc_mean_fallTime_$#.pdf" % suffix,
                width = width, height = height, useTeX = useTeX, standalone = useTeX)

  ggplot(dfG, aes(riseTimeS, fallTimeS, color = "settings")) + 
    geom_point() +
    ggtitle("FADC signal rise vs fall times for ⁵⁵Fe data in $#" % suffix) +
    margin(right = mRight) +
    #theme_font_scale(fontScale) +
    themeLatex(fWidth = 0.9, width = width, height = Height, baseTheme = singlePlot) + 
    ggsave("Figs/FADC/fadc_mean_riseTime_vs_fallTime_$#.pdf" % suffix,
           width = width, height = height, useTeX = useTeX, standalone = useTeX)    

proc fit(fname: string, year: int): (DataFrame, DataFrame) =
  var h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  let is2017 = year == 2017
  let is2018 = year == 2018
  if not is2017 and not is2018:
    raise newException(IOError, "The input file is neither clearly a 2017 nor 2018 calibration file!")
  
  var peakPos = newSeq[float]()
  var actThr = newSeq[float]()  
  var dfProp = newDataFrame()
  for run in fileInfo.runs:
    var df = h5f.readRunDsets(
      run,
      commonDsets = @["fadc/eventNumber",
                      "fadc/baseline",
                      "fadc/riseStart",
                      "fadc/riseTime",                  
                      "fadc/fallStop",
                      "fadc/fallTime",
                      "fadc/minVal",
                      "fadc/argMinval"]                 
    )
    df = df.rename(df.getKeys.mapIt(f{it.stripPrefix("fadc/") <- it}))
    df["runNumber"] = run
    let dset = h5f[(recoBase() & $run / "fadc/fadc_data").dset_str]
    let fadcData = dset[float].toTensor.reshape(dset.shape)

    let feSpec = fitFeSpectrumFadc(df["minVal", float].toSeq1D)
    let ecData = fitEnergyCalib(feSpec, isPixel = false)
    let texts = buildTextForFeSpec(feSpec, ecData)
    plotFeSpectrum(feSpec, run, 3, texts = texts, pathPrefix = "Figs/FADC/fe55_fits/", useTeX = false)

    # add fit to peak positions
    peakPos.add feSpec.pRes[feSpec.idx_kalpha]
    
    ggplot(df, aes("minVal")) +
      geom_histogram(bins = 300) +
      ggsave("/t/fadc_run_$#_minima.pdf" % $run)

    # Now get the activation threshold as a function of gridpix energy on center
    # chip. Get GridPix data on center chip...
    var dfGP = h5f.readRunDsets(
      run,
      chipDsets = some((chip: 3, dsets: @["energyFromCharge", "eventNumber"]))
    )
    # ...sum all clusters for each event (for multiple clusters, the FADC sees all)...
    dfGP = dfGP.group_by("eventNumber").summarize(f{float -> float: "energyFromCharge" << sum(col("energyFromCharge"))})
    # ... join with FADC DF to only have events left with FADC trigger...
    df = innerJoin(dfGP, df.clone(), "eventNumber")
    # ...compute activation threshold as 1-th percentile of data
    actThr.add percentile(df["energyFromCharge", float], 1)

    dfProp.add df
  doAssert h5f.close() >= 0

  let df = toDf({ "runs" : fileInfo.runs,
                  "peaks" : peakPos,
                  "actThr" : actThr })
  result = (df, dfProp)

proc main(path: string, year: int, fit = false, hideText = false) =
  ##    - run 101 <2017-11-29 Wed 6:40> was the first with FADC noise
  ##      significant enough to make me change settings:
  ##      - Diff: 50 ns -> 20 ns (one to left)
  ##      - Coarse gain: 6x -> 10x (one to right)
  ##    - run 112: change FADC settings again due to noise:
  ##      - integration: 50 ns -> 100 ns
  ##        This was done at around <2017-12-07 Thu 8:00>
  ##      - integration: 100 ns -> 50 ns again at around
  ##        <2017-12-08 Fri 17:50>.
  ##    - run 121: Jochen set the FADC main amplifier
  ##      integration time from 50 -> 100 ns again, around
  ##      <2017-12-15 Fri 10:20>
  
  let is2017 = year == 2017
  let yearToRun = if is2017: 2 else: 3
  let suffix = "run$#" % $yearToRun
  
  var dfProp = newDataFrame()
  var df = newDataFrame()  
  var peakPos: seq[float]
  if fit:
    (df, dfProp) = fit(path, year)
    dfProp.writeCsv(&"resources/properties_fadc_{suffix}.csv")
    df.writeCsv(&"resources/peak_positions_fadc_{suffix}.csv")    
  else:
    dfProp = readCsv(&"{path}/properties_fadc_{suffix}.csv")
    df = readCsv(&"{path}/peak_positions_fadc_{suffix}.csv")     

  let allRuns = df["runs", int].toSeq1D

  plotFallTimeRiseTime(dfProp, suffix, allRuns, hideText)

  block Fe55PeakPos:
    let outname = "Figs/FADC/peak_positions_fadc_$#.pdf" % $suffix
    var plt = ggplot(df, aes("runs", "peaks"))
    if is2017:
      plt = plt.fadcSettings(allRuns, hideText, 0.1, 0.35, 0.0)
    plt + geom_point() +
      ylim(0.1, 0.35) +
      ylab("⁵⁵Fe peak position [V]") + xlab("Run number") +
      ggtitle("Peak position of the ⁵⁵Fe runs in the FADC data") + 
      ggsave(outname, width = Width, height = Height, useTeX = useTeX, standalone = useTeX)
  block ActivationThreshold:
    let outname = "Figs/FADC/activation_threshold_gridpix_energy_fadc_$#.pdf" % $suffix
    var plt = ggplot(df, aes("runs", "actThr"))
    if is2017:
      plt = plt.fadcSettings(allRuns, hideText, 0.9, 2.4, 0.0)
    plt + geom_point() +
      ylim(0.9, 2.4) + 
      ylab("Activation threshold [keV]") + xlab("Run number") +
      ggtitle("Activation threshold based on center GridPix energy") + 
      ggsave(outname, width = Width, height = Height, useTeX = useTeX, standalone = useTeX)
    

when isMainModule:
  import cligen
  dispatch main
