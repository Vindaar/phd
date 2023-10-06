import std / [options, sequtils, times]
import ggplotnim, nimhdf5, unchained
defUnit(Second⁻¹)
import ingrid / tos_helpers
# Laptop
# const path = "/mnt/1TB/CAST/2017/development/reco_268_sparking.h5"
# Desktop
const path = "~/CastData/data/2017/development/reco_268_sparking.h5"
let h5f = H5open(path, "r")

var df = newDataFrame()
var dfR = newDataFrame()
for chip in 0 ..< 5:
  let dsets = @["hits"]
  let dfC = h5f.readRunDsets(
    268,
    chipDsets = some((chip: chip, dsets: dsets)),
    commonDsets = @["timestamp"]
  )
    .mutate(f{"chip" <- chip})
    .arrange("timestamp")
  df.add dfC

  # and directly compute the hit frequency
  let hits = dfC["hits", int]
  let time = dfC["timestamp", int]
  let ts = time.map_inline((x - time[0]).s)
  const Interval = 30.min
  var i = 0
  var rate = newSeq[Second⁻¹]()
  var rateTime = newSeq[float]()
  while i < time.len:
    var h = 0
    var Δt = 0.s
    let t0 = time[i]
    echo "Starting at t0 = ", t0
    while Δt < Interval and i < time.len:
      h += hits[i]
      if i > 0:
        Δt += ts[i] - ts[i-1]
      inc i
    rate.add (h.float / Δt)
    echo "To ", time[i-1]
    rateTime.add((time[i-1] + t0) / 2.0)
    h = 0
  dfR.add toDf({"rate" : rate.mapIt(it.float), rateTime, "chip" : chip})
echo df
echo dfR

dfR = dfR.filter(f{int -> bool: fromUnix(`rateTime`).inZone(local()) < initDateTime(19, mApr, 2017, 0, 0, 0, 0, local())})
ggplot(dfR, aes("rateTime", "rate", color = factor("chip"))) +
  geom_point() +
  scale_y_log10() + 
  scale_x_date(isTimestamp = true,
               formatString = "HH:mm:ss",
               dateSpacing = initDuration(hours = 2),
               dateAlgo = dtaAddDuration,
               timeZone = local()) +
  xlab("Time of day") + ylab(r"Rate [$\si{pixel.s^{-1}}$]") + 
  ggsave("/home/basti/phd/Figs/detector/sparking/mean_hit_rate_sparking_run_268.pdf",
        width = 600, height = 360, useTex = true, standalone = true)

dfR.writeCsv("/home/basti/phd/resources/mean_hit_rate_sparking_run_268.csv", precision = 10)
