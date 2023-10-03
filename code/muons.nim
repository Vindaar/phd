import math, macros, unchained
import seqmath, ggplotnim, sequtils, strformat

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

proc electronDensity(ρ: g•cm⁻³, Z, A: UnitLess): cm⁻³ =
  result = N_A * Z * ρ / (A * M_u.to(g•mol⁻¹))

proc I[T](z: float): T =
  ## use Bloch approximation for all but Argon (better use tabulated values!)
  # 188.0 eV from NIST table 
  result = if z == 18.0: 188.0.eV.to(T) 
           else: (10.eV * z).to(T)

proc calcβ(γ: UnitLess): UnitLess =
  result = sqrt(1.0 - 1.0 / (γ^2))

proc betheBloch(z, Z: UnitLess,
                   A: g•mol⁻¹,
                   γ: UnitLess,
                   M: kg): MeV•g⁻¹•cm² =
  ## result in MeV cm² g⁻¹ (normalized by density)
  ## z: charge of particle
  ## Z: charge of particles making up medium
  ## A: atomic mass of particles making up medium
  ## γ: Lorentz factor of particle
  ## M: mass of particle in MeV (or same mass as `m_e` defined as)
  let β = calcβ(γ)
  let W_max = 2 * m_e * c^2 * β^2 * γ^2 /
    (1 + 2 * γ * m_e / M + (m_e / M)^2)
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
  # factor 1000 for conversion of M in g / mol to kg / mol
  result = (pressure * M / (gasConstant * temp)).to(g•cm⁻³)

proc E_to_γ(E: GeV): UnitLess =
  result = E.to(Joule) / (m_μ * c^2) + 1

proc γ_to_E(γ: UnitLess): GeV =
  result = ((γ - 1) * m_μ * c^2).to(GeV)

type
  Element = object
    Z: UnitLess
    M: g•mol⁻¹
    A: UnitLess # numerically same as `M`
    ρ: g•cm⁻³
proc initElement(Z: UnitLess, M: g•mol⁻¹, ρ: g•cm⁻³): Element =
  Element(Z: Z, M: M, A: M.UnitLess, ρ: ρ)

# molar mass. Numerically same as relative atomic mass
let M_Ar = 39.95.g•mol⁻¹
let ρAr = density(1050.mbar, M_Ar, temp = 293.15.K)
let Argon = initElement(18.0.UnitLess, 39.95.g•mol⁻¹, ρAr)

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

proc plotDetectorAbsorption() =
  let E_float = logspace(-2, 2, 1000)
  let energies = E_float.mapIt(it.GeV)
  let E_loss = energies.mapIt(
    (it.to(eV) - intBethe(Argon, 3.cm, it.to(eV))).to(keV).float
  )
  let df = toDf(E_float, E_loss)
  ggplot(df, aes("E_float", "E_loss")) +
    geom_line() +
    xlab("μ Energy [GeV]") + ylab("ΔE [keV]") +
    scale_x_log10() + scale_y_log10() +
    ggtitle("Energy loss of Muons in 3 cm Ar at CAST conditions") +
    ggsave("/home/basti/phd/Figs/muons/ar_energy_loss_cast.pdf")
plotDetectorAbsorption()

let Atmosphere = @[(0.78084, initElement(7.0.UnitLess, 14.006.g•mol⁻¹, 1.2506.g•dm⁻³.to(g•cm⁻³))), # N2
                   (0.20964, initElement(8.0.UnitLess, 15.999.g•mol⁻¹, 1.429.g•dm⁻³.to(g•cm⁻³))),  # O2
                   (0.00934, initElement(18.0.UnitLess, 39.95.g•mol⁻¹, 1.784.g•dm⁻³.to(g•cm⁻³)))]  # Ar

proc plotMuonBethe() =
  let E_float = logspace(-2, 2, 1000)
  let energies = E_float.mapIt(it.GeV)
  var dEdxs = newSeq[float]()
  for e in energies:
    var dEdx = 0.0.MeV•g⁻¹•cm²
    for elTup in Atmosphere:
      let (w, element) = elTup
      let γ = E_to_γ(e)
      dEdx += w * betheBloch(-1, element.Z, element.M, γ, m_μ)
    dEdxs.add dEdx.float
  let df = toDf(E_float, dEdxs)
  ggplot(df, aes("E_float", "dEdxs")) +
    geom_line() +
    xlab("μ Energy [GeV]") + ylab("dE/dx [MeV•g⁻¹•cm²]") +
    scale_x_log10() + scale_y_log10() +
    ggtitle("Energy loss of Muons in atmosphere") +
    ggsave("/home/basti/phd/Figs/muons/energy_loss_muons_atmosphere.pdf")  
