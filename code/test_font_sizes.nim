import ggplotnim
import std / [strutils, strformat]

proc escapeLatex(s: string): string =
  result = s.multiReplace([("e^-", r"$e^-$"), ("\n", r"\\")])

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

func side_by_side_theme(): Theme =
  result = Theme(titleFont: some(font(20.0)),
                 labelFont: some(font(16.0)),
                 tickLabelFont: some(font(16.0)),
                 tickLength: some(10.0),
                 tickWidth: some(1.5),
                 legendFont: some(font(16.0)),
                 legendTitleFont: some(font(16.0, bold = true)),
                 facetHeaderFont: some(font(16.0, alignKind = taCenter)),
                 baseLabelMargin: some(0.5),
                 baseScale: some(1.0))

func theme_scale(scale: float, family = ""): Theme =
  ## Returns a theme that scales all fonts, tick sizes etc. by the given factor compared
  ## to the default values.
  ##
  ## If `family` given will overwrite the font family of all fonts to this.
  result = default_scale()
  proc `*`(x: Option[float], s: float): Option[float] =
    doAssert x.isSome
    result = some(x.get * s)
  proc `*`(x: Option[Font], s: float): Option[Font] =
    doAssert x.isSome
    let f = x.get
    let fam = if family.len > 0: family else: f.family
    result = some(font(f.size * s, bold = f.bold, family = fam, alignKind = f.alignKind))
  result.titleFont = result.titleFont * scale
  result.labelFont = result.labelFont * scale
  result.tickLabelFont = result.tickLabelFont * scale
  result.tickLength = result.tickLength * scale
  result.tickWidth = result.tickWidth * scale
  result.legendFont = result.legendFont * scale
  result.legendTitleFont = result.legendTitleFont * scale
  result.facetHeaderFont = result.facetHeaderFont * scale
  result.baseScale = result.baseScale * scale

func theme_font_scale(scale: float, family = ""): Theme =
  ## Returns a theme similar to `theme_scale` but in which the margins are not
  ## scaled.
  result = theme_scale(scale, family)
  result.baseScale = some(1.0)

const
  xLabel = r"Charge [$\SI{1e3}{e^-}$]"
  yLabel = "Counts"
  runNumber = 149
  chipNumber = 3
  suffix = "_charge"
  titleSuffix = ""
  useTeX = true

let df = readCsv("/t/test/run_149_2023-10-31_18-44-29/fe_spec_run_149_chip_3_charge.pdf.csv")
let texts = @["μ = 917.1e3 e^-", "6.4 eV / 1000 e^-", "σ = 9.07 %", "χ²/dof = 0.65"]
let annot = if not useTeX: texts.join("\n")
            else: texts.join("\n").escapeLatex()

let golden_mean = (sqrt(5.0)-1.0)/2.0      # Aesthetic ratio
let width = 600.0
let height = width * golden_mean
ggplot(df, aes("bins")) +
  geom_histogram(aes(y = "hist"), stat = "identity",
                 hdKind = hdOutline) +
  geom_line(aes("bins", y = "fit"),
            color = some(parseHex("FF00FF"))) +
  xlab(xlabel) +
  ylab(ylabel) +
  annotate(annot,
           left = 0.02,
           bottom = 0.3,
           font = font(16.0, family = "monospace")) +
  ggtitle(&"Fe spectrum for run: {runNumber}{titleSuffix}") +
  side_by_side_theme() +
  ggsave(&"/tmp/test/fe_spec_run_{runNumber}_chip_{chipNumber}{suffix}.pdf",
         width = width, height = height,
         useTeX = useTeX, standalone = useTeX)
