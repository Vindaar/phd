# Laptop
#const calib = "/mnt/1TB/CAST/2018_2/CalibrationRuns/Run_266_181107-22-14"
#const back  = "/mnt/1TB/CAST/2018_2/DataRuns/Run_267_181108-02-05"
# Desktop
# All raw files found in `/mnt/4TB/CAST`. The two runs needed here copied to
from std/os import expandTilde
const calib = "~/CastData/data/2018_2/Run_266_181107-22-14" # calibration
const back  = "~/CastData/data/2018_2/Run_267_181108-02-05" # data

const cEv = 5898
const bEv = 1829 # this event is nice
import ingrid / tos_helpers
import std / [strformat, os, strutils, sequtils]
import ggplotnim

proc toFile(i: int, path: string): string =
  let z = align($i, 6, '0')
  path / &"data{z}.txt"

proc drawPlot() =   
  let protoFiles = readMemFilesIntoBuffer(@[toFile(cEv, calib.expandTilde), toFile(bEv, back.expandTilde)])
  var df = newDataFrame()
  var names = @["X-ray", "Background"]
  for (pf, name) in zip(protoFiles, names):
    let ev = processEventWithScanf(pf)
    let pix = ev.chips[3].pixels
    if pix.len == 0: return
    let dfL = toDf({ "x" : pix.mapIt(it.x.int), "y" : pix.mapIt(it.y.int),
                     "ToT" : pix.mapIt(it.ch.int), "type" : name })
    df.add dfL
  echo df
  ggplot(df, aes("x", "y", color = "ToT")) +
    facet_wrap("type") +
    geom_point() +
    xlim(0, 256) + ylim(0, 256) +
    #theme_font_scale(2.0) +
    #margin(left = 3, bottom = 3, right = 5) +
    margin(right = 3.5) + 
    #facetHeaderText(font = font(12.0, alignKind = taCenter)) +
    xlab("x [Pixel]", margin = 1.5) + ylab("y [Pixel]", margin = 2) + 
    legendPosition(0.88, 0.0) +
    themeLatex(fWidth = 0.9, width = 800, height = 400, baseTheme = singlePlot) + 
    ggsave("/home/basti/phd/Figs/reco/gridpix_example_events.pdf", width = 800, height = 400, useTeX = true, standalone = true)

drawPlot()
