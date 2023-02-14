import std / [sequtils, strformat]
import ingrid / [tos_helpers, ingrid_types]
import pkg / [ggplotnim, nimhdf5, datamancer, ginger]

proc allData(h5f: H5File): DataFrame =
  result = h5f.readDsets(chipDsets = some((chip: 3, dsets: TpaIngridDsetKinds.mapIt(it.toDset()))),
                         commonDsets = @["fadcReadout", "szint1ClockInt", "szint2ClockInt"])

proc plotEvents(df: DataFrame, run: int, numEvents: int, plotCount: var int,
                outpath: string,
                fadcRun: ReconstructedFadcRun) =
  let showFadc = fadcRun.eventNumber.len > 0
  for (tup, subDf) in groups(df.group_by("eventNumber")):
    if numEvents > 0 and plotCount > numEvents: break
    let dfEv = subDf.dfToSeptemEvent()
    let eventNumber = tup[0][1].toInt
    let pltSeptem = ggplot(dfEv, aes(x, y, color = "charge"), backend = bkCairo) +
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
      ggtitle(&"Septem event of event {eventNumber} and run {run}. ")

    if not showFadc:
      pltSeptem + ggsave(&"{outpath}/septemEvents/septemEvent_run_{run}_event_{eventNumber}.pdf")
    else:
      # prepare FADC plot, create canvas and place both next to one another
      let eventIdx = fadcRun.eventNumber.find(eventNumber)
      let dfFadc = toDf({ "x"         : toSeq(0 ..< 2560),
                          "data"      : fadcRun.fadcData[eventIdx, _].squeeze })
      let pltFadc = ggplot(dfFadc, aes("x", "data"), backend = bkCairo) +
        geom_line() +
        geom_point(color = "black", alpha = 0.1) +
        ggtitle(&"Fadc signal of event {eventNumber} and run {run}")
      var img = initViewport(wImg = 1200, hImg = 600, backend = bkCairo)
      img.layout(2, rows = 1)
      img.embedAsRelative(0, ggcreate(pltSeptem).view)
      img.embedAsRelative(1, ggcreate(pltFadc).view)      

      var area = img.addViewport()
      let title = &"Septemboard event and FADC signal for event {eventNumber}"
      let text = area.initText(c(0.5, 0.05, ukRelative), title, goText, taCenter, font = some(font(16.0)))
      area.addObj text
      img.children.add area
      img.draw(&"{outpath}/septemEvents/septem_fadc_run_{run}_event_{eventNumber}.pdf")
    
    inc plotCount

proc plotSzinti(h5f: H5file, df: DataFrame, cutFn: FormulaNode,
                title: string, outpath: string,
                fname: string,
                numEventPlots: int,
                plotEvents: bool,
                showFadc: bool = false
               ) =
  let toGather = df.getKeys().filterIt(it notin ["runNumber", "eventNumber"])
    
  let dfF = df.filter(cutFn)
    .filter(f{`eccentricity` < 10.0})
    .gather(toGather, "key", "value")
    
  echo dfF
  ggplot(dfF, aes("value", fill = "key")) +
    facet_wrap("key", scales = "free") + 
    geom_histogram(position = "identity", binBy = "subset") +
    legendPosition(0.90, 0.0) +
    ggtitle(title) + 
    ggsave(&"{outpath}/{fname}", width = 2000, height = 2000)

  if plotEvents:
    var plotCount = 0
    var fadcRun: ReconstructedFadcRun
    for (tup, subDf) in dfF.group_by(@["runNumber"]).groups:
      if numEventPlots > 0 and plotCount > numEventPlots: break
      let run = tup[0][1].toInt
      if showFadc:
        fadcRun = h5f.readRecoFadcRun(run)
      echo "Run ", run
      let events = subDf["eventNumber", int].toSeq1D
      let dfS = getSeptemDataFrame(h5f, run)
        .filter(f{int: `eventNumber` in events})
      echo dfS
      plotEvents(dfS, run, numEventPlots, plotCount, outpath, fadcRun)  

proc main(fname: string,
          peakAt255 = false,
          vetoPaddle = false,
          sipm = false,
          sipmXrayLike = false,
          plotEvents = true) =
  let h5f = H5open(fname, "r")
  #let fileInfo = h5f.getFileInfo()
  let df = h5f.allData()

  # first the veto paddle around the 255 peak (plot all events)
  if peakAt255:
    h5f.plotSzinti(df,
                   f{int: `szint2ClockInt` > 250 and `szint2ClockInt` < 265},
                   "Cluster properties of all events with veto paddle trigger clock cycles = 255",
                   "Figs/scintillators/peakAt255",
                   "cluster_properties_peak_at_255.pdf",
                   -1,
                   plotEvents)
  # now the veto paddle generally
  if vetoPaddle:
    h5f.plotSzinti(df,
                   f{int: `szint2ClockInt` > 0 and `szint2ClockInt` < 200},
                   "Cluster properties of all events with veto paddle > 0 && < 200",
                   "Figs/scintillators/veto_paddle/",
                   "cluster_properties_veto_paddle_less200.pdf",
                   200,
                   plotEvents)
  # finally the SiPM
  if sipm:
    h5f.plotSzinti(df,
                   f{int: `szint1ClockInt` > 0 and `szint1ClockInt` < 200},
                   "Cluster properties of all events with SiPM > 0 && < 200",
                   "Figs/scintillators/sipm/",
                   "cluster_properties_sipm_less200.pdf",                 
                   200,
                   plotEvents)
  if sipmXrayLike:
    h5f.plotSzinti(df,
                   f{float: `szint1ClockInt` > 0 and `szint1ClockInt` < 200 and
                     `energyFromCharge` > 7.0 and `energyFromCharge` < 9.0 and
                     `length` < 7.0},
                   "Cluster properties of all events with SiPM > 0 && < 200, 7 keV < energy < 9 keV, length < 7mm",
                   "Figs/scintillators/sipmXrayLike/",
                   "cluster_properties_sipm_less200_7_energy_9_length_7.pdf",                 
                   -1,
                   plotEvents,
                   showFadc = true)
    

  discard h5f.close()
    
when isMainModule:
  import cligen
  dispatch main
