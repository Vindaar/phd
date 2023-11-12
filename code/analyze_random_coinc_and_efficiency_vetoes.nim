import shell, strutils, os, sequtils, times

# for multiprocessing
import cligen / [procpool, mslice, osUt]

type
  Veto = enum
    Septem, Line

  RealOrFake = enum
    Real, Fake

## Ecc = 1.0 is not in `eccs` because by default we run `ε = 1.0`.
const eccStudy = @[1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
## Line veto kind is not needed anymore. We select the correct kind in `likelihood`
## -> lvRegular for line veto without septem
## -> lvRegularNoHLC for line veto with septem
## UseRealLayout is also set accordingly.
const cmd = """
ECC_LINE_VETO_CUT=$# \
    likelihood -f ~/CastData/data/DataRuns2018_Reco.h5 \
    --h5out $#/lhood_2018_crAll_80eff_septem_line_ecc_cutoff_$#_$#.h5 \
    --region crAll --cdlYear 2018 --readOnly --lnL --signalEfficiency 0.8 \
    --septemLineVetoEfficiencyFile $# \
    --cdlFile ~/CastData/data/CDL_2019/calibration-cdl-2018.h5 $#
"""
const nJobs = 4
proc toName(rf: RealOrFake): string =
  if rf == Real: "" else: "fake_events"
proc toName(vetoes: set[Veto], rf: RealOrFake): string = (toSeq(vetoes).mapIt($it).join("_") & "_" & toName(rf)).strip(chars = {'_'})
proc toCommand(rf: RealOrFake): string =
  if rf == Real: "" else: "--estimateRandomCoinc"
proc toCommand(veto: Veto): string =
  case veto
  of Septem: "--septemveto"
  of Line: "--lineveto"
proc toCommand(vetoes: set[Veto], rf: RealOrFake): string = (toSeq(vetoes).mapIt(toCommand it).join(" ") & " " & toCommand(rf)).strip
proc toEffFile(vetoes: set[Veto], rf: RealOrFake, ecc: float, outpath: string): string =
  result = &"{outpath}/septem_veto_before_after_septem_line_ecc_cutoff_{ecc}_{toName(vetoes, rf)}.txt"

import flatBuffers
type
  Command = object
    cmd: string
    outputFile: string

proc runCommand(r, w: cint) =
  let o = open(w, fmWrite)  
  for cmdBuf in getLenPfx[int](r.open):
    let cmdObjs = fromFlat[Command](fromString(cmdBuf))
    doAssert cmdObjs.len == 1, "Got more than one command: " & $cmdObjs
    let cmdObj = cmdObjs[0]
    let cmdStr = cmdObj.cmd
    let (res, err) = shellVerbose:
      one:
        cd /tmp
        ($cmdStr)
    # write the program output as a logfile
    writeFile(cmdObj.outputFile, res)
    o.urite "Processing done for: " & $cmdObj

proc main(septem = false,
          line = false,
          septemLine = false,
          eccs = false,
          dryRun = false,
          outpath = "/tmp/") =
  var vetoSetups: seq[set[Veto]]
  if septem:     vetoSetups.add {Septem}
  if line:       vetoSetups.add {Line}
  if septemLine: vetoSetups.add {Septem, Line}                            
  # First run individual at `ε = 1.0`
  var cmds = newSeq[Command]()
  var eccVals = @[1.0]
  if eccs:
    eccVals.add eccStudy
  for rf in RealOrFake:
    for ecc in eccVals:    
      for vetoes in vetoSetups:
        if Line in vetoes or ecc == 1.0: ## If only septem veto do not perform eccentricity study!
          let final = cmd % [ $ecc, outpath, $ecc, toName(vetoes, rf), toEffFile(vetoes, rf, ecc, outpath), toCommand(vetoes, rf) ]
          let outputFile = &"{outpath}/logL_output_septem_line_ecc_cutoff_$#_$#.txt" % [$ecc, toName(vetoes, rf)]
          cmds.add Command(cmd: final, outputFile: outputFile)
  echo "Commands to run:"
  for cmd in cmds:
    echo "\tCommand:  ", cmd.cmd
    echo "\t\tOutput: ", cmd.outputFile
  # now run if desired
  if not dryRun:
    # 1. fill the channel completely (so workers simply work until channel empty, then stop
    let t0 = epochTime()
    let cmdBufs = cmds.mapIt(copyFlat(it).toString())
    var pp = initProcPool(runCommand, framesLenPfx, nJobs)
    var readRes = proc(s: MSlice) = echo $s
    pp.evalLenPfx cmdBufs, readRes
    echo "Running all commands took: ", epochTime() - t0, " s"

when isMainModule:
  import cligen
  dispatch main