plotMuonBethe()
#if true: quit()
import math, unchained, ggplotnim, sequtils

const R_Earth = 6371.km
func distanceAtmosphere(θ: Radian, d: KiloMeter = 36.6149.km): UnitLess =
  ## NOTE: The default value for `d` is not to be understood as a proper height. It.s an
  ## approximation based on a fit to get `R_Earth / d = 174`!
  result = sqrt((R_Earth / d * cos(θ))^2 + 2 * R_Earth / d + 1) - R_Earth / d * cos(θ)

defUnit(cm⁻²•s⁻¹•sr⁻¹)  
defUnit(m⁻²•s⁻¹•sr⁻¹)
proc muonFlux(E: GeV, θ: Radian, E₀, E_c: GeV,
              I₀: m⁻²•s⁻¹•sr⁻¹,
              ε: GeV): m⁻²•s⁻¹•sr⁻¹ =
  const n = 3.0
  let N = (n - 1) * pow((E₀ + E_c).float, n - 1)
  result = I₀ * N * pow((E₀ + E).float, -n) *
    #pow((1 + E / ε).float, -1) *
    ( ( 1.0 / (1 + 1.1 * E * cos(θ) / 115.GeV).float) + (0.054 / (1 + 1.1 * E * cos(θ) / 850.GeV).float) ) * 
    pow(distanceAtmosphere(θ), -(n - 1))

from numericalnim/integrate import simpson
proc plotE_vs_flux(θ: Radian, E₀, E_c: GeV, I₀: m⁻²•s⁻¹•sr⁻¹, ε: GeV,
                   suffix = "") =
  let energies = linspace(E_c.float, 100.0, 1000)
  let E = energies.mapIt(it.GeV)
  let flux = E.mapIt(muonFlux(it, θ, E₀, E_c, I₀, ε).float) # .to(cm⁻²•s⁻¹•sr⁻¹)
  let df = toDf(energies, flux)

  echo "Integrated flux: ", simpson(flux, energies)
  
  ggplot(df, aes("energies", "flux")) +
    geom_line() +
    xlab("Energy [GeV]") + ylab("Flux [m⁻²•s⁻¹•sr⁻¹]") +
    scale_x_log10() + scale_y_log10() +
    ggtitle(&"Flux dependency on the energy of muons at θ = {θ.to(°)}{suffix}") +
    ggsave(&"/home/basti/phd/Figs/muons/energy_vs_flux_cosmic_muons{suffix}.pdf")
plotE_vs_flux(0.Radian,
              2.5.GeV, #4.29.GeV,
              0.5.GeV, 70.7.m⁻²•s⁻¹•sr⁻¹, 854.GeV)


let E₀ = 25.0.GeV
let I₀ = 90.0.m⁻²•s⁻¹•sr⁻¹
let E_c = 1.GeV
let ε = 2000.GeV

proc plotFlux_at_CAST() =
  let energies = linspace(0.5, 100.0, 1000)
  let E = energies.mapIt(it.GeV)
  let flux = E.mapIt(muonFlux(it, 88.0.degToRad.Radian, E₀, E_c, I₀, ε).float)
  let df = toDf(energies, flux)
  ggplot(df, aes("energies", "flux")) +
    geom_line() +
    xlab("Energy [GeV]") + ylab("Flux [m⁻²•s⁻¹•sr⁻¹]") +
    scale_x_log10() + scale_y_log10() +
    ggtitle("Flux dependency on the energy at θ = 88° at CAST altitude") +
    ggsave("/home/basti/phd/Figs/muons/flux_at_cast_88_deg.pdf")
plotFlux_at_CAST()

