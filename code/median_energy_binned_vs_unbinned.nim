import std / [times, strformat]
import ggplotnim

let df1 = readCsv("/home/basti/phd/resources/behavior_over_time/data_full_run_gasgain_90.0_min_filtered_crSilver.csv")
let df2 = readCsv("/home/basti/phd/resources/behavior_over_time/data_gas_gains_binned_90.0_min_filtered_crSilver.csv")
let df = bind_rows([("Unbinned", df1), ("Binned", df2)], "Data")

proc th(): Theme =
  result = singlePlot()
  result.tickLabelFont = some(font(7.0))

let name = "energyFromChargeMedian"
ggplot(df, aes("timestamp", name, shape = "runType", color = "Data")) +
  facet_wrap("runPeriods", scales = "free") +
  facetMargin(0.75, ukCentimeter) +
  scale_x_date(name = "Date", isTimestamp = true,
               dateSpacing = initDuration(weeks = 2),
               formatString = "dd/MM/YYYY", dateAlgo = dtaAddDuration) +
  geom_point(alpha = some(0.8), size = 2.0) +
  ylim(2.0, 6.5) +
  margin(top = 1.5, left = 4.0, bottom = 1.0, right = 2.0) +
  legendPosition(0.5, 0.175) +
  xlab("Date", margin = 0.0) +
  ylab("Energy [keV]", margin = 3.0) +
  themeLatex(fWidth = 1.0, width = 1200, height = 800, baseTheme = th) + 
  ggtitle(&"Median of cluster energy, binned vs. unbinned. 90 min intervals.") +
  ggsave(&"Figs/behavior_over_time/median_energy_binned_vs_unbinned.pdf",
         width = 1200, height = 800,
         useTeX = true, standalone = true)
