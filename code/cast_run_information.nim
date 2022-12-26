# 1. open file
# 2. get file info
# 3. for each run get extended run info
# ?
import std / [times, strformat, strutils]
import nimhdf5, unchained
import ingrid / tos_helpers

type
  CastInformation = object
    totalDuration: Second
    activeDuration: Second
    activeFraction: float # ratio of active / total    
    numTrackings: int
    trackingTime: Second
    activeTrackingTime: Second
    totalEvents: int # total number of recorded events
    onlyCenter: int  # events with activity only on center chip (> 3 hits)
    onlyOuter: int   # events with activity only on outer, but not center chip
    centerAndOuter: int # events with activity on center & any outer chip
    center: int      # events with activity on center (irrespective any other)
    anyActive: int # events with any active chip
    fractionWithCenter: float # fraction of events that have center chip activity
    fractionWithAny: float # fraction of events that have any activity
    # ... add mean of event durations?
    fadcReadouts: int
    fractionFadc: float # fraction of events having FADC readout
    scinti1NonTrivial: int # number of non trivial scinti triggers 0 < x < 4095
    scinti2NonTrivial: int # number of non trivial scinti triggers 0 < x < 4095
    scinti1Triggers: int # number of any scinti triggers != 0
    scinti2Triggers: int # number of any scinti triggers != 0
    fractionScinti1: float # fraction of events with any scinti 1 activity    
    fractionScinti2: float # fraction of events with any scinti 2 activity

proc fieldToStr(s: string): string =
  case s
  of "totalDuration":      result = "total duration"
  of "activeDuration":     result = "active duration"
  of "activeFraction":     result = "active fraction"
  of "numTrackings":       result = "# trackings"
  of "trackingTime":       result = "tracking time"
  of "activeTrackingTime": result = "active tracking time"
  of "totalEvents":        result = "total # events"
  of "center":             result = "center chip"
  of "onlyCenter":         result = "only center chip"
  of "onlyOuter":          result = "only any outer chip"
  of "centerAndOuter":     result = "center + outer"
  of "anyActive":          result = "any chip"
  of "fractionWithCenter": result = "fraction with center"
  of "fractionWithAny":    result = "fraction with any"
  of "fadcReadouts":       result = "with fadc readouts"
  of "fractionFadc":       result = "fraction with FADC"
  of "scinti1NonTrivial":  result = "with SiPM trigger <4095"
  of "scinti2NonTrivial":  result = "with veto scinti trigger <4095"
  of "scinti1Triggers":    result = "with any SiPM trigger"
  of "scinti2Triggers":    result = "with any veto scinti trigger"
  of "fractionScinti1":    result = "fraction with any SiPM"
  of "fractionScinti2":    result = "fraction with any veto scinti"  

proc `$`(castInfo: CastInformation): string =
  result.add &"Total duration: {pretty(castInfo.totalDuration.to(Hour), 4, true)}\n"
  result.add &"Active duration: {pretty(castInfo.activeDuration.to(Hour), 4, true)}\n"
  result.add &"Active fraction: {castInfo.activeFraction}\n"
  result.add &"Number of trackings: {castInfo.numTrackings}\n"
  result.add &"Tracking time: {pretty(castInfo.trackingTime.to(Hour), 4, true)}\n"
  result.add &"Active tracking time: {pretty(castInfo.activeTrackingTime.to(Hour), 4, true)}\n"
  result.add &"Number of total events:   {castInfo.totalEvents}\n"
  result.add &"Number of events without center: {castInfo.onlyOuter}\n"
  result.add &"\t| {(castInfo.onlyOuter.float / castInfo.totalEvents.float) * 100.0} %\n"
  result.add &"Number of events only center: {castInfo.onlyCenter}\n"
  result.add &"\t| {(castInfo.onlyCenter.float / castInfo.totalEvents.float) * 100.0} %\n"
  result.add &"Number of events with center activity and outer: {castInfo.centerAndOuter}\n"
  result.add &"\t| {(castInfo.centerAndOuter.float / castInfo.totalEvents.float) * 100.0} %\n"
  result.add &"Number of events any hit events: {castInfo.anyActive}\n"
  result.add &"\t| {(castInfo.anyActive.float / castInfo.totalEvents.float) * 100.0} %\n"

proc countEvents(df: DataFrame): int =
  for (tup, subdf) in groups(df.group_by("runNumber")):
    inc result, subDf["eventNumber", int].max

proc contains[T](t: Tensor[T], x: T): bool =
  for i in 0 ..< t.size:
    if x == t[i]:
      return true

