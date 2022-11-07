import std / [strutils, os, sequtils]
import ggplotnim

const path = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/pedestalRuns/"
const file = "pedestalRun000042_1_182143774.txt-fadc"
var df = readCsv(path / file, header = "#")
  .rename(f{"val" <- "nb of channels: 0"})
  .filter(f{"#" notin `val`})
  .mutate(f{"val" ~ `val`.parseFloat})
df["Channel"] = toSeq(0 ..< df.len)
df = df.mutate(f{int -> bool: "even?" ~ `Channel` mod 2 == 0})
echo df
echo df.tail(20)
ggplot(df, aes("Channel", "val", color = "even?")) +
  geom_point(size = 1.0) +
  ggtitle("FADC channel values of pedestal run") +  
  ggsave("/home/basti/phd/Figs/detector/calibration/fadc_pedestal_run.pdf")
#         useTeX = true, standalone = true)
ggplot(df.group_by("even?").filter(f{float -> bool: `val` < percentile(col("val"), 95)}),
       aes("Channel", "val", color = "even?")) +
  facet_wrap("even?", scales = "free") +
  facetMargin(0.5) +
  margin(bottom = 1.0, right = 3.0) +
  xlab("Channel", margin = 0.0) + 
  geom_point(size = 1.0) +
  legendPosition(0.91, 0.0) +
  ggtitle("FADC channel values of pedestal run, split by even and odd channel numbers") +
  ggsave("/home/basti/phd/Figs/detector/calibration/fadc_pedestal_split_even_odd.pdf", width = 1200, height = 600)#
#         useTeX = true, standalone = true)                                                                                               
