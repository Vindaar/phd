import horizonsapi, datamancer, times

let startDate = initDateTime(01, mJan, 2017, 00, 00, 00, 00, local())
let stopDate = initDateTime(31, mDec, 2019, 23, 59, 59, 00, local())
let nMins = (stopDate - startDate).inMinutes()
const blockSize = 85_000 # max line number somewhere above 90k. Do less to have some buffer
let numBlocks = ceil(nMins.float / blockSize.float).int # we end up at a later date than `stopDate`, but that's fine
echo numBlocks
let blockDur = initDuration(minutes = blockSize)

let comOpt = { #coFormat : "json", # data returned as "fake" JSON 
               coMakeEphem : "YES", 
               coCommand : "10",  # our target is the Sun, index 10
               coEphemType : "OBSERVER" }.toTable # observational parameters
var ephOpt = { eoCenter : "coord@399", # observational point is a coordinate on Earth (Earth idx 399)
               eoStartTime : startDate.format("yyyy-MM-dd"),
               eoStopTime : (startDate + blockDur).format("yyyy-MM-dd"),
               eoStepSize : "1 MIN", # in 1 min steps
               eoCoordType : "GEODETIC", 
               eoSiteCoord : "+6.06670,+46.23330,0", # Geneva
               eoCSVFormat : "YES" }.toTable # data as CSV within the JSON (yes, really)
var q: Quantities
q.incl 20 ## Observer range! In this case range between our coordinates on Earth and target

var reqs = newSeq[HorizonsRequest]()
for i in 0 ..< numBlocks:
  # modify the start and end dates
  ephOpt[eoStartTime] = (startDate + i * blockDur).format("yyyy-MM-dd")
  ephOpt[eoStopTime] = (startDate + (i+1) * blockDur).format("yyyy-MM-dd")
  echo "From : ", ephOpt[eoStartTime], " to ", ephOpt[eoStopTime]
  reqs.add initHorizonsRequest(comOpt, ephOpt, q)

let res = getResponsesSync(reqs)

proc convertToDf(res: seq[HorizonsResponse]): DataFrame =
  result = newDataFrame()
  for r in res:
    result.add parseCsvString(r.csvData)

let df = res.convertToDf().unique("Date__(UT)__HR:MN")
  .select(["Date__(UT)__HR:MN", "delta", "deldot"])
echo df

df.writeCsv("/home/basti/phd/resources/sun_earth_distance_cast_datataking.csv",
            precision = 16)