proc computeMeanEnergyLoss() =
  let energies = linspace(0.5, 100.0, 1000)
  let E = energies.mapIt(it.GeV)
  let flux = E.mapIt(muonFlux(
    it, 88.0.degToRad.Radian, E₀, E_c, I₀, ε).float
  )
  let E_loss = E.mapIt(
    (it.to(eV) - intBethe(Argon, 3.cm, it.to(eV))).to(keV).float
  )
  let fluxSum = flux.sum
  let df = toDf(energies, E_loss, flux)
      .mutate(f{"flux" ~ `flux` / fluxSum},
              f{"AdjFlux" ~ `E_loss` * `flux`})
  echo "Mean energy loss: ", df["AdjFlux", float].sum
computeMeanEnergyLoss()

proc computeHeight(S: Meter, θ: Radian): KiloMeter =
  ## For given remaining distance distance along the path of a muon
  ## `S` (see fig. 1 in 1606.06907) computes the remaining height above
  ## ground. Formula is the result of inverting eq. 7 to `d` using quadratic
  ## formula. Positive result, because negative is negative.
  result = (-1.0 * R_Earth + sqrt(R_Earth^2 + S^2 + 2 * S * R_Earth * cos(θ)).m).to(km)

import algorithm
defUnit(K•m⁻¹)
proc barometricFormula(h: KiloMeter): g•cm⁻³ =
  let hs = @[0.0.km, 11.0.km]
  let ρs = @[1.225.kg•m⁻³, 0.36391.kg•m⁻³]
  let Ts = @[288.15.K, 216.65.K]
  let Ls = @[-1.0 * 0.0065.K•m⁻¹, 0.0.K•m⁻¹]
  let M_air = 0.0289644.kg•mol⁻¹
  let R = 8.3144598.N•m•mol⁻¹•K⁻¹
  let g_0 = 9.80665.m•s⁻²
  let idx = hs.mapIt(it.float).lowerBound(h.float) - 1
  case idx
  of 0:
    # in Troposphere, using regular barometric formula for denities
    let expArg = g_0 * M_air / (R * Ls[idx])
    result = (ρs[idx] * pow(Ts[idx] / (Ts[idx] + Ls[idx] * (h - hs[idx])), expArg)).to(g•cm⁻³)
  of 1:
    # in Tropopause, use equation valid for L_b = 0
    result = (ρs[idx] * exp(-1.0 * g_0 * M_air * (h - hs[idx]) / (R * Ts[idx]))).to(g•cm⁻³)
  else: doAssert false, "Invalid height! Outside of range!"

import random
randomize(430)
proc intBetheAtmosphere(E: GeV, θ: Radian, dx = 10.cm): eV =
  ## integrated energy loss using Bethe formula for muons generated at
  ## `15.km` under an angle of `θ` to the observer for a muon of energy
  ## `E`.
  # Main contributions in Earth's atmosphere
  const τ = 2.19618.μs # muon half life
  let elements = Atmosphere
  var γ: UnitLess = E_to_γ(E.to(GeV))
  result = E.to(eV)
  var totalLoss = 0.eV
  let h_muon = 15.km # assume creation happens in `15.km`
  let S = h_muon.to(m) * distanceAtmosphere(θ.rad, d = h_muon)
  var S_prime = S
  while S_prime > 0.m and result > 0.eV:
    let h = computeHeight(S_prime, θ)
    let ρ_at_h = barometricFormula(h)
    var E_loss = 0.0.MeV
    for eTup in elements: # compute the weighted contribution of the element fraction
      let (w, e) = eTup
      E_loss += w * betheBloch(-1, e.Z, e.M, γ, m_μ) * ρ_at_h * dx

    ## Add step for radioactive decay of muon.
    ## - given `dx` compute likelihood of decay
    ## - eigen time of muon: dx / v = dt. dτ = dt / γ
    ## - muon decay is λ = 1 / 2.2e-6s
    let β = calcβ(γ)
    # compute effective time in lab frame
    let δt = dx / (β * c)
    # compute eigen time
    let δτ = δt / γ
    # probability of a decay in this time frame
    let p = pow(1 / math.E, δτ / τ)
    # decay with likelihood `p`
    #echo "γ = ", γ, " yields ", p, " in δτ ", δτ, " for energy ", E
    if rand(1.0) < (1.0 - p):
      echo "Particle decayed after: ", S_prime
      return 0.eV
          
    result = result - E_loss.to(eV)
    S_prime = S_prime - dx
    γ = E_to_γ(result.to(GeV))
    totalLoss = totalLoss + E_loss.to(eV)
  echo "total Loss ", totalLoss.to(GeV)
  result = max(0.float, result.float).eV

