import ggplotnim, ggplotnim/ggplot_sdl2
import unchained
const mpe = "~/phd/resources/MPE/mpe_xray_telescope_cast_effective_area.csv"
const llnl = "~/phd/resources/LLNL/EffectiveArea.txt"
let dfMpe = readCsv(mpe)
let dfLLNL = readCsv(llnl, sep = ' ')
  .rename(f{"Energy[keV]" <- "E(keV)"},
          f{"EffectiveArea[cm²]" <- "Area(cm^2)"})
let df = bind_rows([("MPE", dfMpe), ("LLNL", dfLLNL)], "Telescope")
const areaBore = (4.3.cm / 2.0)^2 * π ## Area of the CAST bore in cm²
ggplot(df, aes("Energy[keV]", "EffectiveArea[cm²]", color = "Telescope")) +
  geom_line() +
  xlab(r"Energy [\si{keV}]") + ylab(r"EffectiveArea [\si{cm^2}]") +
  scale_y_continuous(secAxis = secAxis(f{1.0 / areaBore.float}, name = r"Transmission [\si{\%}]")) +
  legendPosition(0.83, -0.2) +
  themeLatex(fWidth = 0.9, width = 600, baseTheme = singlePlot) + 
  ggshow("~/phd/Figs/telescopes/effective_area_mpe_llnl.pdf", useTeX = true, standalone = true)
