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
#dfHT.writeCsv("~/phd/resources/sun_earth_distance_cast_solar_trackings.csv")

let texts = @[r"$μ_{\text{distance}} = " & &"{meanD:.4f}$",
              #r"$\text{Variance} = " & &"{varD:.4g}$",
              r"$σ_{\text{distance}} = " & &"{stdD:.4f}$"]
let annot = texts.join(r"\\")
echo "Annot: ", annot

proc thm(): Theme =
  result = sideBySide()
  result.annotationFont = some(font(7.0)) # we don't want monospace font!

ggplot(df, aes("Timestamp", "delta", color = "Type")) +
  geom_line(data = df.filter(f{`Type` == "HorizonsAPI"})) +
  geom_point(data = df.filter(f{`Type` == "Trackings"}), size = 1.0) +
  scale_x_date(isTimestamp = true,
               formatString = "yyyy-MM",
               dateSpacing = initDuration(days = 90)) +
  xlab("Date", rotate = -45.0, alignTo = "right", margin = 3.0) +
  annotate(text = annot, x = 1.5975e9, y = 1.0075) + 
  ggtitle("Distance in AU Sun ⇔ Earth") +
  legendPosition(0.7, 0.2) + 
  themeLatex(fWidth = 0.5, width = 600, baseTheme = thm, useTeX = true) +
  margin(left = 3.5, bottom = 3.75) + 
  ggsave("~/phd/Figs/systematics/sun_earth_distance_cast_solar_tracking.pdf", width = 600, height = 360, dataAsBitmap = true)
