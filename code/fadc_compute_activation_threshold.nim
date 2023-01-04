import nimhdf5, ggplotnim
import std / [strutils, os, sequtils]
import ingrid / [tos_helpers, fadc_helpers, ingrid_types, fadc_analysis]

proc fadcSettingRuns(): seq[int] =
  result = @[0, 101, 121]

proc stripPrefix(s, p: string): string =
  result = s
  result.removePrefix(p)

proc minimum(h5f: H5File, runNumber: int, percentile: int): (float, float) =
  var df = h5f.readRunDsets(
    runNumber,
    chipDsets = some((chip: 3, dsets: @["energyFromCharge", "eventNumber"]))
  )
  # sum all energies of all same events to get a combined energy of all
  # clusters on the center chip in each event (to correlate w/ FADC)
  df = df.group_by("eventNumber").summarize(f{float -> float: "energyFromCharge" << sum(col("energyFromCharge"))})
  var run = h5f.readRecoFadcRun(runNumber)
  let dfFadc = toDf({ "eventNumber" : run.eventNumber,
                      "minVals" : run.minVals })
  # join both by `eventNumber` (dropping center chip events w/ no FADC)
  df = innerJoin(df, dfFadc, "eventNumber")
  # percentile based on minvals & gridpix energy
  result = (percentile(run.minvals.mapIt(it.abs), percentile), percentile(df["energyFromCharge", float], percentile))

proc main(fname: string, percentile: int) =
  var h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  echo fileInfo
  var minimaFadc = newSeq[float]()
  var minimaGP = newSeq[float]()  
  var idxs = newSeq[int]()
  for run in fileInfo.runs:
    let idx = lowerBound(fadcSettingRuns(), run)
    echo "idx ", idx, " for run ", run
    let (minFadc, minEnergy) = minimum(h5f, run, percentile)
    minimaFadc.add minFadc
    minimaGP.add minEnergy
    idxs.add idx

  let df = toDf(minimaFadc, minimaGP, idxs)
  ggplot(df, aes("minimaFadc", fill = "idxs")) +
    geom_histogram(position = "identity", alpha = 0.5, hdKind = hdOutline) +
    ggsave("/t/fadc_minima.pdf")

  ggplot(df, aes("minimaGP", fill = "idxs")) +
    geom_histogram(position = "identity", alpha = 0.5, hdKind = hdOutline) +
    ggsave("/t/fadc_minima_gridpix_energy.pdf")    

when isMainModule:
  import cligen
  dispatch main
