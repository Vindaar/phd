import shell, strutils

proc main(path: string, run: int) =
  # parse data
  let outfile = "/t/xray_finger_$#.h5" % $run
  let recoOut = "/t/reco_xray_finger_$#.h5" % $run
  
  shell:
    raw_data_manipulation -p ($path) "--runType xray --out " ($outfile)
  shell:
    reconstruction ($outfile) "--out " ($recoOut)
  
when isMainModule:
  import cligen
  dispatch main
