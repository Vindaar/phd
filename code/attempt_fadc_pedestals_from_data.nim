import std / [strutils, os, sequtils, sugar, algorithm]
import ggplotnim

# to read from H5 input
import nimhdf5
import ingrid / tos_helpers
import ingrid / ingrid_types

proc readFadc(f: string): DataFrame =
  # read the FADC files using our CSV parser. Everything `#` is header
  # aside from the last 3 lines. Skip those using `maxLines`
  result = readCsv(f, header = "#", maxLines = 10240)
    .rename(f{"val" <- "nb of channels: 0"})
  #result["Channel"] = toSeq(0 ..< result.len)
  result["Register"] = toSeq(0 ..< 2560).repeat(4).concat.sorted
  result["Channel"] = @[1, 2, 3, 4].repeat(2560).concat

const Size = 5000

proc getFadcDset(h5f: H5File, runNumber: int): H5DataSet =
  let fadcGroup = fadcRawPath(runNumber)
  doAssert fadcGroup in h5f
  let group = h5f[fadcGroup.grp_str]
  result = h5f[(group.name / "raw_fadc").dset_str]
  
proc readChannel(h5f: H5File, dset: H5DataSet, start: int): seq[uint16] =
  let toRead = min(Size, dset.shape[0] - start)
  result = read_hyperslab(dset, uint16,
                          offset = @[start, 0],
                          count = @[toRead, dset.shape[1]])
  
import weave
proc percIdx(q: float, len: int): int = (len.float * q).round.int

proc biasedTruncMean*[T](x: Tensor[T], axis: int, qLow, qHigh: float): Tensor[float] =
  ## Computes the *biased* truncated mean of `x` by removing the quantiles `qLow` on the
  ## bottom end and `qHigh` on the upper end.
  ## ends of the data. `q` should be given as a fraction of events to remove on both ends.
  ## E.g. `qLow = 0.05, qHigh = 0.99` removes anything below the 5-th percentile and above the 99-th.
  ##
  ## Note: uses `weave` internally to multithread along the desired axis!
  doAssert x.rank == 2
  result = newTensorUninit[float](x.shape[axis])
  init(Weave)
  let xBuf = x.toUnsafeView()
  let resBuf = result.toUnsafeView()
  let notAxis = if axis == 0: 1 else: 0
  let numH = x.shape[notAxis] # assuming row column major, 0 is # rows, 1 is # cols
  let numW = x.shape[axis]
  parallelFor i in 0 ..< numW:
    captures: {xBuf, resBuf, numH, numW, axis, qLow, qHigh}
    let xT = xBuf.fromBuffer(numH, numW)
    # get a sorted slice for index `i`
    let subSorted = xT.atAxisIndex(axis, i).squeeze.sorted
    let plow = percIdx(qLow, numH) 
    let phih = percIdx(qHigh, numH)

    var resT = resBuf.fromBuffer(numW)
    ## compute the biased truncated mean by slicing sorted data to lower and upper
    ## percentile index
    var red = 0.0 
    for j in max(0, plow) ..< min(numH, phih): # loop manually as data is `uint16` to convert
      red += subSorted[j].float
    resT[i] = red / (phih - plow).float
  syncRoot(Weave)
  exit(Weave)

defColumn(uint16, uint8)  
proc readFadcH5(f: string, runNumber: int): DataFrame = #seq[DataTable[colType(uint16, uint8)]] =
  let h5f = H5open(f, "r")
  let registers = toSeq(0 ..< 2560).repeat(4).concat.sorted
  let channels = @[1, 2, 3, 4].repeat(2560).concat
  let idxs = arange(3, 2560, 4)
  ## XXX: maybe just read the hyperslab that corresponds to a single channel over
  ## the whole run? That's the whole point of those after all.
  ##  -> That is way too slow unfortunately
  ## XXX: better replace logic by going row wise N elements instead of column wise.
  ## Has the advantage that our memory requirements are constant and not dependent
  ## on the number of elements in the run. If we then average over the resulting N
  ## pedestals, it should be fine.
  let dset = getFadcDset(h5f, runNumber)
  var val = newTensor[float](2560 * 4)
  when true:
    var slices = 0
    for i in arange(0, dset.shape[0], Size):
      # read 
      let data = readChannel(h5f, dset, i)
      let toRead = min(Size, dset.shape[0] - i)
      echo "Reading..."
      let dT = data.toTensor.reshape([toRead, data.len div toRead])
      echo "Read ", i, " to read up to : ", toRead, " now processing..."
      inc slices
      val += biasedTruncMean(dT, axis = 1, qLow = 0.2, qHigh = 0.98)
    for i in 0 ..< 2560 * 4:
      val[i] /= slices.float
  result = toDf({"Channel" : channels, val, "Register" : registers})
  #for fadc in h5f.iterFadcFromH5(runNumber):
  #  let datCh3 = fadc.data[idxs] # .mapIt(it.int)
  #  var df = toDf({"val" : dat, "Register" : registers, "Channel" : channels})
  #  result.add df

## Main function to avoid bug of closure capturing old variable  
proc readFadcData(path: string, runNumber: int): DataFrame =
  var df = newDataFrame()
  if path.endsWith(".h5"):
    doAssert runNumber > 0
    df = readFadcH5(path, runNumber)
  else:
    var dfs = newSeq[DataFrame]()
    var i = 0
    for f in walkFiles(path / "*.txt-fadc"):
      echo "Parsing ", f
      dfs.add readFadc(f)
      inc i
      if i > 5000: break
    let dfP = assignStack(dfs)
    var reg = newSeq[int]()
    var val = newSeq[float]()
    var chs = newSeq[int]()
    for (tup, subDf) in groups(dfP.group_by(["Channel", "Register"])):
      echo "At ", tup
      let p20 = percentile(subDf["val", float], 20)
      let p80 = percentile(subDf["val", float], 80)
      reg.add tup[1][1].toInt
      chs.add tup[0][1].toInt
      let dfF = if p80 - p20 > 0: subDf.filter(dfFn(subDf, f{float: `val` >= p20 and `val` <= p80}))
                else: subDf
      val.add dfF["val", float].mean
    df = toDf({"Channel" : chs, val, "Register" : reg})
  df.writeCsv("/t/pedestal.csv")
  echo df.pretty(-1)
  result = df

proc main(path: string, outfile: string = "/t/empirical_fadc_pedestal_diff.pdf",
          plotVoltage = false,
          runNumber = -1,
          onlyCsv = false
         ) =
  let pData = readFadcData(path, runNumber)
  if onlyCsv: return
  const path = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/pedestalRuns/"
  const file = "pedestalRun000042_1_182143774.txt-fadc"
  let pReal = readFadc(path / file)
  echo "DATA= ", pData
  echo "REAL= ", pReal
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
