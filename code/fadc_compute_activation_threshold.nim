import nimhdf5, ggplotnim
import std / [strutils, os, sequtils]
import ingrid / [tos_helpers, fadc_helpers, ingrid_types, fadc_analysis]

proc fadcSettingRuns(): seq[int] =
  result = @[0, 101, 121]

proc minimum(h5f: H5File, runNumber: int, percentile: int): float =
  var run = h5f.readRecoFadcRun(runNumber)
  result = percentile(run.minvals, percentile)

proc main(fname: string, percentile: int) =
  var h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  echo fileInfo
  var minima = newSeq[float]()
  var idxs = newSeq[int]()
  for run in fileInfo.runs:
    let idx = lowerBound(fadcSettingRuns(), run)
    echo "idx ", idx, " for run ", run
    minima.add minimum(h5f, run, percentile)
    idxs.add idx
  ggplot(toDf(minima, idxs), aes("minima", fill = "idxs")) +
    geom_histogram(position = "identity", alpha = 0.5, hdKind = hdOutline) +
    ggsave("/t/fadc_minima.pdf")

when isMainModule:
  import cligen
  dispatch main
