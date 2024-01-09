import ggplotnim, seqmath
import std / [os, sequtils, strutils]
proc readRT(p: string): DataFrame =
  result = readCsv(p, sep = ' ', skipLines = 4, colNames = @["x", "y", "z"])
  result["File"] = p  
proc meanData(df: DataFrame): DataFrame =
  result = df.mutate(f{"x" ~ `x` - mean(col("x"))},
                     f{"y" ~ `y` - mean(col("y"))})
proc customSideBySide(): Theme =
  result = sideBySide()
  result.titleFont = some(font(8.0))

proc plots(df: DataFrame, title, outfile: string) =
  var customInferno = inferno()
  customInferno.colors[0] = 0 # transparent
  ggplot(df.filter(f{`x` >= -7.0 and `x` <= 7.0 and `y` >= -7.0 and `y` <= 7.0}),
         aes("x", "y", fill = "z")) +
    geom_raster() +
    scale_fill_gradient(customInferno) +
    xlab("x [mm]") + ylab("y [mm]") +
    xlim(-7.0, 7.0) + ylim(-7.0, 7.0) +
    coord_fixed(1.0) + 
    ggtitle(title) +
    themeLatex(fWidth = 0.5, width = 600, baseTheme = customSideBySide, useTeX = true) + 
    ggsave(outfile)
  
var dfs = newSeq[DataFrame]()
for f in walkFiles("/home/basti/org/resources/llnl_cast_nature_jaime_data/2016_DEC_Final_CAST_XRT/*2Dmap.txt"):
  echo "Reading: ", f
  dfs.add readRT(f)
echo "Summarize"
var df = dfs.assignStack()
df = df.group_by(@["x", "y"])
  .summarize(f{float: "z" << sum(`z`)},
             f{float: "zMean" << mean(`z`)})
  .mutate(f{"y" ~ col("y").max - idx(`y`)}) # invert the y axis
df = df.meanData()
plots(df,
      "LLNL raytracing of axion image (sum all energies)",
      "~/phd/Figs/rayTracing/raytracing_axion_image_llnl_jaime_all_energies.pdf")
