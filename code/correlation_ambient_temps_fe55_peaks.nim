import std / [strutils, sequtils, times, stats, strformat]
import os except FileInfo
import ggplotnim, nimhdf5
import ingrid / tos_helpers
import ingrid / ingrid_types

type
  FeFileKind = enum
    fePixel, feCharge, feFadc

let UseTex = getEnv("USE_TEX", "false").parseBool
let Width = getEnv("WIDTH", "1000").parseFloat
let Height = getEnv("HEIGHT", "600").parseFloat

const Peak = "μ"
let PeakNorm = if UseTex: r"$μ/μ_{\text{max}}$" else: "μ/μ_max"
const TempPeak = "(μ/T) / max"
let T_amb = if UseTex: r"$T_{\text{amb}}$" else: "T_amb"

proc readFePeaks(files: seq[string], feKind: FeFileKind = fePixel): DataFrame =
  const kalphaPix = 10
  const kalphaCharge = 4
  const parPrefix = "p"
  const dateStr = "yyyy-MM-dd'.'HH:mm:ss" # example: 2017-12-04.13:39:45
  var dset: string
  var kalphaIdx: int
  case feKind
  of fePixel:
    kalphaIdx = kalphaPix
    dset = "FeSpectrum"
  of feCharge:
    kalphaIdx = kalphaCharge
    dset = "FeSpectrumCharge"
  of feFadc:
    kalphaIdx = kalphaCharge
    dset = "FeSpectrumFadcPlot" # raw dataset is `minvals` instead of `FeSpectrumFadc`

  var h5files = files.mapIt(H5open(it, "r"))
  var fileInfos = newSeq[FileInfo]()
  for h5f in mitems(h5files):
    let fi = h5f.getFileInfo()
    fileInfos.add fi
  var
    peakSeq = newSeq[float]()
    dateSeq = newSeq[float]()
  for (h5f, fi) in zip(h5files, fileInfos):
    for r in fi.runs:
      let group = h5f[(recoBase() & $r).grp_str]
      let chpGrpName = if feKind in {fePixel, feCharge}: group.name / "chip_3"
                       else: group.name / "fadc"
      peakSeq.add h5f[(chpGrpName / dset).dset_str].attrs[
        parPrefix & $kalphaIdx, float
      ]
      dateSeq.add parseTime(group.attrs["dateTime", string],
                            dateStr,
                            utc()).toUnix.float
  result = toDf({ Peak : peakSeq,
                  "Timestamp" : dateSeq })
    .arrange("Timestamp", SortOrder.Ascending)
    .mutate(f{float: PeakNorm ~ idx(Peak) / max(col(Peak))},
            f{"Type" <- $feKind})

proc toDf[T: object](data: seq[T]): DataFrame =
  ## Converts a seq of objects that (may only contain scalar fields) to a DF
  result = newDataFrame()
  for i, d in data:
    for field, val in fieldPairs(d):
      if field notin result:
        result[field] = newColumn(toColKind(type(val)), data.len)
      result[field, i] = val
    
proc readGasGainSliceData(files: seq[string]): DataFrame =     
  result = newDataFrame()
  for f in files:
    let h5f = H5file(f, "r")
    let fInfo = h5f.getFileInfo()
    for r in fInfo.runs:
      for c in fInfo.chips:
        let group = recoDataChipBase(r) & $c
        var gainSlicesDf = h5f[group & "/gasGainSlices90", GasGainIntervalResult].toDf
        gainSlicesDf["Chip"] = c
        gainSlicesDf["Run"] = r
        gainSlicesDf["File"] = f
        result.add gainSlicesDf
    discard h5f.close()

const periods = [("2017-10-30", "2017-12-23"),
                 ("2018-02-15", "2018-04-22"),
                 ("2018-10-19", "2018-12-21")]

proc toPeriod(x: int): string =
  let date = x.fromUnix()
  for p in periods:
    let t0 = p[0].parseTime("YYYY-MM-dd", utc())
    let t1 = p[1].parseTime("YYYY-MM-dd", utc())
    if date >= t0 and date <= t1: return p[0]
  
proc mapToPeriod(df: DataFrame, timeCol: string): DataFrame =
  result = df.mutate(f{int -> string: "RunPeriod" ~ toPeriod(idx(timeCol))})
    .filter(f{string -> bool: `RunPeriod`.len > 0})

