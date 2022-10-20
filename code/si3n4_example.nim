import xrayAttenuation, ggplotnim
# generate a compound of silicon and nitrogen with correct number of atoms
let Si₃N₄ = compound((Si, 3), (N, 4))
# use the transmission plotting helper with known density for the material and
# desired thickness
Si₃N₄.plotTransmission(3.44.g•cm⁻³, 300.nm.to(Meter),
                       outpath = "./Figs/theory")
