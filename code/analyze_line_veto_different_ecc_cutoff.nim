import shell, strutils, os

#let vals = @[1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
#let vals = @[1.0, 1.1]
let vals = @[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
#let vetoes = @["--lineveto", "--lineveto --estimateRandomCoinc"]
let vetoes = @["--septemveto --lineveto", "--septemveto --lineveto --estimateRandomCoinc"]

## XXX: ADD CODE DIFFERENTIATING SEPTEM + LINE & LINE ONLY IN NAMES AS WELL!
#const lineVeto = "lvRegular"
const lineVeto = "lvRegularNoHLC"
let cmd = """
LINE_VETO_KIND=$# \
    ECC_LINE_VETO_CUT=$# \
    USE_REAL_LAYOUT=true \
    likelihood -f ~/CastData/data/DataRuns2018_Reco.h5 \
    --h5out /t/lhood_2018_crAll_80eff_septem_line_ecc_cutoff_$#_$#_real_layout$#.h5 \
    --region crAll --cdlYear 2018 \
    --cdlFile ~/CastData/data/CDL_2019/calibration-cdl-2018.h5 $#
"""
proc toName(veto: string): string = (if "estimateRandomCoinc" in veto: "_fake_events" else: "")
for val in vals:
  for veto in vetoes:
    let final = cmd % [ lineVeto, $val, $val, lineVeto, toName(veto),
                        $veto ]
    let (res, err) = shellVerbose:
      one:
        cd /tmp
        ($final)
    writeFile("/tmp/logL_output_septem_line_ecc_cutoff_$#_$#_real_layout$#.txt" % [$val, lineVeto, toName(veto)], res)
    let outpath = "/home/basti/org/resources/septem_veto_random_coincidences/autoGen/"
    let outfile = "septem_veto_before_after_septem_line_ecc_cutoff_$#_$#_real_layout$#.txt" % [$val, lineVeto, toName(veto)]
    copyFile("/tmp/septem_veto_before_after.txt", outpath / outfile)
    removeFile("/tmp/septem_veto_before_after.txt") # remove file to not append more and more to file
