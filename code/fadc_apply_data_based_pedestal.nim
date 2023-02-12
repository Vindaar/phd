import nimhdf5, ggplotnim
import std / [strutils, os, sequtils]
import ingrid / [tos_helpers, fadc_helpers, ingrid_types, fadc_analysis]

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

proc plotCompare(data, real: Tensor[float]) =
  let path = "/t/fadc_spectrum_compare.pdf"
  for idx in 0 ..< data.shape[0]:
    let df = toDf({ "x" : toSeq(0 ..< 2560),
                    "data" : data[idx, _].squeeze,
                    "real" : real[idx, _].squeeze })
      .gather(["data", "real"], "type", "vals")
    ggplot(df, aes("x", "vals", color = "type")) +
      geom_line() +
      #geom_point(color = color(0.1, 0.1, 0.1, 0.1)) +
      ggsave(path)
    sleep(1000)

proc getFadcData(fadcRun: ProcessedFadcRun, pedestal: seq[uint16]): Tensor[float] =
  let ch0 = getCh0Indices()
  let
    fadc_ch0_indices = getCh0Indices()
    # we demand at least 4 dips, before we can consider an event as noisy
    n_dips = 4
    # the percentile considered for the calculation of the minimum
    min_percentile = 0.95
    numFiles = fadcRun.eventNumber.len
  
  var fData = ReconstructedFadcRun(
    fadc_data: newTensorUninit[float]([numFiles, 2560]),
    eventNumber: fadcRun.eventNumber,
    noisy: newSeq[int](numFiles),
    minVals: newSeq[float](numFiles)
  )

  for i in 0 ..< fadcRun.eventNumber.len:
    let slice = fadcRun.rawFadcData[i, _].squeeze
    let data = slice.fadcFileToFadcData(
      pedestal,
      fadcRun.trigRecs[i], fadcRun.settings.postTrig, fadcRun.settings.bitMode14,
      fadc_ch0_indices).data
    fData.fadc_data[i, _] = data.unsqueeze(axis = 0)
    fData.noisy[i]        = data.isFadcFileNoisy(n_dips)
    fData.minVals[i]      = data.calcMinOfPulse(min_percentile)
  when false:
    let data = fData.fadcData.toSeq2D
    let (baseline, xMin, riseStart, fallStop, riseTime, fallTime) = calcRiseAndFallTime(
      data, 
      false
    )
    let df = toDf({ "argMinval" : xMin.mapIt(it.float),
                    "baseline" : baseline.mapIt(it.float),
                    "riseStart" : riseStart.mapIt(it.float),
                    "fallStop" : fallStop.mapIt(it.float),
                    "riseTime" : riseTime.mapIt(it.float),
                    "fallTime" : fallTime.mapIt(it.float),
                    "minvals" : fData.minvals })
    for idx in 0 ..< df.len:
      plotIdx(df, fData.fadc_data, idx)
      sleep(1000)

  result = fData.fadcData

proc readFadc(f: string): DataFrame =
  # read the FADC files using our CSV parser. Everything `#` is header
  # aside from the last 3 lines. Skip those using `maxLines`
  result = readCsv(f, header = "#", maxLines = 10240)
    .rename(f{"val" <- "nb of channels: 0"})
  #result["Channel"] = toSeq(0 ..< result.len)
  result["Register"] = toSeq(0 ..< 2560).repeat(4).concat.sorted
  result["Channel"] = @[1, 2, 3, 4].repeat(2560).concat

proc main(fname: string, runNumber: int) =
  var h5f = H5open(fname, "r")
  let pedestal = readCsv("/t/pedestal.csv") # created from above
    .arrange(["Register", "Channel"])
  echo pedestal
  const path = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/pedestalRuns/"
  const file = "pedestalRun000042_1_182143774.txt-fadc"
  let pReal = readFadc(path / file)
  
  let fileInfo = h5f.getFileInfo()
  for run in fileInfo.runs:
    if run == runNumber:
      let fadcRun = h5f.readFadcFromH5(run)
      let fromData = fadcRun.getFadcData(pedestal["val", uint16].toSeq1D)
      let fromReal = fadcRun.getFadcData(pReal["val", uint16].toSeq1D)

      plotCompare(fromData, fromReal)
      
when isMainModule:
  import cligen
  dispatch main
