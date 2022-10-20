import std / times
import ggplotnim
const path = "/home/basti/phd/resources/"
let df = readCsv(path & "temperature_sparking_run_268.csv")
let dfR = readCsv(path & "mean_hit_rate_sparking_run_268.csv")
  .group_by("chip")
  .mutate(f{"rateNorm" ~ `rate` / max(`rate`) * 80.0})
  .rename(f{"Timestamp" <- "rateTime"})

let sa = secAxis(name = "Hit rate [a.u.]",
                 trans = f{1.0 / 80.0})
                 #invTransFn = f{`rateNorm` * 80.0})

ggplot(df, aes("Timestamp", "Temperature", color = "Type")) +
  geom_line() +
  geom_point(data = dfR, aes = aes("Timestamp", "rateNorm", color = factor("chip"))) + 
  # ggtitle("Temperature during run on 2017/04/18 in which fan was placed next to detector") + 
  xlab("Time of day") + ylab("Temperature [°C]") +
  margin(top = 2.0) +
  scale_y_continuous(secAxis = sa) + 
  scale_x_date(isTimestamp = true,
               formatString = "HH:mm:ss",
               dateSpacing = initDuration(hours = 2),
               dateAlgo = dtaAddDuration,
               timeZone = local()) + 
  legendPosition(0.835, 0.1) +
  yMargin(0.05) + 
  ggsave("/home/basti/phd/Figs/detector/sparking/temperature_and_sparking_run_268.pdf")

