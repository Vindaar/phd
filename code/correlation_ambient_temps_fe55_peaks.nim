import std / [strutils, sequtils, times]
import os except FileInfo
import ggplotnim, nimhdf5
import ingrid / tos_helpers
import ingrid / ingrid_types

type
  FeFileKind = enum
    fePixel, feCharge, feFadc

const Peak = "μ"
const PeakNorm = "μ/μ_max"
const TempPeak = "(μ/T) / max"

const TempFile = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/cast_2017_2018_temperatures.csv"
const OrgFormat = "'<'yyyy-MM-dd ddd H:mm'>'"
var dfTemp = toDf(readCsv(TempFile))
  .filter(f{c"Temp / °" != "-"})
dfTemp["Timestamp"] = dfTemp["Date"].toTensor(string).map_inline(parseTime(x, OrgFormat, utc()).toUnix)

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

proc plotCorrelation(files: seq[string], kind: FeFileKind, gainDf: DataFrame) =
  let df = readFePeaks(files, feCharge)
    .filter(f{`Timestamp` >= 1.54e9})
  let t0 = df["Timestamp", float].min
  let t1 = df["Timestamp", float].max

  let dfTemp = dfTemp
    .filter(f{float: `Timestamp` >= t0 and `Timestamp` <= t1})
  var gainDf = gainDf
    .filter(f{float: `tStart` >= t0 and `tStart` <= t1})
  echo gainDf
  ggplot(gainDf, aes("tStart", "G")) +
    geom_point() +
    ggsave("/t/raw_gas_gain.pdf")
  let dfCastTemp = readCsv("/tmp/temperatures_cast.csv")
    .filter(f{float: `Time` >= t0 and `Time` <= t1})
    .group_by("Temperature")
    .mutate(f{"TempNorm" ~ `TempVal` / max(col("TempVal"))})
    .filter(f{`Temperature` != "T_ext"})

  ## XXX: combine point like data for legend?
  # let dfC = bind_rows([("Fe55", df), ("SeptemTemp", dfTemp)], "Type")

    
  ggplot(df, aes("Timestamp", PeakNorm)) +
    geom_point(data = gainDf, aes = aes("tStart", f{float: `G` / max(col("G"))}, color = "Chip"), alpha = 0.7, size = 1.5) + 
    geom_line(data = dfCastTemp, aes = aes("Time", "TempNorm", color = "Temperature")) +
    geom_point(data = dfTemp, aes = aes("Timestamp", f{idx("Temp / °") / max(col("Temp / °"))}), color = "blue") +
    geom_point() +
    ggtitle("Correlation between temperatures (Septem = blue points) & 55Fe position " & $kind & " (black) and gas gains by chip", titleFont = font(11.0)) + 
    ggsave("/tmp/correlation_" & $kind & "_all_chips_gasgain.pdf", width = 1000, height = 600)
    
  gainDf = gainDf.filter(f{`Chip` == 3})
  ggplot(df, aes("Timestamp", PeakNorm)) +
    geom_point(data = gainDf, aes = aes("tStart", f{float: `G` / max(col("G"))}), color = "purple", alpha = 0.7, size = 1.5) + 
    geom_line(data = dfCastTemp, aes = aes("Time", "TempNorm", color = "Temperature")) +
    geom_point(data = dfTemp, aes = aes("Timestamp", f{idx("Temp / °") / max(col("Temp / °"))}), color = "blue") +
    geom_point() +
    ggtitle("Correlation between temperatures (Septem = blue points) & 55Fe position " & $kind & " (black) and gas gains (chip3) in purple", titleFont = font(11.0)) +     
    ggsave("/tmp/correlation_" & $kind & ".pdf", width = 1000, height = 600)
    

proc main(calibFiles: seq[string], dataFiles: seq[string] = @[]) =
  ## NOTE: this file needs the CSV file containing the temperature data from the slow control
  ## CAST log files, which is written running the `cast_log_reader` on the slow control log
  ## directory!
  var gainDf = newDataFrame()
  if dataFiles.len > 0:
    gainDf = readGasGainSliceData(dataFiles)
  plotCorrelation(calibFiles, fePixel, gainDf)
  plotCorrelation(calibFiles, feCharge, gainDf)

when isMainModule:
  import cligen
  dispatch main
