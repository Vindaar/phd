import nimhdf5, ggplotnim
import std / [strutils, os, sequtils]
import ingrid / [tos_helpers]
import ingrid / calibration / [calib_fitting, calib_plotting]
import ingrid / calibration 

proc stripPrefix(s, p: string): string =
  result = s
  result.removePrefix(p)

proc plotIdx(df: DataFrame, fadcData: Tensor[float], idx: int) =
  let xmin = df["argMinval", int][idx]
  let xminY = df["minvals", float][idx]
  let xminlineX = @[xmin, xmin] # one point for x of min, max
  let fData = fadcData[idx, _].squeeze
  let xminlineY = linspace(fData.min, fData.max, 2)

  let riseStart = df["riseStart", int][idx]
  let fallStop = df["fallStop", int][idx]
  let riseStartX = @[riseStart, riseStart]
  let fallStopX = @[fallStop, fallStop]
  let baseline = df["baseline", float][idx]  
  let baselineY = @[baseline, baseline]
  
  let df = toDf({ "x"         : toSeq(0 ..< 2560),
                  "baseline"  : baseline,
                  "data"      : fData,
                  "xminX"     : xminlineX, 
                  "xminY"     : xminlineY,
                  "riseStart" : riseStartX,
                  "fallStop"  : fallStopX })
                  # Comparison has to be done by hand unfortunately
  let path = "/t/fadc_spectrum_baseline.pdf"
  ggplot(df, aes("x", "data")) +
    geom_line() +
    geom_point(color = color(0.1, 0.1, 0.1, 0.1)) +
    geom_line(aes = aes("x", "baseline"),
              color = "blue") +
    geom_line(data = df.head(2), aes = aes("xminX", "xminY"),
                     color = "red") +
    geom_line(data = df.head(2), aes = aes("riseStart", "xminY"),
                     color = "green") +
    geom_line(data = df.head(2), aes = aes("fallStop", "xminY"),
                     color = "pink") +
    ggsave(path)

from ginger import transparent    
proc plotFallTimeRiseTime(df: DataFrame, suffix: string) =
  ## Given a full run of FADC data, create the
  ## Note: it may be sensible to compute a truncated mean instead
  let dfG = df.group_by("runNumber").summarize(f{float: "riseTime" << truncMean(col("riseTime").toSeq1D, 0.05)},
                                               f{float: "fallTime" << truncMean(col("fallTime").toSeq1D, 0.05)})
  ggplot(dfG, aes(runNumber, riseTime, color = fallTime)) + 
    geom_point() +
    ggtitle("Comparison of FADC signal rise times in ⁵⁵Fe data for all runs in $#" % suffix) +
    ggsave("Figs/FADC/fadc_mean_riseTime_$#.pdf" % suffix)
  ggplot(dfG, aes(runNumber, fallTime, color = riseTime)) + 
    geom_point() +
    ggtitle("Comparison of FADC signal fall times in ⁵⁵Fe data for all runsin $#" % suffix) +
    ggsave("Figs/FADC/fadc_mean_fallTime_$#.pdf" % suffix)

proc main(fname: string, year: int) =
  var h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  let is2017 = year == 2017
  let is2018 = year == 2018
  if not is2017 and not is2018:
    raise newException(IOError, "The input file is neither clearly a 2017 nor 2018 calibration file!")
  
  var peakPos = newSeq[float]()
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
                      "fadc/minvals",
                      "fadc/argMinval"]                 
    )
    df = df.rename(df.getKeys.mapIt(f{it.stripPrefix("fadc/") <- it}))
    df["runNumber"] = run
    let dset = h5f[(recoBase() & $run / "fadc/fadc_data").dset_str]
    let fadcData = dset[float].toTensor.reshape(dset.shape)

    ## The following can be used to construct event displays
    #for idx in 0 ..< dset.shape[0]:
    #  plotIdx(df, fadcData, idx)
    #  sleep(500)

    let feSpec = fitFeSpectrumFadc(df["minvals", float].toSeq1D)
    let ecData = fitEnergyCalib(feSpec, isPixel = false)
    let texts = buildTextForFeSpec(feSpec, ecData)
    plotFeSpectrum(feSpec, run, 3, texts = texts, pathPrefix = "Figs/FADC/fe55_fits/")

    # add fit to peak positions
    peakPos.add feSpec.pRes[feSpec.idx_kalpha]
    
    
    ggplot(df, aes("minvals")) +
      geom_histogram(bins = 300) +
      ggsave("/t/fadc_run_$#_minima.pdf" % $run)

    dfProp.add df

  let yearToRun = if is2017: 2 else: 3
  let suffix = "run$#" % $yearToRun
    
  plotFallTimeRiseTime(dfProp, suffix) 



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
  let df = toDf({ "runs" : fileInfo.runs,
                  "peaks" : peakPos })

  let outname = "Figs/FADC/peak_positions_fadc_$#.pdf" % $suffix
  var plt = ggplot(df, aes("runs", "peaks"))

  if is2017:
    let settings = @["""Integration: 50 ns\\
Diff: 50 ns\\
Gain: 6x""",
                   """Integration: 50 ns\\
Diff: 20 ns\\
Gain: 10x""",
                   """Integration: 100 ns\\
Diff: 20 ns\\
Gain: 10x""" ]
    let runs = @[80, 101, 121]
    let widths = @[101 - 80, 121 - 101, fileInfo.runs.max - 121]
    let ys = @[0.1, 0.1, 0.1]
    let heights = @[0.25, 0.25, 0.25] # @[0.35, 0.35, 0.35]
    let textYs = @[0.33, 0.27, 0.22]
    let dfRects = toDf(settings, ys, textYs, runs, heights, widths)

    
    plt = plt +
      geom_tile(data = dfRects, aes = aes(x = "runs", y = "ys", height = "heights", width = "widths", fill = "settings"),
                alpha = 0.3) +
      geom_text(data = dfRects, aes = aes(x = f{`runs` + 35}, y = "textYs", text = "settings")) +
      xlim(80, 200)
  plt + geom_point() +
    ylim(0.1, 0.35) +
    ylab("⁵⁵Fe peak position [V]") + xlab("Run number") +
    ggtitle("Peak position of the ⁵⁵Fe runs in the FADC data") + 
    ggsave(outname)

  if is2017:
    writeCsv(df, "resources/peak_positions_fadc_run2.csv")
  elif is2018:
    writeCsv(df, "resources/peak_positions_fadc_run3.csv")
      
when isMainModule:
  import cligen
  dispatch main

