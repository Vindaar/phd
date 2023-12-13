import ggplotnim, nimhdf5
import ingrid / [tos_helpers, ingrid_types]

proc read(f: string, run: int): DataFrame =
  withH5(f, "r"):
    result = h5f.readRunDsets(
      run = run,
      chipDsets = some((chip: 3, dsets: @["eccentricity", "centerX", "centerY", "energyFromCharge"]))
    )

proc main(calib, back: string) =

  # read data from each file, one fixed run with good statistics
  # cut on silver region
  let dfC = read(calib, 128)
  let dfB = read(back, 124)
  var df = bind_rows([("Calibration", dfC), ("Background", dfB)], "Type")
    .filter(f{float -> bool: inRegion(`centerX`, `centerY`, crSilver)},
            f{float: `eccentricity` < 10.0})
  ggplot(df, aes("eccentricity", fill = "Type")) +
    #geom_histogram(bins = 100,
    #               hdKind = hdOutline, 
    #               position = "identity",
    #               alpha = 0.5,
    #               density = true) +
    xlab("Eccentricity") + ylab("Density") +   
    geom_density(color = "black", size = 1.0, alpha = 0.7, normalize = true) + 
    ggtitle("Eccentricity of calibration and background data") +
    themeLatex(fWidth = 0.5, width = 600, baseTheme = sideBySide) +
    margin(left = 2.2, right = 5.2) +         
    ggsave("Figs/background/eccentricity_calibration_background.pdf", useTeX = true, standalone = true)

  proc splitPeaks(x: float): string =
    if x >= 2.75 and x <= 3.25:
      "Escapepeak"
    elif x >= 5.55 and x <= 6.25:
      "Photopeak"
    else:
      "Unclear"

  let dfP = dfC
      .mutate(f{float: "Peak" ~ splitPeaks(`energyFromCharge`)})
      .filter(f{string: `Peak` != "Unclear"},
              f{`eccentricity` <= 2.0})
  ggplot(dfP, aes("eccentricity", fill = "Peak")) +
    #geom_histogram(bins = 50,
    #               hdKind = hdOutline, 
    #               position = "identity",
    #               alpha = 0.5,
    #               density = true) +
    xlab("Eccentricity") + ylab("Density") + 
    geom_density(color = "black", size = 1.0, alpha = 0.7, normalize = true) +
    ggtitle(r"$^{55}\text{Fe}$ photopeak (5.9 keV) and escapepeak (3 keV)") +
    themeLatex(fWidth = 0.5, width = 600, baseTheme = sideBySide) +
    margin(left = 2.2, right = 5.2) +     
    ggsave("Figs/background/eccentricity_photo_escape_peak.pdf", useTeX = true, standalone = true)
    
when isMainModule:
  import cligen
  dispatch main
