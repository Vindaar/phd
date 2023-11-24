import ggplotnim, sequtils, times, strutils, strformat
# 2017-Jan-01 00:00
const Format = "yyyy-MMM-dd HH:mm"
const OrgFormat = "'<'yyyy-MM-dd ddd H:mm'>'"
const p2017 = "~/CastData/ExternCode/TimepixAnalysis/resources/DataRuns2017_Reco_tracking_times.csv"
const p2018 = "~/CastData/ExternCode/TimepixAnalysis/resources/DataRuns2018_Reco_tracking_times.csv"
var df = readCsv("~/phd/resources/sun_earth_distance_cast_datataking.csv")
  .mutate(f{string -> int: "Timestamp" ~ parseTime(idx("Date__(UT)__HR:MN").strip, Format, local()).toUnix.int})
proc readRuns(f: string): DataFrame =
  result = readCsv(f)
    .mutate(f{string -> int: "TimestampStart" ~ parseTime(idx("Tracking start"), OrgFormat, local()).toUnix.int})
    .mutate(f{string -> int: "TimestampStop" ~ parseTime(idx("Tracking stop"), OrgFormat, local()).toUnix.int})
var dfR = readRuns(p2017)  
dfR.add readRuns(p2018)

var dfHT = newDataFrame()
for tracking in dfR:
  let start = tracking["TimestampStart"].toInt
  let stop = tracking["TimestampStop"].toInt
  dfHT.add df.filter(f{int: `Timestamp` >= start and `Timestamp` <= stop})

dfHT["Type"] = "Trackings"
df["Type"] = "HorizonsAPI"
df.add dfHT

let deltas = dfHT["delta", float]
let meanD = deltas.mean
let varD = deltas.variance
let stdD = deltas.std
echo "Mean distance during trackings = ", meanD
echo "Variance of distance during trackings = ", varD
echo "Std of distance during trackings = ", stdD
# and write back the DF of the tracking positions
dfHT.writeCsv("~/phd/resources/sun_earth_distance_cast_solar_trackings.csv")

ggplot(df, aes("Timestamp", "delta", color = "Type")) +
  geom_line(data = df.filter(f{`Type` == "HorizonsAPI"})) +
  geom_point(data = df.filter(f{`Type` == "Trackings"}), size = 1.0) +
  scale_x_date(isTimestamp = true,
               formatString = "yyyy-MM",
               dateSpacing = initDuration(days = 60)) +
  xlab("Date", rotate = -45.0, alignTo = "right", margin = 1.5) +
  annotate(text = &"Mean distance during trackings = {meanD:.4f}", x = 1.52e9, y = 1.0175) + 
  annotate(text = &"Variance distance during trackings = {varD:.4g}", x = 1.52e9, y = 1.015) +   
  annotate(text = &"Std distance during trackings = {stdD:.4f}", x = 1.52e9, y = 1.0125) + 
  margin(bottom = 2.0) + 
  ggtitle("Distance in AU Sun ⇔ Earth") +
  theme_font_scale(1.0, family = "serif") + 
  ggsave("~/phd/Figs/systematics/sun_earth_distance_cast_solar_tracking.pdf", width = 600, height = 360)