block MuonLimits:
  let τ_μ = 2.1969811.μs
  # naively this means given some distance `s` the muon can
  # traverse `s = c • τ_μ` (approximating its speed by `c`) before
  # it has decayed with a 1/e chance
  # due to special relativity this is extended by γ
  let s = c * τ_μ
  echo s
  # given production in 15 km, means
  let h = 15.km
  echo h / s
  # so a reduction of (1/e)^22. So 0.
  # now it's not 15 km but under an angle `θ = 88°`.
  let R_over_d = 174.UnitLess
  let n = 3.0
  let E₀ = 25.0.GeV
  let I₀ = 90.0.m⁻²•s⁻¹•sr⁻¹
  let E_c = 1.GeV
  let ε = 2000.GeV

  # distance atmospher gives S / d, where `d` corresponds to our `h` up there
  let S = h * distanceAtmosphere(88.0.degToRad.rad)
  # so about 203 km
  # so let's say 5 * mean distance is ok, means we ned
  let S_max = S / 5.0
  # so need a `γ` such that `s` is stretched to `S_max`
  let γ = S_max / s
  echo γ
  # ouch. Something has to be wrong. γ of 61?

  # corresponds to an energy loss of what?
  let Nitrogen = initElement(7.0.UnitLess, 14.006.g•mol⁻¹, 1.2506.g•dm⁻³.to(g•cm⁻³))
  echo "================================================================================"
  echo "Energy left: ", intBethe(Nitrogen, S.to(cm), 6.GeV.to(eV), dx = 1.m.to(μm)).to(GeV)
  proc print(E: GeV, θ: Radian) =
    let left = intBetheAtmosphere(E, θ = θ).to(GeV)
    echo "E = ", E, ", θ = ", θ, ", Bethe = ", E - left
  print(6.GeV, 0.Radian)
  #print(200.GeV, 0.Radian)  
  #print(200.GeV, 88.°.to(Radian))
  #print(200.GeV, 75.°.to(Radian))

  let E_loss75 = 100.GeV - intBetheAtmosphere(100.GeV, 75.°.to(Radian)).to(GeV)
  plotE_vs_flux(75.°.to(Radian),
                E_loss75, #23.78.GeV, #25.GeV, #E_loss75,
                1.0.GeV,
                90.m⁻²•s⁻¹•sr⁻¹, #65.2.m⁻²•s⁻¹•sr⁻¹,
                2000.GeV, # 854.GeV,
                "_at_75deg")

  
  echo "S@75° = ", h * distanceAtmosphere(75.0.degToRad.rad, d = 15.0.km)
  echo "================================================================================"  
echo E_to_γ(4.GeV)
echo E_to_γ(0.GeV)

