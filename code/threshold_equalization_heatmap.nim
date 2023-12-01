import ggplotnim
import std / [sequtils, strutils, strformat]

proc main(fname, runPeriod: string, chip: int) =
  let aranged = toSeq(0 .. 255).mapIt($it)
  var df = readCsv(fname, sep = '\t', colNames = aranged)
  df["y"] = toSeq(0 .. 255)
  df = df.gather(aranged, "x", "4-bit DAC")
    .mutate(f{"x" ~ `x`.parseInt})
  echo df
  
  ggplot(df, aes("x", "y", fill = "4-bit DAC")) +
    geom_raster() + 
    #scale_x_continuous() +
    #xlim(-0.5, 16.5) +
    xlim(0, 255) + ylim(0, 255) + 
    ggtitle(&"Equalization bits after optimization, {runPeriod}, chip: {chip}") + 
    ggsave(&"/home/basti/phd/Figs/detector/calibration/heatmap_threshold_equalization_{runPeriod}_chip_{chip}.pdf",
           useTeX = true, standalone = true)

when isMainModule:
  import cligen
  dispatch main
