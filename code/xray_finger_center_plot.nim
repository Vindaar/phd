import nimhdf5, ggplotnim, options
import ingrid / tos_helpers
import std / [strutils, tables]

proc main(run: int) =
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
  ggplot(df, aes("centerX", "centerY", color = "count")) +
    geom_point(size = 0.75) +
    geom_point(data = newDataFrame(), aes = aes(x = centerX, y = centerY),
               color = "red", marker = mkRotCross) + 
    scale_color_continuous() +
    ggtitle("X-ray finger clusters of run $#" % $run) +
    xlim(0.0, 14.0) + ylim(0.0, 14.0) +
    ggsave("/home/basti/phd/Figs/CAST_Alignment/xray_finger_centers_run_$#.pdf" % $run)

when isMainModule:
  import cligen
  dispatch main