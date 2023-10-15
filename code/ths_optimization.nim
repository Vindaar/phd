import ggplotnim

proc main(fname: string) =
  var df = readCsv(fname, sep = '\t', colNames = @["x", "y", "min", "max", "bit", "opt"])
  let breaks = linspace(-0.5, 15.5, 17).toSeq1D
  echo breaks
  ggplot(df, aes("bit")) +
    geom_histogram(breaks = breaks, hdKind = hdOutline) +
    scale_x_continuous() +
    xlim(-0.5, 16.5) +
    xlab("4-bit DAC") + 
    ggtitle("Distribution of all equalization bits after optimization") + 
    ggsave("/home/basti/phd/Figs/detector/calibration/optimized_equalization_bits_example.pdf",
           useTeX = true, standalone = true)
  df = df.gather(["min", "max", "opt"], "type", "THL")
  ggplot(df.filter(f{`THL` > 330.0 and `THL` < 460.0}), aes("THL", fill = "type")) +
    geom_histogram(binWidth = 1.0, position = "identity", hdKind = hdOutline, alpha = 0.7) +
    ggtitle("THL distributions for all equalization bits at 0, 15 and optimized") +
    #xlim(330, 460) + 
    ggsave("/home/basti/phd/Figs/detector/calibration/ths_optimization_distributions_example.pdf",
           useTeX = true, standalone = true)
when isMainModule:
  import cligen
  dispatch main