proc countChipActivity(castInfo: var CastInformation, df: DataFrame) =
  for (tup, subDf) in groups(df.group_by(["eventNumber", "runNumber"])):
    let chips = subDf["chip"].unique.toTensor(int)
    if 3 in chips:
      inc castInfo.center
    # start new if 
    if 3 notin chips: 
      inc castInfo.onlyOuter
    elif [3].toTensor == chips:
      inc castInfo.onlyCenter
    elif 3 in chips and chips.len > 1:
      inc castInfo.centerAndOuter
    inc castInfo.anyActive

proc processFile(fname: string): CastInformation = # extend to both calib & both background
  let h5f = H5open(fname, "r")
  let fileInfo = getFileInfo(h5f)
  var castInfo: CastInformation
  for run in fileInfo.runs:
    let runInfo = getExtendedRunInfo(h5f, run, fileInfo.runType)
    castInfo.totalDuration  += runInfo.timeInfo.t_length.inSeconds().Second
    castInfo.activeDuration += runInfo.activeTime.inSeconds.Second
    castInfo.numTrackings   += runInfo.trackings.len
    for track in runInfo.trackings:
      castInfo.trackingTime += track.t_length.inSeconds.Second

    # read the data of all chips & FADC
    const names = ["eventNumber", "fadcReadout", "szint1ClockInt", "szint2ClockInt"]
    let dfNoChips = h5f.readRunDsets(run, commonDsets = names)
    let dfChips = h5f.readRunDsetsAllChips(run, fileInfo.chips,
                                           dsets = @[]) # don't need additional dsets
    castInfo.totalEvents       += dfNoChips.countEvents()
    castInfo.countChipActivity(dfChips)
    castInfo.fadcReadouts      += dfNoChips.filter(f{`fadcReadout` == 1}).len
    castInfo.scinti1Triggers   += dfNoChips.filter(f{`szint1ClockInt` != 0}).len
    castInfo.scinti2Triggers   += dfNoChips.filter(f{`szint2ClockInt` != 0}).len
    castInfo.scinti1NonTrivial += dfNoChips.filter(f{`szint1ClockInt` != 0 and `szint1ClockInt` < 4095}).len
    castInfo.scinti2NonTrivial += dfNoChips.filter(f{`szint2ClockInt` != 0 and `szint2ClockInt` < 4095}).len
      

# compute at the end as we need total information about fraction of total / active
  template fraction(arg, by: untyped): untyped = (castInfo.arg / castInfo.by) * 100.0
  castInfo.activeFraction = fraction(activeDuration, totalDuration)
  castInfo.activeTrackingTime = (castInfo.trackingTime * castInfo.activeFraction / 100.0)
  # fractions
  castInfo.fractionWithCenter = fraction(center         , totalEvents)
  castInfo.fractionWithAny    = fraction(anyActive      , totalEvents)
  castInfo.fractionFadc       = fraction(fadcReadouts   , totalEvents)
  castInfo.fractionScinti1    = fraction(scinti1Triggers, totalEvents)
  castInfo.fractionScinti2    = fraction(scinti2Triggers, totalEvents)
  echo castInfo
  result = castInfo

proc toTable(castInfos: Table[(string,string), CastInformation]): string =
  ## Turns the input into an Org table
  # | Field | Back Run-2 | Back Run-3 | Calib Run-2 | Calib Run-3 |
  # |-
  # ...
  # turn the input into a DF, then `toOrgTable` it
  proc toColName(tup: (string, string)): string =
    result = tup[1] & " "
    if "2017" in tup[0]:
      result.add "Run-2"
    else:
      result.add "Run-3"
      
  var df = newDataFrame()
  for k, v in pairs(castInfos):
    var fields = newSeq[string]()
    var vals = newSeq[string]()
    for field, val in fieldPairs(v):
      fields.add field.fieldToStr()
      when typeof(val) is Second:
        vals.add pretty(val.to(Hour), precision = 2, short = true,
                        format = ffDecimal)
      elif typeof(val) is float:
        vals.add $(val.formatFloat(precision = 4)) & " %"
      else:
        vals.add "\\num{" & $val & "}"
    let colName = k.toColName()
    let dfLoc = toDf({"Field" : fields, colName : vals})
    if df.len == 0:
      df = dfLoc
    else:
      df[colName] = dfLoc[colName]

  df = df.select(["Field", "calib Run-2", "calib Run-3", "back Run-2", "back Run-3"])
  echo df.toOrgTable(emphStrNumber = false)

proc main(background: seq[string], calibration: seq[string]) =

  var tab = initTable[(string, string), CastInformation]()
  for b in background:
    echo "--------------- Processing: ", b, " ---------------"
    tab[(b, "back")] = processFile(b)
    
  for c in calibration:
    echo "--------------- Processing: ", c, " ---------------"    
    tab[(c, "calib")] = processFile(c)
  echo tab
  echo tab.toTable()

when isMainModule:
  import cligen
  dispatch main
