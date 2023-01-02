import nimhdf5, ggplotnim
import std / [strutils, os, sequtils]
import ingrid / [tos_helpers, fadc_helpers, ingrid_types, fadc_analysis]

proc stripPrefix(s, p: string): string =
  result = s
  result.removePrefix(p)

proc plotIdx(df: DataFrame, fadcData: Tensor[float], runNumber, idx: int) =
  let xmin = df["xmin", int][idx]
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
  
  let dfLoc = toDf({ "x"         : toSeq(0 ..< 2560),
                     "baseline"  : baseline,
                     "data"      : fData,
                     "xminX"     : xminlineX, 
                     "xminY"     : xminlineY,
                     "riseStart" : riseStartX,
                     "fallStop"  : fallStopX })
                     # Comparison has to be done by hand unfortunately
  let path = "/t/fadc_spectrum_baseline_$#.pdf" % $idx
  ggplot(dfLoc, aes("x", "data")) +
    geom_line() +
    geom_point(color = color(0.1, 0.1, 0.1, 0.1)) +
    geom_line(aes = aes("x", "baseline"),
              color = "blue") +
    geom_line(data = dfLoc.head(2), aes = aes("xminX", "xminY"),
                     color = "red") +
    geom_line(data = dfLoc.head(2), aes = aes("riseStart", "xminY"),
                     color = "green") +
    geom_line(data = dfLoc.head(2), aes = aes("fallStop", "xminY"),
                     color = "pink") +
    ggtitle("FADC spectrum of run $# and index $#" % [$runNumber, $idx]) +
    xlab("FADC Register") + ylab("FADC signal voltage U [V]") + 
    ggsave(path)
  copyFile(path, "/t/fadc_spectrum_baseline.pdf")

proc toDf[U: object](x: U): DataFrame =
  result = newDataFrame()
  for field, val in fieldPairs(x):
    type T = typeof(val[0]) 
    when T isnot int and T is SomeInteger:
      result[field] = val.asType(int)
    elif T isnot float and T is SomeFloat:
      result[field] = val.asType(float)
    else:
      result[field] = val

proc plotFadc(h5f: H5File, runNumber, sleep: int) =
  var run = h5f.readRecoFadcRun(runNumber)
  var data = h5f.readRecoFadc(runNumber)  
  var df = data.toDf()
  df["minvals"] = run.minvals
  for idx in 0 ..< df.len:
    plotIdx(df, run.fadc_data, runNumber, idx)
    sleep(sleep)

proc main(fname: string, runNumber: int, sleep = 1000) =
  var h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  for run in fileInfo.runs:
    if run == runNumber:
      plotFadc(h5f, run, sleep)
      
when isMainModule:
  import cligen
  dispatch main
