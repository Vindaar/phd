import std / [strutils, os, sequtils, sugar, algorithm]
import ggplotnim

proc readFadc(f: string): DataFrame =
  # read the FADC files using our CSV parser. Everything `#` is header
  # aside from the last 3 lines. Skip those using `maxLines`
  result = readCsv(f, header = "#", maxLines = 10240)
    .rename(f{"val" <- "nb of channels: 0"})
  #result["Channel"] = toSeq(0 ..< result.len)
  result["Register"] = toSeq(0 ..< 2560).repeat(4).concat.sorted
  result["Channel"] = @[1, 2, 3, 4].repeat(2560).concat

## Main function to avoid bug of closure capturing old variable  
proc readFadcData(path: string): DataFrame =
  var dfs = newSeq[DataFrame]()
  var i = 0
  for f in walkFiles(path / "*.txt-fadc"):
    echo "Parsing ", f
    dfs.add readFadc(f)
    inc i
    #if i > 100: break
  let df = assignStack(dfs)
  var reg = newSeq[int]()
  var val = newSeq[float]()
  var chs = newSeq[int]()
  for (tup, subDf) in groups(df.group_by(["Channel", "Register"])):
    let p20 = percentile(subDf["val", float], 20)
    let p80 = percentile(subDf["val", float], 80)
    reg.add tup[1][1].toInt
    chs.add tup[0][1].toInt
    let dfF = if p80 - p20 > 0: subDf.filter(f{float: `val` >= p20 and `val` <= p80})
             else: subDf
    val.add dfF["val", float].mean
  let dfP = toDf({"Channel" : chs, val, "Register" : reg})
  dfP.writeCsv("/t/pedestal.csv")
  echo dfP.pretty(-1)
  result = dfP

proc main(path: string, outfile: string = "/t/empirical_fadc_pedestal_diff.pdf",
          plotVoltage = false) =
  let pData = readFadcData(path)
  
  const path = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/pedestalRuns/"
  const file = "pedestalRun000042_1_182143774.txt-fadc"
  let pReal = readFadc(path / file)
  echo pData
  echo pReal
  var df = bind_rows([("Data", pData), ("Real", pReal)], "ID")
    .spread("ID", "val")
    .mutate(f{"Diff" ~ abs(`Data` - `Real`)})
    # alternatively compute the voltage corresponding to the FADC register values,
    # assuming 12 bit working mode (sampling_mode == 0)
    .mutate(f{"DiffVolt" ~ `Diff` / 2048.0})
  var plt: GgPlot
  if plotVoltage:
    plt = ggplot(df, aes("Register", "DiffVolt", color = "Channel")) +
      ylim(0, 100.0 / 2048.0)    
  else:
    plt = ggplot(df, aes("Register", "Diff", color = "Channel")) +
      ylim(0, 100)
  plt +
    geom_point(size = 1.5, alpha = 0.75) +
    ylab("Difference between mean and actual pedestal [ADC]") + 
    ggtitle("Attempt at computing pedestal values based on truncated mean of data") +
    margin(top = 2) +
    xlim(0, 2560) + 
    ggsave(outfile)
  
when isMainModule:
  import cligen
  dispatch main