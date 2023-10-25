import std / [times, strformat]
import ggplotnim

let df1 = readCsv("/home/basti/phd/resources/behavior_over_time/data_full_run_gasgain_90.0_min_filtered_crSilver.csv")
let df2 = readCsv("/home/basti/phd/resources/behavior_over_time/data_gas_gains_binned_90.0_min_filtered_crSilver.csv")
let df = bind_rows([("Unbinned", df1), ("Binned", df2)], "Data")

proc toPeriod(v: float): string =
  result = v.int.fromUnix.format("dd/MM/YYYY")

let name = "energyFromChargeMedian"
ggplot(df, aes("timestamp", name, shape = "runType", color = "Data")) +
  facet_wrap("runPeriods", scales = "free") +
  facetMargin(0.5, ukCentimeter) +
  theme_scale(1.2) +
  facetHeaderText(font = font(14.0)) + 
  scale_x_continuous(labels = toPeriod) +
  geom_point(alpha = some(0.8), size = 2.0) +
  ylim(2.0, 6.5) +
  margin(top = 1.5, left = 2.0, bottom = 1.0, right = 2.0) +
  legendPosition(0.5, 0.175) +
  xlab("Date", rotate = -20, alignTo = "right", margin = 0.0) +
  ylab("Energy [keV]") + 
  ggtitle(&"Median of cluster energy, binned vs. unbinned. 90 min intervals.") +
  ggsave(&"Figs/behavior_over_time/median_energy_binned_vs_unbinned.pdf",
         width = 1200, height = 800,
         useTeX = true, standalone = true)
