const calib = "/mnt/1TB/CAST/2018_2/CalibrationRuns/Run_266_181107-22-14"
const back  = "/mnt/1TB/CAST/2018_2/DataRuns/Run_267_181108-02-05"
const cEv = 5898
const bEv = 1829 # this event is nice
import ingrid / tos_helpers
import std / [strformat, os, strutils, sequtils]
import ggplotnim

proc toFile(i: int, path: string): string =
  let z = align($i, 6, '0')
  path / &"data{z}.txt"

proc drawPlot() =   
  let protoFiles = readMemFilesIntoBuffer(@[toFile(cEv, calib), toFile(bEv, back)])
  var df = newDataFrame()
  var names = @["X-ray", "Background"]
  for (pf, name) in zip(protoFiles, names):
    let ev = processEventWithScanf(pf)
    let pix = ev.chips[3].pixels
    if pix.len == 0: return
    let dfL = toDf({ "x" : pix.mapIt(it.x.int), "y" : pix.mapIt(it.y.int),
                     "ToT" : pix.mapIt(it.ch.int), "type" : name })
    df.add dfL
  ggplot(df, aes("x", "y", color = "ToT")) +
    facet_wrap("type") +
    geom_point() +
    xlim(0, 256) + ylim(0, 256) +
    ggsave("/home/basti/phd/Figs/reco/gridpix_example_events.pdf", width = 1200, height = 600)

drawPlot()
