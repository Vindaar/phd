import strutils

proc parseFile(fname: string): float =
  var lines = fname.readFile.strip.splitLines()
  var line = 0
  var numRuns = 0
  var outputs = 0
  # if file has more than 68 lines, remove everything before, as that means
  # those were from a previous run
  if lines.len > 68:
    lines = lines[^68 .. ^1]
    doAssert lines.len == 68
  while line < lines.len:
    if lines[line].len == 0: break
    # parse input
    # `Septem events before: 1069 (L,F) = (false, false)`
    let input = lines[line].split(':')[1].strip.split()[0].parseInt
    # parse output
    # `Septem events after fake cut: 137`
    inc line
    let output = lines[line].split(':')[1].strip.parseInt
    result += output.float / input.float
    outputs += output
    inc numRuns
    inc line
  echo "\tMean output = ", outputs.float / numRuns.float
  result = result / numRuns.float

# now all files in our eccentricity cut run directory
const path = "/home/basti/phd/resources/estimateRandomCoinc/"
import std / [os, parseutils]
import ggplotnim
import strscans
proc parseEccentricityCutoff(f: string): float =
  let (success, _, ecc) = scanTuple(f, "$+ecc_cutoff_$f_")
  result = ecc

proc determineType(f: string): string =
  ## I'm sorry for this. :)
  if "Septem_Line" in f:
    result.add "SeptemLine"
  elif "Septem" in f:
    result.add "Septem"
  elif "Line" in f:
    result.add "Line"
    
  if "_fake_events.txt" in f:
    result.add "Fake"
  else:
    result.add "Real"

proc hasSeptem(f: string): bool = "Septem" in f
proc hasLine(f: string): bool = "Line" in f
proc isFake(f: string): string =
  if "fake_events" in f: "Fake" else: "Real"

var df = newDataFrame()
# walk all files and determine the type
for f in walkFiles(path / "septem_veto_before_after*.txt"):
  echo "File: ", f
  let frac = parseFile(f)
  let eccCut = parseEccentricityCutoff(f)
  echo "\tFraction of events left = ", frac
  let typ = determineType(f)
  echo "\tFraction of events left = ", frac
  df.add toDf({"Type" : typ, "Septem" : hasSeptem(f), "Line" : hasLine(f), "Fake" : isFake(f), "ε_cut" : eccCut, "FractionPass" : frac})

# Now write the table we want to use in the thesis for the efficiencies & random coinc
# rate
import std / strformat  
proc convert(x: float): string =
  let s = &"{x * 100.0:.2f}"
  result = r"$\num{" & s & "}$"
  
echo df.filter(f{`ε_cut` == 1.0})
  .mutate(f{float -> string: "FractionPass" ~ convert(idx("FractionPass"))})
  .drop("Type", "ε_cut")
  .spread("Fake", "FractionPass").toOrgTable()
# And finally create the plots and output CSV file
if true:
  df.writeCsv("/home/basti/phd/resources/septem_line_random_coincidences_ecc_cut.csv", precision = 8)  

block PlotFromCsv:
  block OldPlot:
    let oldFile = "/home/basti/org/resources/septem_line_random_coincidences_ecc_cut.csv"
    if fileExists(oldFile):
      let df = readCsv(oldFile)
        .filter(f{`Type` notin ["LinelvRegularNoHLCReal", "LinelvRegularNoHLCFake"]})
        .mutate(f{string: "Type" ~ `Type`.replace("lvRegular", "").replace("NoHLC", "")})
      ggplot(df, aes("ε_cut", "FractionPass", color = "Type")) +
        geom_point() +
        ggtitle("Fraction of events passing line veto based on ε cutoff") +
        #margin(right = 9) +
        themeLatex(fWidth = 0.9, width = 600, baseTheme = singlePlot) + 
        ggsave("Figs/background/estimateSeptemVetoRandomCoinc/fraction_passing_line_veto_ecc_cut_only_relevant.pdf",
               width = 600, height = 420, useTeX = true, standalone = true)
        #ggsave("/tmp/fraction_passing_line_veto_ecc_cut.pdf", width = 800, height = 480)
  block NewPlot:
    ggplot(df, aes("ε_cut", "FractionPass", color = "Type")) +
      geom_point() +
      ggtitle("Fraction of events passing line veto based on ε cutoff") +
      #margin(right = 9) +
      margin(right = 5.5) + 
      xlab("Eccentricity cut 'ε_cut'") + ylab("Fraction passing [%]") + 
      themeLatex(fWidth = 0.9, width = 600, baseTheme = singlePlot) +       
      ggsave("Figs/background/estimateSeptemVetoRandomCoinc/fraction_passing_line_veto_ecc_cut_only_relevant.pdf",
             width = 600, height = 420, useTeX = true, standalone = true)
    
  
## XXX: we probably don't need the following plot for the real data, as the eccentricity
## cut does not cause anything to get worse at lower values. Real improvement better than
## fake coincidence rate.
#df = df.spread("Type", "FractionPass").mutate(f{float: "Ratio" ~ `Real` / `Fake`})
#ggplot(df, aes("ε_cut", "Ratio")) +
#  geom_point() +
#  ggtitle("Ratio of fraction of events passing line veto real/fake based on ε cutoff") + 
#  #ggsave("Figs/background/estimateSeptemVetoRandomCoinc/ratio_real_fake_fraction_passing_line_veto_ecc_cut.pdf")
#  ggsave("/tmp/ratio_real_fake_fraction_passing_line_veto_ecc_cut.pdf")
