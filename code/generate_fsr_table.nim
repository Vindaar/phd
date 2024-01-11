import std / [sequtils, strutils, os, tables, algorithm]

const path = "/home/basti/CastData/ExternCode/TimepixAnalysis/resources/ChipCalibrations/"
const periods = ["Run2", "Run3"]
const chipInfo = "chipInfo.txt"
const thrMean = "thresholdMeans$#.txt"
const chips = toSeq(0 .. 6)

import ggplotnim
proc readThresholdMeans(path: string, chip: int): DataFrame =
  echo path / thrMean
  result = readCsv(path / (thrMean % $chip), sep = '\t', colNames = @["x", "y", "min", "max", "bit", "opt"])
    .select("opt")
    .rename(f{"THL" <- "opt"})
    .mutate(f{"chip" <- chip})

# parse the names of the chips from the run info file
var df = newDataFrame()    
for period in periods:
  var header = @["DAC"]
  var tab = initTable[int, seq[(string, int)]]()
  var dfPeriod = newDataFrame()
  for chip in chips:
    proc toTuple(s: seq[seq[string]]): seq[(string, int)] =
      for x in s:
        doAssert x.len == 2
        result.add (x[0], x[1].parseInt)
    let chipPath = path / period / "chip" & $chip
    let data = readFile(chipPath / "fsr" & $chip & ".txt")
      .splitLines
      .filterIt(it.len > 0)
      .mapIt(it.split)
      .toTuple()

    tab[chip] = data

    # read chip name and add to header
    proc readChipName(chip: int): string =
      result = readFile(chipPath / chipInfo)
        .splitLines()[0] 
      result.removePrefix("chipName: ")
    header.add readChipName(chip)

    dfPeriod.add readThresholdMeans(chipPath, chip)
  dfPeriod["Run"] = period
  df.add dfPeriod
  
  proc invertTable(tab: Table[int, seq[(string, int)]]): Table[string, seq[(int, int)]] =
    result = initTable[string, seq[(int, int)]]()
    for chip, data in pairs(tab):
      for (dac, value) in data:
        if dac notin result:
          result[dac] = newSeq[(int, int)]()
        result[dac].add (chip, value)

  proc wrap(s: string): string = "|" & s & "|\n"
  proc toOrgTable(s: seq[seq[string]], header: seq[string]): string =
    let tabLine = wrap toSeq(0 ..< header.len).mapIt("------").join("|")
    result = tabLine
    result.add wrap(header.join("|"))
    result.add tabLine
    for x in s:
      doAssert x.len == header.len
      result.add wrap(x.join("|"))
    result.add tabLine

  proc toOrgTable(tab: Table[string, seq[(int, int)]],
                  header: seq[string]): string =
    var commonDacs = newSeq[seq[string]]()
    var diffDacs = newSeq[seq[string]]()
    for (dac, row) in pairs(tab):
      var fullRow = @[dac]
      let toAdd = row.sortedByIt(it[0]).mapIt($it[1])
      if toAdd.deduplicate.len > 1:
        fullRow.add toAdd
        diffDacs.add fullRow 
      else:
        commonDacs.add @[dac, toAdd.deduplicate[0]]
    result.add toOrgTable(diffDacs, header)
    result.add "\n\n"
    result.add toOrgTable(commonDacs, @["DAC", "Value"])
    # now add common dacs table
  echo "Run: ", period
  echo tab.invertTable.toOrgTable(header)

echo df["THL", float].min  
ggplot(df.filter(f{`THL` > 100}), aes("THL", fill = factor("chip"))) +
  facet_wrap("Run") + 
  geom_histogram(binWidth = 1.0, position = "identity", alpha = 0.7, hdKind = hdOutline) +
  ggtitle("Optimized THL distribution of the noise peak for each chip") +
  ylab(r"\# pixels", margin = 2.0) +
  facetHeaderText(font = font(12.0, alignKind = taCenter)) +
  themeLatex(fWidth = 0.9, width = 600, baseTheme = singlePlot) +
  scale_x_continuous(breaks = 8) + 
  margin(left = 3.0, right = 3.5) + 
  ggsave("/home/basti/phd/Figs/detector/calibration/septemboard_all_thl_optimized.pdf",
         useTeX = true, standalone = true,
         width = 1000, height = 600)
