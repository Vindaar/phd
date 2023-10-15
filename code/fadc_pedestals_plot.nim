import std / [strutils, os, sequtils, algorithm]
import ggplotnim

const path = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/pedestalRuns/"
const file = "pedestalRun000042_1_182143774.txt-fadc"
# read the FADC files using our CSV parser. Everything `#` is header
# aside from the last 3 lines. Skip those using `maxLines`
var df = readCsv(path / file, header = "#", maxLines = 10240)
  .rename(f{"val" <- "nb of channels: 0"})
# generate indices 0, 0, 0, 0, 1, 1, 1, 1, ..., 2559, 2559, 2559, 2559 
df["Register"] = toSeq(0 ..< 2560).repeat(4).concat.sorted
df["Channel"] = @[1, 2, 3, 4].repeat(2560).concat
when false:
  df["Channel"] = @[1, 2, 3, 4].repeat(2560)
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
    geom_point(size = 1.0) +
    legendPosition(0.91, 0.0) +
    ggtitle("FADC channel values of pedestal run, split by even and odd channel numbers") +
    ggsave("/home/basti/phd/Figs/detector/calibration/fadc_pedestal_split_even_odd.pdf", width = 1200, height = 600)#
  #         useTeX = true, standalone = true)
else:
  ggplot(df.group_by("Channel").filter(f{float -> bool: `val` < percentile(col("val"), 99)}),
         aes("Register", "val", color = "Channel")) +
    facet_wrap("Channel", scales = "free") +
    geom_point(size = 2.0) +
    facetMargin(0.5) +
    margin(bottom = 1.0, right = 2.0) +
    legendPosition(0.87, 0.0) + 
    ylab("Register") + 
    ggtitle("FADC register pedestal values, split by channels") +    
    xlab("Channel", margin = 0.0) + 
    ggsave("/home/basti/phd/Figs/detector/calibration/fadc_pedestal_split_by_channel.pdf",
          useTeX = true, standalone = true)
