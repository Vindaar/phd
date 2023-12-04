import ggplotnim
import std / [strutils, strformat]

## Notes:
## Font: STIXTwoText
## Text size: 11pt
## Figure caption size: 10pt
## Subcaption subfigure caption size: 9pt

## A4 paper: 210 × 297 mm²
## So: Total width in LaTeX pt:
## width: 8.26771653543 inch
## 597.507874016 pt (using 72.27 DPI)
##
## Using KOMAoption DIV 14 and BCOR=5mm yields 458.29268pt  458.29268pt
## To get that with a fixed margin on both sides needs:
## 139.215194016pt in the margin.
## That is 1.92632065886 inches and thus
## 4.8928544735 cm.
## Ergo: 2.44642723675cm on each side.


proc escapeLatex(s: string): string =
  result = s.multiReplace([("e^-", r"$e^-$"), ("\n", r"\\"), ("%", "\\%")])

#func side_by_side_theme(): Theme =
#  result = Theme(titleFont: some(font(16.0)),
#                 labelFont: some(font(12.0)),
#                 tickLabelFont: some(font(12.0)),
#                 tickLength: some(7.5),
#                 tickWidth: some(1.5),
#                 legendFont: some(font(12.0)),
#                 legendTitleFont: some(font(12.0, bold = true)),
#                 facetHeaderFont: some(font(12.0, alignKind = taCenter)),
#                 baseScale: some(1.0))

## This was the sizes used by adjusting by hand
#func side_by_side_theme(): Theme =
#  result = Theme(titleFont: some(font(20.0)),
#                 labelFont: some(font(16.0)),
#                 tickLabelFont: some(font(16.0)),
#                 tickLength: some(10.0),
#                 tickWidth: some(1.5),
#                 legendFont: some(font(16.0)),
#                 legendTitleFont: some(font(16.0, bold = true)),
#                 facetHeaderFont: some(font(16.0, alignKind = taCenter)),
#                 baseLabelMargin: some(0.5),
#                 baseScale: some(1.0))

#func theme_scale(scale: float, family = ""): Theme =
#  ## Returns a theme that scales all fonts, tick sizes etc. by the given factor compared
#  ## to the default values.
#  ##
#  ## If `family` given will overwrite the font family of all fonts to this.
#  result = default_scale()
#  proc `*`(x: Option[float], s: float): Option[float] =
#    doAssert x.isSome
#    result = some(x.get * s)
#  proc `*`(x: Option[Font], s: float): Option[Font] =
#    doAssert x.isSome
#    let f = x.get
#    let fam = if family.len > 0: family else: f.family
#    result = some(font(f.size * s, bold = f.bold, family = fam, alignKind = f.alignKind))
#  result.titleFont = result.titleFont * scale
#  result.labelFont = result.labelFont * scale
#  result.tickLabelFont = result.tickLabelFont * scale
#  result.tickLength = result.tickLength * scale
#  result.tickWidth = result.tickWidth * scale
#  result.legendFont = result.legendFont * scale
#  result.legendTitleFont = result.legendTitleFont * scale
#  result.facetHeaderFont = result.facetHeaderFont * scale
#  result.baseScale = result.baseScale * scale

# in ggplotnim.nim  
# func default_scale*(): Theme =
#   result = Theme(titleFont: some(font(16.0)),
#                  labelFont: some(font(12.0)),
#                  tickLabelFont: some(font(8.0)),
#                  tickLength: some(5.0),
#                  tickWidth: some(1.0),
#                  legendFont: some(font(12.0)),
#                  legendTitleFont: some(font(12.0, bold = true)),
#                  facetHeaderFont: some(font(8.0, alignKind = taCenter)),
#                  baseLabelMargin: some(0.3),
#                  baseScale: some(1.0))

#func side_by_side_theme(): Theme =
#  result = Theme(titleFont: some(font(10.0)),
#                 labelFont: some(font(10.0)),
#                 tickLabelFont: some(font(8.0)),
#                 tickLength: some(5.0),
#                 tickWidth: some(1.0),
#                 gridLineWidth: some(1.0),                 
#                 legendFont: some(font(10.0)),
#                 legendTitleFont: some(font(10.0, bold = true)),
#                 facetHeaderFont: some(font(8.0, alignKind = taCenter)),
#                 baseLabelMargin: some(0.4),
#                 annotationFont: some(font(8.0, family = "monospace")),
#                 baseScale: some(1.0))
  
const
  xLabel = r"Charge [$\SI{1e3}{e^-}$]"
  yLabel = "Counts"
  runNumber = 149
  chipNumber = 3
  suffix = "_charge"
  titleSuffix = ""
  useTeX = true

#let df = readCsv("~/phd/playground/Figs/run_149_2023-10-31_18-44-29/fe_spec_run_149_chip_3_charge.pdf.csv")
let df = readCsv("~/phd/playground/Figs/run_149_2023-12-03_18-26-39/fe_spec_run_149_chip_3_charge.pdf.csv")
let texts = @["μ = 917.1e3 e^-", "6.4 eV / 1000 e^-", "σ = 9.07 %", "χ²/dof = 0.65"]
let annot = if not useTeX: texts.join("\n")
            else: texts.join("\n").strip.escapeLatex()

echo annot

const textWidth = 455.24411 / 72.27 * 72.0
ggplot(df, aes("bins")) +
  geom_histogram(aes(y = "hist"), stat = "identity",
                 hdKind = hdOutline) +
  geom_line(aes("bins", y = "fit"),
            color = some(parseHex("FF00FF"))) +
  xlab(xlabel) +
  ylab(ylabel) +
  annotate(annot,
           left = 0.02,
           bottom = 0.4,
           font = font(16.0, family = "monospace")) +
  ggtitle(&"Fe spectrum for run: {runNumber}{titleSuffix}") +
  themeLatex(fWidth = 0.5, width = 600, sideBySide) + 
  ggsave(&"~/phd/playground/Figs/run_149_2023-10-31_18-44-29/fe_spec_run_{runNumber}_chip_{chipNumber}{suffix}.pdf",
         #width = width, height = height,
         useTeX = useTeX, standalone = useTeX)
