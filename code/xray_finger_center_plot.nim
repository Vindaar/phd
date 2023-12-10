import nimhdf5, ggplotnim, options
import ingrid / tos_helpers
import std / [strutils, tables]

proc main(run: int, switchAxes: bool = false, useTeX = false) =
  let file = "/t/reco_xray_finger_$#.h5" % $run
  
  #proc readClusters(h5f: H5File): (seq[float], seq[float]) =
  var h5f = H5open(file, "r")
  
  # compute counts based on number of each pixel hit
  proc toIdx(x: float): int = (x / 14.0 * 256.0).round.int.clamp(0, 255)
  var ctab = initCountTable[(int, int)]() 
  
  var df = readRunDsets(h5f, run = run,
                        chipDsets = some((
                        chip: 3, dsets: @["centerX", "centerY"])))
    .mutate(f{"xidx" ~ toIdx(idx("centerX"))},
            f{"yidx" ~ toIdx(idx("centerY"))})
  let xidx = df["xidx", int]
  let yidx = df["yidx", int]
  forEach x in xidx, y in yidx:
    inc cTab, (x, y)
  df = df.mutate(f{int: "count" ~ cTab[(`xidx`, `yidx`)]})
  let centerX = df["centerX", float].mean
  let centerY = df["centerY", float].mean
  discard h5f.close()
 
  echo "Center position of the cluster is at: (x, y) = (", centerX, ", ", centerY, ")"
  ## NOTE: Exchanging the axes for X and Y is equivalent to a 90° clockwise rotation for our data
  ## because the centerX values are inverted `(256 - x), applyPitchConversion`. 
  ## The real rotation of the Septemboard detector at CAST seen from the telescope onto the
  ## detector is precisely 90° clockwise. 
  let x = if switchAxes: "centerY" else: "centerX"
  let y = if switchAxes: "centerX" else: "centerY"
  let cX = if switchAxes: centerY else: centerX
  let cY = if switchAxes: centerX else: centerY
  ggplot(df, aes(x, y, color = "count")) +
    geom_point(size = 0.75) +
    geom_point(data = newDataFrame(), aes = aes(x = cX, y = cY),
               color = "red", marker = mkRotCross) + 
    scale_color_continuous() +
    ggtitle("X-ray finger clusters of run $#" % $run) +
    xlab(r"x [mm]") + ylab(r"y [mm]") + 
    xlim(0.0, 14.0) + ylim(0.0, 14.0) +
    margin(right = 3.5) + 
    #theme_scale(1.0, family = "serif") +
    coord_fixed(1.0) + 
    themeLatex(fWidth = 0.5, width = 600, baseTheme = sideBySide) +
    legendPosition(0.83, 0.0) + 
    ggsave("/home/basti/phd/Figs/CAST_Alignment/xray_finger_centers_run_$#.pdf" % $run,
           useTeX = useTeX, standalone = useTeX, dataAsBitmap = true)
           #useTeX = true, standalone = true)

when isMainModule:
  import cligen
  dispatch main
