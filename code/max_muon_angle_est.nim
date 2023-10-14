import unchained, ggplotnim, strformat, sequtils
let w = 5.mm # mean width of a track in 8-10keV hump
let h = 3.cm # detector height
proc computeLength(α: UnitLess): mm =  ## todo: add degrees?
  ## α: float # Incidence angle
  var w_prime = w / cos(α)       # projected width taking incidence
                                 # angle into account
  let L_prime = tan(α) * h       # projected `'length'` of track
                                 # from center to center
  let L_full = L_prime + w_prime # full `'length'` is bottom to top, thus
                                 # + w_prime
  result = L_full.to(mm)
proc computeEccentricity(L_full, w: mm, α: UnitLess): UnitLess =
  let w_prime = w / cos(α)
  result = L_full / w_prime

let αs = linspace(0.0, degToRad(25.0), 1000)
let εs = αs.mapIt(it.computeLength.computeEccentricity(w, it).float)
let αsDeg = αs.mapIt(it.radToDeg)
let df = toDf(αsDeg, εs)

# maximum eccentricity for text annotation
let max_εs = max(εs)
let max_αs = max(αsDeg)

# compute the maximum angle under which `no` lead is seen
let d_open = 28.cm # assume 28 cm from readout to end of lead shielding
let h_open = 5.cm # assume open height is 10 cm, so 5 cm from center
let α_limit = arctan(h_open / d_open).radToDeg

# data for the limit of 8-10 keV eccentricity
let ε_max_hump = 1.3 # 1.2 is more reasonable, but 1.3 is the
                     # absolute upper limit
echo df.head(1)
echo α_limit
echo ε_max_hump
echo max_εs
echo max_αs
ggplot(df, aes("αsDeg", "εs")) +
  geom_line() +
  geom_linerange(aes = aes(x = α_limit, yMin = 1.0, yMax = max_εs),
                 color = color(1.0, 0.0, 1.0)) +
  geom_linerange(aes = aes(y = ε_max_hump, xMin = 0, xMax = max_αs),
                 color = color(0.0, 1.0, 1.0)) +
  geom_text(aes = aes(x = α_limit, y = max_εs + 0.1,
                      text = "Maximum angle no lead traversed")) +
  geom_text(aes = aes(x = 17.5, y = ε_max_hump + 0.1,
                      text = r"Largest $ε$ in $\SIrange{8}{10}{keV}$ hump")) +
  xlab(r"$α$: Incidence angle [°]") +
  ylab(r"$ε$: Eccentricity") +
  ylim(1.0, 4.0) +
  ggtitle(&"Expected eccentricity for tracks of mean width {w}") +
  ggsave("~/phd/Figs/muonStudies/exp_eccentricity_given_incidence_angle.pdf", useTeX = true, standalone = true,
        width = 600, height = 360)
