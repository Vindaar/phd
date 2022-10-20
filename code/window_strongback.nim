## Super dumb MC sampling over the entrance window using the Johanna's code from `raytracer2018.nim`
## to check the coverage of the strongback of the 2018 window
##
## Of course one could just color areas based on the analytical description of where the
## strongbacks are, but this is more interesting and looks fun. The good thing is it also
## allows us to easily compute the fraction of pixels within and outside the strongbacks.
import ggplotnim, random, chroma
proc colorMe(y: float): bool =
  const
    stripDistWindow = 2.3  #mm
    stripWidthWindow = 0.5 #mm
  if abs(y) > stripDistWindow / 2.0 and
     abs(y) < stripDistWindow / 2.0 + stripWidthWindow or
     abs(y) > 1.5 * stripDistWindow + stripWidthWindow and
     abs(y) < 1.5 * stripDistWindow + 2.0 * stripWidthWindow:
    result = true
  else:
    result = false

proc sample() =
  randomize(423)
  const nmc = 5_000_000
  let black = color(0.0, 0.0, 0.0)
  var dataX = newSeqOfCap[float](nmc)
  var dataY = newSeqOfCap[float](nmc)
  var inside = newSeqOfCap[bool](nmc)
  for idx in 0 ..< nmc:
    let x = rand(-7.0 .. 7.0)
    let y = rand(-7.0 .. 7.0)
    if x*x + y*y < 7.0 * 7.0:
      dataX.add x
      dataY.add y
      inside.add colorMe(y)
  let df = toDf(dataX, dataY, inside)
  echo "A fraction of ", df.filter(f{`inside` == true}).len / df.len, " is occluded by the strongback"
  let dfGold = df.filter(f{abs(idx(`dataX`, float)) <= 2.25 and
                           abs(idx(`dataY`, float)) <= 2.25})
  echo "Gold region: A fraction of ", dfGold.filter(f{`inside` == true}).len / dfGold.len, " is occluded by the strongback"
  ggplot(df, aes("dataX", "dataY", fill = "inside")) +
    geom_point(size = 1.0) +
    # draw the gold region as a black rectangle
    geom_linerange(aes = aes(y = 0, x = 2.25, yMin = -2.25, yMax = 2.25), color = "black") +
    geom_linerange(aes = aes(y = 0, x = -2.25, yMin = -2.25, yMax = 2.25), color = "black") +
    geom_linerange(aes = aes(x = 0, y = 2.25, xMin = -2.25, xMax = 2.25), color = "black") +
    geom_linerange(aes = aes(x = 0, y = -2.25, xMin = -2.25, xMax = 2.25), color = "black") +
    xlab("x [mm]") + ylab("y [mm]") +
    ggtitle("Idealized schematic of the window layout. Strongback in red.") +
    ggsave("/home/basti/phd/Figs/SiN_window_occlusion.png", width = 1150, height = 1000)
sample()
