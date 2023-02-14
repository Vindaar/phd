import nimhdf5, ggplotnim
import std / [strutils, os, sequtils, sets, strformat]
import ingrid / [tos_helpers, ingrid_types]
import ingrid / calibration / [calib_fitting, calib_plotting]
import ingrid / calibration 

proc stripPrefix(s, p: string): string =
  result = s
  result.removePrefix(p)

proc plotFallTimeRiseTime(df: DataFrame, suffix: string) =
  ## Given a full run of FADC data, create the
  ## Note: it may be sensible to compute a truncated mean instead
  proc plotDset(dset: string) =

    let dfCalib = df.filter(f{`Type` == "calib"})
    echo "============================== ", dset, " =============================="
    echo "Percentiles:"
    echo "\t 1-th: ", dfCalib[dset, float].percentile(1)
    echo "\t 5-th: ", dfCalib[dset, float].percentile(5)
    echo "\t95-th: ", dfCalib[dset, float].percentile(95)
    echo "\t99-th: ", dfCalib[dset, float].percentile(99)    
    
    ggplot(df, aes(dset, fill = "Type")) + 
      geom_histogram(position = "identity", bins = 100, hdKind = hdOutline, alpha = 0.7) +
      ggtitle(&"Comparison of FADC signal {dset} in ⁵⁵Fe vs background data in $#" % suffix) +
      ggsave(&"Figs/statusAndProgress/FADC/fadc_{dset}_signal_vs_background_$#.pdf" % suffix)
    ggplot(df, aes(dset, fill = "Type")) + 
      geom_density(normalize = true, alpha = 0.7, adjust = 2.0) +
      ggtitle(&"Comparison of FADC signal {dset} in ⁵⁵Fe vs background data in $#" % suffix) +
      ggsave(&"Figs/statusAndProgress/FADC/fadc_{dset}_kde_signal_vs_background_$#.pdf" % suffix)
  plotDset("fallTime")
  plotDset("riseTime")

  when false:
    let dfG = df.group_by("runNumber").summarize(f{float: "riseTime" << truncMean(col("riseTime").toSeq1D, 0.05)},
                                                 f{float: "fallTime" << truncMean(col("fallTime").toSeq1D, 0.05)})
    ggplot(dfG, aes(runNumber, riseTime, color = fallTime)) + 
      geom_point() +
      ggtitle("Comparison of FADC signal rise times in ⁵⁵Fe data for all runs in $#" % suffix) +
      ggsave("Figs/FADC/fadc_mean_riseTime_$#.pdf" % suffix)
    ggplot(dfG, aes(runNumber, fallTime, color = riseTime)) + 
      geom_point() +
      ggtitle("Comparison of FADC signal fall times in ⁵⁵Fe data for all runsin $#" % suffix) +
      ggsave("Figs/FADC/fadc_mean_fallTime_$#.pdf" % suffix)

proc read(fname, typ: string): DataFrame =
  var h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  
  var peakPos = newSeq[float]()
  result = newDataFrame()
  for run in fileInfo.runs:
    if recoBase() & $run / "fadc" notin h5f: continue # skip runs that were without FADC
    var df = h5f.readRunDsets(
      run,
      #chipDsets = some((chip: 3, dsets: @["eventNumber"])), # XXX: causes problems?? Removes some FADC data
                                                             # but not due to events!
      fadcDsets = @["eventNumber",
                    "baseline",
                    "riseStart",
                    "riseTime",                  
                    "fallStop",
                    "fallTime",
                    "minvals",
                    "argMinval"]                 
    )
    # in calibration case filter to 
    if typ == "calib":
      let xrayRefCuts = getXrayCleaningCuts()
      let cut = xrayRefCuts["Mn-Cr-12kV"]
      let grp = h5f[(recoBase() & $run / "chip_3").grp_str]
      let passIdx = cutOnProperties(
        h5f,
        grp,
        crSilver, # try cutting to silver
        (toDset(igRmsTransverse), cut.minRms, cut.maxRms),
        (toDset(igRmsTransverse), 0.0, cut.maxEccentricity),        
        (toDset(igLength), 0.0, cut.maxLength),
        (toDset(igHits), cut.minPix, Inf),
        #(toDset(igEnergyFromCharge), 2.5, 3.5)
      )
      let dfChip = h5f.readRunDsets(run, chipDsets = some((chip: 3, dsets: @["eventNumber"])))
      let allEvNums = dfChip["eventNumber", int]
      let evNums = passIdx.mapIt(allEvNums[it]).toSet
      df = df.filter(f{int: `eventNumber` in evNums})
    df["runNumber"] = run
    result.add df
  result["Type"] = typ
  echo result

proc main(back, calib: string, year: int) =
  var df = newDataFrame()
  df.add read(back, "back")
  df.add read(calib, "calib")
  
  let is2017 = year == 2017
  let is2018 = year == 2018
  if not is2017 and not is2018:
    raise newException(IOError, "The input file is neither clearly a 2017 nor 2018 calibration file!")
  
  let yearToRun = if is2017: 2 else: 3
  let suffix = "run$#" % $yearToRun
  plotFallTimeRiseTime(df, suffix) 
      
when isMainModule:
  import cligen
  dispatch main