proc plotE_vs_flux_and_angles(E_c: GeV, I₀: m⁻²•s⁻¹•sr⁻¹, ε: GeV,
                              suffix = "") =
  ## Generates a plot of the muon flux vs energy for a fixed set of different
  ## angles.
  ##
  ## The energy loss is computed using a fixed 
  let energies = logspace(log10(E_c.float), 2.float, 1000)
  let angles = linspace(0.0, 80.0, 9)
  block CalcLossEachMuon:
    var df = newDataFrame()
    for angle in angles:
      let E = energies.mapIt(it.GeV)
      let θ = angle.°.to(Radian)
      var flux = newSeq[float]()
      var E_initials = newSeq[float]()
      var E_lefts = newSeq[float]()
      var lastDropped = 0.GeV
      for e in E:
        let E_left = intBetheAtmosphere(e, θ).to(GeV)
        if E_left <= 0.0.GeV:
          echo "Skipping energy : ", e, " as muon was lost in atmosphere"
          continue
        elif E_left <= E_c:
          echo "Skipping energy : ", e, " as muon has less than E_c = ", E_c, " energy left"
          lastDropped = e
          continue
        let E₀ = e - E_left
        flux.add muonFlux(e, θ, E₀, E_c, I₀, ε).float
        E_initials.add e.float        
        E_lefts.add E_left.float
      let dfLoc = toDf({E_initials, E_lefts, flux, "angle [°]" : angle})
      #  .filter(f{`E_initials` >= lastDropped.float})
      df.add dfLoc
    ggplot(df, aes("E_initials", "flux", color = factor("angle [°]"))) +
      geom_line() +
      xlab(r"Initial energy [\si{GeV}]") + ylab(r"Flux [\si{m^{-2}.s^{-1}.sr^{-1}}]") +
      scale_x_log10() + scale_y_log10() +
      ggtitle(&"Differential muon flux dependency at different angles{suffix}") +
      ggsave(&"/home/basti/phd/Figs/muons/initial_energy_vs_flux_and_angle_cosmic_muons{suffix}.pdf",
             useTeX = true, standalone = true, width = 600, height = 450)
  
    ggplot(df, aes("E_lefts", "flux", color = factor("angle [°]"))) +
      geom_line() +
      xlab(r"Energy at surface [\si{GeV}]") + ylab(r"Flux [\si{m^{-2}.s^{-1}.sr^{-1}}]") +
      scale_x_log10() + scale_y_log10() +
      ggtitle(&"Differential muon flux dependency at different angles{suffix}") +
      ggsave(&"/home/basti/phd/Figs/muons/final_energy_vs_flux_and_angle_cosmic_muons{suffix}.pdf",
             useTeX = true, standalone = true, width = 600, height = 450)              
  block StaticLoss:
    var df = newDataFrame()
    for angle in angles:
      let E = energies.mapIt(it.GeV)
      let θ = angle.°.to(Radian)
      let E₀ = 100.GeV - intBetheAtmosphere(100.GeV, 0.0.Radian).to(GeV)    
      let flux = E.mapIt(muonFlux(it, θ, E₀, E_c, I₀, ε).float)
      let dfLoc = toDf({energies, flux, "angle [°]" : angle})
      df.add dfLoc
    ggplot(df, aes("energies", "flux", color = factor("angle [°]"))) +
      geom_line() +
      xlab("Energy [GeV]") + ylab("Flux [m⁻²•s⁻¹•sr⁻¹]") +
      scale_x_log10() + scale_y_log10() +
      ggtitle(&"Differential muon flux dependency at different angles{suffix}") +
      ggsave(&"/home/basti/phd/Figs/muons/energy_vs_flux_and_angle_cosmic_muons{suffix}.pdf")


#proc plotE_vs_flux_and_angles(E_c: GeV, I₀: m⁻²•s⁻¹•sr⁻¹, ε: GeV,
#                              suffix = "") =
#  ## Generates a plot of the integrated muon flux vs angles for a fixed set of different
#  ## energies.
#  let angles = linspace(0.0, 90.0, 100)
#  var df = newDataFrame()
#  let energies = linspace(E_c.float, 100.0, 1000)
#  let E = energies.mapIt(it.GeV)
#  for angle in angles:
#    let θ = angle.°.to(Radian)
#    let E₀ = 100.GeV - intBetheAtmosphere(100.GeV, θ).to(GeV)
#    let flux = E.mapIt(muonFlux(it, θ, E₀, E_c, I₀, ε).float) 
#    let dfLoc = toDf({energies, flux, "angle [°]" : angle})
#    df.add dfLoc
#  ggplot(df, aes("energies", "flux", color = factor("angle [°]"))) +
#    geom_line() +
#    xlab("Energy [GeV]") + ylab("Flux [m⁻²•s⁻¹•sr⁻¹]") +
#    scale_x_log10() + scale_y_log10() +
#    ggtitle(&"Differential muon flux dependency at different angles{suffix}") +
#    ggsave(&"/home/basti/phd/Figs/muons/energy_vs_flux_and_angle_cosmic_muons{suffix}.pdf")

# different angles!      
block MuonBehavior:
  plotE_vs_flux_and_angles(0.3.GeV, 90.m⁻²•s⁻¹•sr⁻¹, 854.GeV)

proc unbinnedCdf(x: seq[float]): (seq[float], seq[float]) =
  ## Computes the CDF of unbinned data
  var cdf = newSeq[float](x.len)
  for i in 0 ..< x.len:
    cdf[i] = i.float / x.len.float
  result = (x.sorted, cdf)

