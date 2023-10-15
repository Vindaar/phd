import std / [strutils, strscans, os, strformat] 
import ggplotnim
import unchained

proc charge(voltage: mV): UnitLess =
  ## Returns the number of electrons given a voltage pulse of amplitude `voltage`
  ## at the 8.fF capacitor of the Timepix1
  result = 8.fF * voltage / e

#const path = "/home/basti/septemH_calibration/SCurve/chip_3/voltage_*.txt"
#const path = "/home/basti/septemH_calibration/CalibJul2018/SCurves/chip_1/voltage_*.txt"
const path = "/home/basti/septemH_calibration/SeptemH_FullCalib_InGridDatabase/chip3/SCurve/voltage_*.txt"
#const path = "/home/basti/septemH_calibration/SeptemH_FullCalib_2018_2/chip0/SCurve/voltage_*.txt"
var charges = newSeq[float]()
var thls = newSeq[int]()
for file in walkFiles(path):
  let (success, _, voltage) = scanTuple(file.extractFilename, "$*_$i.txt$.")
  if voltage == 0: continue # skip 0
  charges.add charge(voltage.mV)
  ## we'll do the simplest approach to get the correct THL value:
  ## - strip everything before noise peak (to have single THL value)
  ## - compute
  var df = readCsv(file, sep = '\t', header = "#", colNames = @["THL", "counts"])
  let thlAtMax = df.filter(f{int: `counts` == `counts`.max})["THL", int][0] # must be single element
  const TestPulses = 1000
  df = df.filter(f{`THL` > thlAtMax})
    .mutate(f{int: "DiffHalf" ~ abs(`counts` - TestPulses div 2)})
    .filter(f{int: `DiffHalf` == min(col("DiffHalf"))}) # f{int: `DiffHalf` < 200})
  thls.add df["THL", int][0] # must be single element

import polynumeric
let fit = polyFit(thls.toTensor.asType(float),
                  charges.toTensor,
                  polyOrder = 1)
echo fit
proc linear(x, m, b: float): float = m * x + b

let thlFit = linspace(thls.min, thls.max, 10)
let chargesFit = linspace(charges.min, charges.max, 10)
var dfFit = toDf({ "thls" : thlFit,
                   "charges" : thlFit.map_inline(linear(x, fit[1], fit[0])) })
echo dfFit
let df = toDf(thls, charges)

ggplot(df, aes("thls", "charges")) + 
  geom_point() +
  geom_line(data = dfFit, aes = aes("thls", "charges"), color = parseHex("FF00FF")) +
  xlab("THL DAC") + ylab("Injected charge [e⁻]") + 
  ggtitle(&"Fit parameters: m = {fit[1]:.2f} e⁻/THL, b = {fit[0]:.2f} e⁻") +
  ggsave("/home/basti/phd/Figs/charge_per_thl.pdf")
