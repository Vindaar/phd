import ggplotnim, times

# Laptop:
#const path = "/mnt/1TB/CAST/2017/development/Run_268_170418-05-43/temp_log.txt"
# Desktop:
const path = "~/CastData/data/2017/development/Run_268_170418-05-43/temp_log.txt"

proc p(x: string): DateTime =
  result = x.parse("YYYY-MM-dd'.'HH:mm:ss", local())
let df = readCsv(path, sep = '\t', skipLines = 2, colNames = @["IMB", "Septem", "DateTime"])
  .filter(f{string -> bool: p(`DateTime`) < initDateTime(19, mApr, 2017, 0, 0, 0, 0, local())})
  .gather(@["IMB", "Septem"], "Type", "Temperature")
  .mutate(f{"Timestamp" ~ p(`DateTime`).toTime().toUnix()})

## XXX: fix plotting of string columns as date scales, due to discrete / continuous mismatch and lacking
## `dataScale` field
ggplot(df, aes("Timestamp", "Temperature", color = "Type")) +
  geom_line() +
  # scale_x_continuous() +
  ggtitle("Temperature during run on 2017/04/18 with fan next to detector") + 
  xlab("Time of day") + ylab("Temperature [°C]") +
  #margin(top = 2.0) + 
  scale_x_date(isTimestamp = true,
               formatString = "HH:mm:ss",
               dateSpacing = initDuration(hours = 2),
               dateAlgo = dtaAddDuration,
               timeZone = local()) +
  ggsave("/home/basti/phd/Figs/detector/sparking/temperature_sparking_run_268.pdf",
        width = 600, height = 360, useTeX = true, standalone = true)
df.writeCsv("/home/basti/phd/resources/temperature_sparking_run_268.csv")  
