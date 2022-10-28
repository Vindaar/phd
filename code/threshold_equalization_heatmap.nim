import ggplotnim
import std / [sequtils, strutils]

proc main(fname: string) =
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
    ggtitle("Heatmap of all equalization bits after optimization") + 
    ggsave("/home/basti/phd/Figs/detector/calibration/heatmap_threshold_equalization_example.pdf",
           useTeX = true, standalone = true)

when isMainModule:
  import cligen
  dispatch main