import random, algorithm
proc sampleFlux(samples = 1_000_000): DataFrame =
  randomize(1337)
  let energies = linspace(0.1, 100.0, 100_000)
  #let energies = logspace(0, 2, 1000)
  let E = energies.mapIt(it.GeV)
  let flux = E.mapIt(muonFlux(it, 88.0.degToRad.Radian, E₀, E_c, I₀, ε).float)
  # given flux compute CDF
  let fluxCS = flux.cumSum()
  let fluxCS_sorted = flux.sorted.cumSum()
  let fluxCDF = fluxCS.mapIt(it / fluxCS[^1])
  let fluxCDF_sorted = fluxCS_sorted.mapIt(it / fluxCS_sorted[^1])

  let (data, cdf) = unbinnedCdf(flux)

  let dfX = toDf(energies, fluxCS, fluxCS_sorted, fluxCDF, fluxCDF_sorted)
  ggplot(dfX, aes("energies", "fluxCS")) +
    geom_line() +
    ggsave("/t/cumsum_test.pdf")
  ggplot(dfX, aes("energies", "fluxCDF")) +
    geom_line() +
    ggsave("/t/cdf_test.pdf")    
  ggplot(dfX, aes("energies", "fluxCS_sorted")) +
    geom_line() +
    ggsave("/t/cumsum_sorted_test.pdf")    
  ggplot(dfX, aes("energies", "fluxCDF_sorted")) +
    geom_line() +
    ggsave("/t/cdf_sorted_test.pdf")

  ggplot(toDf(data, cdf), aes("data", "cdf")) +
    geom_line() +
    ggsave("/t/unbinned_cdf.pdf")
  
  #if true: quit()
  var lossesBB = newSeq[float]()
  var lossesMP = newSeq[float]()
  var energySamples = newSeq[float]()

  let dedxmin = 1.519.MeV•cm²•g⁻¹
  echo "Loss = ", (dedxmin * Argon.ρ * 3.cm).to(keV)
  
  for i in 0 ..< samples:
    # given the fluxCDF sample different energies, which correspond to the
    # distribution expected at CAST
    let idx = fluxCdf.lowerBound(rand(1.0))
    let E_element = E[idx]
    # given this energy `E` compute the loss
    let lossBB = (E_element.to(eV) - intBethe(Argon, 3.cm, E_element.to(eV), dx = 50.μm)).to(keV).float
    lossesBB.add lossBB
    let lossMP = mostProbableLoss(-1, Argon.Z, Argon.M, E_Element.E_to_γ(), Argon.ρ * 3.cm)
    lossesMP.add lossMP.float
    #echo "Index ", i, " yields energy ", E_element, " and loss ", loss
    energySamples.add E_element.float
  let df = toDf(energySamples, lossesBB, lossesMP)
    .gather(["lossesBB", "lossesMP"], "Type", "Value")
  ggplot(df, aes("Value", fill = "Type")) +
    geom_histogram(bins = 300, hdKind = hdOutline, alpha = 0.5, position = "identity") +
    margin(top = 2) +
    xlim(5, 15) +
    ggtitle(&"Energy loss of muon flux at CAST based on MC sampling with {samples} samples") +
    ggsave("/home/basti/phd/Figs/muons/sampled_energy_loss.pdf")

  ggplot(df, aes("energySamples")) +
    geom_histogram(bins = 300) +
    margin(top = 2) +
    ggtitle(&"Sampled energies for energy loss of muon flux at CAST") +
    ggsave("/home/basti/phd/Figs/muons/sampled_energy_for_energy_loss.pdf")
  let (samples, bins) = histogram(energySamples, bins = 300)
  let dfH = toDf({"bins" : bins[0 ..< ^1], samples})
    .filter(f{`bins` > 0.0 and `samples`.float > 0.0})
  ggplot(dfH, aes("bins", "samples")) +
    geom_line() +
    scale_x_log10() + 
    margin(top = 2) +
    ggtitle(&"Sampled energies for energy loss of muon flux at CAST") +
    ggsave("/home/basti/phd/Figs/muons/sampled_energy_for_energy_loss_manual.pdf")

  ggplot(toDf(energies, flux), aes("energies", "flux")) +
    geom_line() +
    scale_x_log10() +
    ggsave("/tmp/starting_data_e_flux.pdf")

  ggplot(toDf(energies, flux), aes("energies", "flux")) +
    geom_line() +
    ggsave("/tmp/linear_starting_data_e_flux.pdf")
    

discard sampleFlux(samples = 1_000_000)
