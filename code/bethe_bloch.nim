import math, macros, unchained, ggplotnim, sequtils, strformat, strutils
import thesisHelpers
import ggplotnim / ggplot_vegatex

let K = 4 * π * N_A * r_e^2 * m_e * c^2 # usually in: [MeV mol⁻¹ cm²]

defUnit(cm³•g⁻¹)
defUnit(J•m⁻¹)
defUnit(cm⁻³)
defUnit(g•mol⁻¹)
defUnit(MeV•g⁻¹•cm²)
defUnit(mol⁻¹)
defUnit(keV•cm⁻¹)
defUnit(g•cm⁻³)
defUnit(g•cm⁻²)

proc I[T](z: float): T =
  ## use Bloch approximation for all but Argon (better use tabulated values!)
  result = if z == 18.0: 188.0.eV.to(T) 
           else: (10.eV * z).to(T)

proc calcβ(γ: UnitLess): UnitLess =
  result = sqrt(1.0 - 1.0 / (γ^2))

proc betheBloch(z, Z: UnitLess, A: g•mol⁻¹, γ: UnitLess, M: kg): MeV•g⁻¹•cm² =
  ## result in MeV cm² g⁻¹ (normalized by density)
  ## z: charge of particle
  ## Z: charge of particles making up medium
  ## A: atomic mass of particles making up medium
  ## γ: Lorentz factor of particle
  ## M: mass of particle in MeV (or same mass as `m_e` defined as)
  let β = calcβ(γ)
  let W_max = 2 * m_e * c^2 * β^2 * γ^2 / (1 + 2 * γ * m_e / M + (m_e / M)^2)
  let lnArg = 2 * m_e * c^2 * β^2 * γ^2 * W_max / (I[Joule](Z)^2)
  result = (K * z^2 * Z / A * 1.0 / (β^2) * (
   0.5 * ln(lnArg) - β^2
  )).to(MeV•g⁻¹•cm²)

proc mostProbableLoss(z, Z: UnitLess, A: g•mol⁻¹, γ: UnitLess,
                      x: g•cm⁻²): keV =
  ## Computes the most probable value, corresponding to the peak of the Landau
  ## distribution, that gives rise to the Bethe-Bloch formula.
  ##
  ## Taken from PDG chapter 'Passage of particles through matter' equation
  ## `34.12` in 'Fluctuations in energy loss', version 2020).
  ##
  ## `x` is the "thickness". Density times length, `x = ρ * d`. The other parameters
  ## are as in `betheBloch` above.
  let β = calcβ(γ)
  let ξ = K / 2.0 * Z / A * z*z * (x / (β*β))
  const j = 0.200
  let I = I[Joule](Z)
  result = (ξ * ( ln((2 * m_e * c^2 * β^2 * γ^2).to(Joule) / I) + ln(ξ.to(Joule) / I) + j - β^2)).to(keV) # - δ*(β*γ)

proc density(p: mbar, M: g•mol⁻¹, temp: Kelvin): g•cm⁻³ =
  ## returns the density of the gas for the given pressure.
  ## The pressure is assumed in `mbar` and the temperature (in `K`).
  ## The default temperature corresponds to BabyIAXO aim.
  ## Returns the density in `g / cm^3`
  let gasConstant = 8.314.J•K⁻¹•mol⁻¹ # joule K^-1 mol^-1
  let pressure = p.to(Pa) # pressure in Pa
  result = (pressure * M / (gasConstant * temp)).to(g•cm⁻³)

proc E_to_γ(E: GeV): UnitLess =
  result = E.to(Joule) / (m_μ * c^2) + 1

type
  Element = object
    name: string
    Z: UnitLess
    M: g•mol⁻¹
    A: UnitLess # numerically same as `M`
    ρ: g•cm⁻³

proc initElement(name: string, Z: UnitLess, M: g•mol⁻¹, ρ: g•cm⁻³): Element =
  Element(name: name, Z: Z, M: M, A: M.UnitLess, ρ: ρ)