proc readSeptemTemps(): DataFrame =
  const TempFile = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/cast_2017_2018_temperatures.csv"
  const OrgFormat = "'<'yyyy-MM-dd ddd H:mm'>'"
  result = toDf(readCsv(TempFile))
    .filter(f{c"Temp / °" != "-"})
  result["Timestamp"] = result["Date"].toTensor(string).map_inline(parseTime(x, OrgFormat, utc()).toUnix)

proc readCastTemps(): DataFrame =
  result = readCsv("/tmp/temperatures_cast.csv")
    #.filter(f{float: `Time` >= t0 and `Time` <= t1})
    .group_by("Temperature")
    .mutate(f{"TempNorm" ~ `TempVal` / max(col("TempVal"))})
    .filter(f{`Temperature` != "T_ext"})
  var newKeys = newSeq[(string, string)]()
  if UseTex:
    result = result.mutate(f{string -> string: "Temperature" ~ (
      let suff = `Temperature`.split("_")[1] 
      r"$T_{\text{" & suff & "}}$")
    })
    echo "Resulting DF: ", result

proc toPeriod(v: float): string =
  result = v.int.fromUnix.format("dd/MM/YYYY")

proc keepEvery(df: DataFrame, num: int): DataFrame =
  ## Keeps only every `num` row of the data frame
  result = df
  result["idxMod"] = toSeq(0 ..< df.len)
  result = result.filter(f{int -> bool: `idxMod` mod num == 0})
    
proc plotCorrelationPerPeriod(df: DataFrame, kind: FeFileKind, gainDf, dfCastTemp, dfTemp: DataFrame,
                              period, outpath = "/tmp") =
  let t0 = df["Timestamp", float].min
  let t1 = df["Timestamp", float].max

  let dfCastTemp = dfCastTemp
    .keepEvery(50)
    .filter(f{float: `Time` >= t0 and `Time` <= t1})  
  let dfTemp = dfTemp
    .filter(f{float: `Timestamp` >= t0 and `Timestamp` <= t1})
  var gainDf = gainDf
    .filter(f{float: `tStart` >= t0 and `tStart` <= t1})
    .mutate(f{float: "gainNorm" ~ `G` / max(col("G"))})
  echo gainDf

  ## XXX: combine point like data for legend?
  # let dfC = bind_rows([("Fe55", df), ("SeptemTemp", dfTemp)], "Type")
  var plt = ggplot(df, aes("Timestamp", PeakNorm)) +
    geom_line(data = dfCastTemp, aes = aes("Time", "TempNorm", color = "Temperature")) +
    geom_point() +
    scale_x_continuous(labels = toPeriod) 

  if dfTemp.len > 0: # only if septemboard data available in this period
    plt = plt + geom_point(data = dfTemp, aes = aes("Timestamp", f{idx("Temp / °") / max(col("Temp / °"))}), color = "blue")

  

  block AllChips:
    plt + geom_point(data = gainDf, aes = aes("tStart", "gainNorm", color = gradient("Chip")), alpha = 0.7, size = 1.5) +
      ggtitle("Correlation between temperatures (Septem = blue points) \\& 55Fe position " & $kind &
        " (black) and gas gains by chip", titleFont = font(11.0)) +
      themeLatex(fWidth = 0.9, textWidth = 677.3971, # the `\textheight`, want to insert in landscape
                  width = Width, height = Height, baseTheme = singlePlot) +
      margin(bottom = 2.5) + 
      ggsave(&"{outpath}/correlation_{kind}_all_chips_gasgain_period_{period}.pdf",
              width = 1000, height = 600,
              useTeX = UseTeX, standalone = UseTeX)                                                                              

  block CenterChip:
    gainDf = gainDf.filter(f{`Chip` == 3})
    plt + geom_point(data = gainDf, aes = aes("tStart", "gainNorm"), color = "purple", alpha = 0.7, size = 1.5) + 
      ggtitle("Correlation between temperatures (Septem = blue points) \\& 55Fe position " & $kind &
        " (black) and gas gains (chip3) in purple", titleFont = font(11.0)) +
      themeLatex(fWidth = 0.9, textWidth = 677.3971, # the `\textheight`, want to insert in landscape
                 width = Width, height = Height, baseTheme = singlePlot) + 
      ggsave(&"{outpath}/correlation_{kind}_period_{period}.pdf", width = 1000, height = 600,
             useTeX = UseTeX, standalone = UseTeX)                                   

