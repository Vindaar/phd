import std / [sequtils, strformat]
import ingrid / [tos_helpers, ingrid_types]
import pkg / [ggplotnim, nimhdf5, datamancer]

proc allData(h5f: H5File): DataFrame =
  result = h5f.readDsets(chipDsets = some((chip: 3, dsets: TpaIngridDsetKinds.mapIt(it.toDset()))),
                         commonDsets = @["fadcReadout", "szint1ClockInt", "szint2ClockInt"])

proc plotEvents(df: DataFrame, run: int) =
  for (tup, subDf) in groups(df.group_by("eventNumber")):
    let dfEv = subDf.dfToSeptemEvent()
    let eventNumber = tup[0][1].toInt
    ggplot(dfEv, aes(x, y, color = "charge")) +
      geom_point(size = 1.0) +
      xlim(0, 768) + ylim(0, 768) + scale_x_continuous() + scale_y_continuous() +
      geom_linerange(aes = aes(y = 0, xMin = 128, xMax = 640)) +
      geom_linerange(aes = aes(y = 256, xMin = 0, xMax = 768)) +
      geom_linerange(aes = aes(y = 512, xMin = 0, xMax = 768)) +
      geom_linerange(aes = aes(y = 768, xMin = 128, xMax = 640)) +
      geom_linerange(aes = aes(x = 0, yMin = 256, yMax = 512)) +
      geom_linerange(aes = aes(x = 256, yMin = 256, yMax = 512)) +
      geom_linerange(aes = aes(x = 512, yMin = 256, yMax = 512)) +
      geom_linerange(aes = aes(x = 768, yMin = 256, yMax = 512)) +
      geom_linerange(aes = aes(x = 128, yMin = 0, yMax = 256)) +
      geom_linerange(aes = aes(x = 384, yMin = 0, yMax = 256)) +
      geom_linerange(aes = aes(x = 640, yMin = 0, yMax = 256)) +
      geom_linerange(aes = aes(x = 128, yMin = 512, yMax = 768)) +
      geom_linerange(aes = aes(x = 384, yMin = 512, yMax = 768)) +
      geom_linerange(aes = aes(x = 640, yMin = 512, yMax = 768)) +
      margin(top = 1.5) +
      ggtitle(&"Septem event of event {eventNumber} and run {run}. ") + 
      ggsave(&"Figs/scintillators/peakAt255/septemEvents/septemEvent_run_{run}_event_{eventNumber}.pdf")

proc main(fname: string, plotEvents = true) =
  let h5f = H5open(fname, "r")
  let fileInfo = h5f.getFileInfo()
  let df = h5f.allData()

  let toGather = df.getKeys().filterIt(it notin ["runNumber", "eventNumber"])
    
  let dfF = df.filter(f{int: `szint2ClockInt` > 250 and `szint2ClockInt` < 265})
    .filter(f{`eccentricity` < 10.0})
    .gather(toGather, "key", "value")
    
  echo dfF
  ggplot(dfF, aes("value", fill = "key")) +
    facet_wrap("key", scales = "free") + 
    geom_histogram(position = "identity", binBy = "subset") +
    legendPosition(0.90, 0.0) +
    ggtitle("Cluster properties of all events with veto paddle trigger clock cycles = 255") + 
    ggsave("Figs/scintillators/peakAt255/cluster_properties.pdf", width = 2000, height = 2000)

  if plotEvents:
    for (tup, subDf) in dfF.group_by(@["runNumber"]).groups:
      let run = tup[0][1].toInt
      echo "Run ", run
      let events = subDf["eventNumber", int].toSeq1D
      let dfS = getSeptemDataFrame(h5f, run)
        .filter(f{int: `eventNumber` in events})
      echo dfS
      plotEvents(dfS, run)
    

  discard h5f.close()
    
when isMainModule:
  import cligen
  dispatch main
