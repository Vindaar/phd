import shell, strutils, sequtils
import nimhdf5
import ingrid / [ingrid_types, tos_helpers]

const filePath = "~/CastData/data/CalibrationRuns$#_Reco.h5"
const genData = """
fake_event_generator \
    like \
    -p $file \
    --run $run \
    --outpath $fakeFile \
    --outRun $run \
    --tfKind Mn-Cr-12kV \
    --nmc 50000
"""
const plotData = """
plotDatasetGgplot \
    -f $file \
    -f $fakeFile \
    --names 55Fe --names Simulation \
    --run $run \
    --plotPath /home/basti/phd/Figs/fakeEventSimulation/runComparisons/ \
    --prefix ingrid_properties_run_$run \
    --suffix ", run $run"
"""

proc main(generate = false,
          plot = false,
          fakeFile = "~/org/resources/fake_events_for_runs.h5") =
  const years = [2017, 2018]
  for year in years:
    #if year == "2017": continue ## skip for now, already done
    let file = filePath % [$year]
    var runs = newSeq[int]()
    withH5(file, "r"):
      let fileInfo = getFileInfo(h5f)
      runs = fileInfo.runs
    for run in runs:
      echo "Working on run: ", run
      if generate:
        let genCmd = genData % ["file", file, "run", $run, "fakeFile", fakeFile]
        shell:
          ($genCmd)
      if plot:
        let plotCmd = plotData % ["file", file, "fakeFile", fakeFile, "run", $run, "run", $run, "run", $run]
        shell:
          ($plotCmd)
when isMainModule:
  import cligen
  dispatch main