let M_Ar = 39.95.g•mol⁻¹ # molar mass. Numerically same as relative atomic mass
#let ρAr = density(1050.mbar, M_Ar, temp = 293.15.K)
let ρAr = density(1013.mbar, M_Ar, temp = 293.15.K)
let Argon = initElement("ar", 18.0.UnitLess, 39.95.g•mol⁻¹, ρAr)

proc intBethe(e: Element, d_total: cm, E0: eV, dx = 1.μm): eV =
  ## integrated energy loss of bethe formula after `d` cm of matter
  ## and returns the energy remaining
  var γ: UnitLess = E_to_γ(E0.to(GeV))
  var d: cm
  result = E0
  var totalLoss = 0.eV
  while d < d_total and result > 0.eV:
    let E_loss: MeV = betheBloch(-1, e.Z, e.M, γ, m_μ) * e.ρ * dx
    result = result - E_loss.to(eV)
    γ = E_to_γ(result.to(GeV))
    d = d + dx.to(cm)
    totalLoss = totalLoss + E_loss.to(eV)
  result = max(0.float, result.float).eV

func argonLabel(): string = "fig:theory:muon_argon_3cm_bethe_loss"

## TODO: add in the most probable value calc!  
func argonCaption(): string = 
  result = r"Mean energy loss via Bethe-Bloch (purple) equation of muons in \SI{3}{\cm} of argon at " &
    r"conditions in use in GridPix detector at CAST. \SI{1050}{mbar} of chamber pressure at room " &
    r"temperature. Note that the mean is skewed by events that transfer a large amount of energy, " &
    r"but are very rare! As such care must be taken interpreting the numbers. Green shows the most " &
    r"probable energy loss, based on the peak of the Landau-Vavilov distribution underlying the " &
    r"Bethe-Bloch mean value." &
    interactiveVega(argonLabel())

proc plotDetectorAbsorption(element: Element) =
  let E_float = logspace(-2, 2, 1000)
  let energies = E_float.mapIt(it.GeV)
  let E_loss = energies.mapIt((it.to(eV) - intBethe(element, 3.cm, it.to(eV))).to(keV).float)
  let E_lossMP = energies.mapIt(mostProbableLoss(-1, element.Z, element.M, E_to_γ(it), ρ_Ar * 3.cm).float)
  let df = seqsToDf({E_float, "Bethe-Bloch (BB)" : E_loss, "Most probable (MP)" : E_lossMP})
    .gather(["Bethe-Bloch (BB)", "Most probable (MP)"], "Type", "Value")
  ggplot(df, aes("E_float", "Value", color = "Type")) +
    geom_line() +
    #xlab(r"μ Energy [\si{\GeV}]") + ylab(r"$-\left\langle \frac{\mathrm{d}E}{\mathrm{d}x}\right\rangle$ [\si{\keV}]") +
    xlab(r"μ Energy [\si{\GeV}]") +
    ylab(r"$-\left\langle \frac{\mathrm{d}E}{\mathrm{d}x}\right\rangle$ (BB), $Δ_p$ (MP) [\si{\keV}]") +
    scale_x_log10() + scale_y_log10() +
    theme_latex() + 
    ggtitle(r"Energy loss of Muons in \SI{3}{\cm} " & &"{element.name.capitalizeAscii} at CAST conditions") +
    #ggsave(&"/home/basti/phd/Figs/muonStudies/{element.name}_energy_loss_cast.pdf", useTeX = true, standalone = true)
    ggvegatex(&"/home/basti/phd/Figs/muonStudies/{element.name}_energy_loss_cast",
              caption = argonCaption(),
              label = argonLabel())
plotDetectorAbsorption(Argon)

proc plotMostProbable(e: Element) =
  let E_float = logspace(-1.5, 2, 1000)
  let energies = E_float.mapIt(it.GeV)
  let E_loss = energies.mapIt(mostProbableLoss(-1, e.Z, e.M, E_to_γ(it), ρ_Ar * 3.cm))
  let df = toDf({"E_loss" : E_loss.mapIt(it.float), E_float})
  ggplot(df, aes("E_float", "E_loss")) +
    geom_line() +
    scale_x_log10() + 
    xlab("Energy [GeV]") + ylab("Most probable loss [keV]") +
    ggsave("/tmp/most_probable_loss.pdf")
plotMostProbable(Argon)