proc plotCorrelation(files: seq[string], kind: FeFileKind, gainDf, dfCastTemp, dfTemp: DataFrame,
                     outpath = "/tmp") =
  let df = readFePeaks(files, feCharge)
    .mapToPeriod("Timestamp")

  for (tup, subDf) in groups(df.group_by("RunPeriod")):
    plotCorrelationPerPeriod(subDf, kind, gainDf, dfCastTemp, dfTemp, tup[0][1].toStr, outpath)

proc plotTempVsGain(dfCastTemp, gainDf: DataFrame, outpath: string) =    
  ## Now let's plot the actual gas gain against the temperature in each slice.
  ## Only for the center chip.
  ## 1. compute mean temperature within time associated with each gain value
  # dfCastTemp
  # gainDf
  ## NOTE: We do not compute the mean temperature associated with the
  proc mapGainToTemp(gainDf, dfCastTemp: DataFrame, period: string): DataFrame =
    let t0G = gainDf["tStart", int].min
    let t1G = gainDf["tStop", int].max
    # filter temperature data to relevant range
    echo dfCastTemp.isNil
    echo dfCastTemp
    let dfF = dfCastTemp
       .filter(f{int: `Time` >= t0G and `Time` <= t1G},
               f{string -> bool: `Temperature` == T_amb})
      
    var cT: RunningStat    
    let ambT = dfF["TempVal", float]
    let time = dfF["Time", int]    
  
    var j = 0
    let gDf = gainDf.filter(f{int -> bool: `Chip` == 3})
    var temps = newSeq[float](gDf.len)
    ## we now walk all temperatures and accumulate them in a `RunningStat` to compute
    ## the mean within `tStart` and `tStop` (by `tStart` of the next slice).
    ## First and last are just copied from ambient temperature values.
    temps[0] = ambT[0]    
    for i in 1 ..< gDf.high:
      while time[j] < gDf["tStart", int][i]:
        cT.push ambT[j]
        inc j
      temps[i] = cT.mean
      cT.clear()
    temps[gDf.high] = ambT[ambT.len - 1]
    let gains = gDf["G", float]
    result = toDf(temps, gains, period)

  var dfGT = newDataFrame()
  for (tup, subDf) in groups(gainDf.groupBy("RunPeriod")):
    dfGT.add mapGainToTemp(subDf, dfCastTemp, tup[0][1].toStr)
  echo dfGT
  echo dfGT.tail(100)
  ggplot(dfGT.filter(f{`temps` > 0.0}), aes("temps", "gains", color = "period")) +
    geom_point() +
    ggtitle("Gas gain (90 min slices) vs ambient T at CAST (center chip)") +
    xlab("Temperature [°C]") + ylab("Gas gain") +
    themeLatex(fWidth = 0.9, width = 600, baseTheme = singlePlot) +
    ggsave(&"{outpath}/gain_vs_temp_center_chip.pdf",
           width = 600, height = 360,
           useTeX = UseTeX, standalone = UseTeX)            
      
proc main(calibFiles: seq[string], dataFiles: seq[string] = @[],
          outpath = "/tmp/") =
  ## NOTE: this file needs the CSV file containing the temperature data from the slow control
  ## CAST log files, which is written running the `cast_log_reader` on the slow control log
  ## directory!
  var gainDf = newDataFrame()
  if dataFiles.len > 0:
    gainDf = readGasGainSliceData(dataFiles)
      .mapToPeriod("tStart")
    ## Make a plot of the raw gas gains of all chips
    ggplot(gainDf, aes("tStart", "G", color = "Chip")) +
      geom_point(size = 2.0) +
      ggtitle("Raw gas gain values in 90 min bins for all chips") +
      themeLatex(fWidth = 0.9, width = Width, height = Height, baseTheme = singlePlot) +       
      ggsave(&"{outpath}/raw_gas_gain.pdf",
             width = 600, height = 360, 
             useTeX = UseTeX, standalone = UseTeX)              

  let dfCastTemp = readCastTemps()
  let dfTemp = readSeptemTemps()
  plotTempVsGain(dfCastTemp, gainDf, outpath)
      
  plotCorrelation(calibFiles, fePixel,  gainDf, dfCastTemp, dfTemp, outpath)
  plotCorrelation(calibFiles, feCharge, gainDf, dfCastTemp, dfTemp, outpath)

when isMainModule:
  import cligen
  dispatch main
