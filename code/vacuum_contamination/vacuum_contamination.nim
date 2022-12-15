import math
import tubing
import sequtils, future
import typeinfo

# This script contains a calculation for the total volume of the
# currently in use vacuum system at CAST (behind and including LLNL
# telescope)

proc cylinder_volume(diameter, length: float): float =
  # this proc calculates the volume of a cylinder, given a
  # diameter and a length both in cm
  result = PI * pow(diameter / 2.0, 2) * length
  
proc t_piece_volume(diameter, length_long, length_short: float): float =
  # this proc calculates the volume of a T shaped vacuum piece, using
  # the cylinder volume proc
  # inputs:
  # diameter: diameter of the tubing in cm
  # length_long: length of the long axis of the tubing
  # length_short: length of the short axis of the tubing
  result = cylinder_volume(diameter, length_long) + cylinder_volume(diameter, length_short - diameter)

proc cross_piece_volume(diameter, length: float): float =
  # this proc calculates the volume of a cross shaped vacuum piece, using
  # the cylinder volume proc
  # inputs:
  # diameter: diameter of the tubing in cm
  # length: length of one axis of the tubing
  result = 2 * cylinder_volume(diameter, length) - pow(diameter, 3)

proc calcTotalVacuumVolume(t: TubesMap): float =
  # function which calculates the total vacuum volume, using
  # the rough measurements of the length and diameters of all the
  # piping
  # the TubesMap consists of:
  # static_tubes : seq[tuple[diameter: float, length: float]]
  # flexible_tubes : seq[tuple[diameter: float, length: float]]
  # t_pieces : seq[tuple[diameter: float, length_long: float, length_short: float]]
  # crosses : seq[tuple[diameter: float, length: float]]
  # define variables to store static volume etc

  # calc volume of static tubing
  let static_vol = sum(map(
    t.static_tubes, (b: tuple[diameter, length: float]) ->
    float =>
    cylinder_volume(b.diameter / 10, b.length)))
  let flexible_vol = sum(map(
    t.flexible_tubes, (b: tuple[diameter, length: float]) -> 
    float =>
    cylinder_volume(b.diameter / 10, b.length)))
  let t_vol = sum(map(
    t.t_pieces, (b: tuple[diameter, length_long, length_short: float]) ->
    float =>
    t_piece_volume(b.diameter / 10, b.length_long, b.length_short)))
  let crosses_vol = sum(map(
    t.crosses, (b: tuple[diameter, length: float]) ->
    float =>
    cross_piece_volume(b.diameter / 10, b.length)))

  result = static_vol + flexible_vol + t_vol + crosses_vol

proc calcFlowRate(d, p, mu, x: float): float =
  # this function calculates the flow rate following the Poiseuille Equation
  # for a non-ideal gas under laminar flow.
  # inputs:
  # d: diameter of the tube in m
  # p: pressure difference between both ends of the tube in Pa
  # mu: dynamic viscosity of the medium
  # x: length of the tube
  # note: get viscosity e.g. from https://www.lmnoeng.com/Flow/GasViscosity.php
  # returns the flow rate in m^3 / s
  result = PI * pow(d, 4) * p / (128 * mu * x)

proc calcGasAmount(p, V, T: float): float =
  # this function calculates the amount of gas in moles follinwg
  # the ideal gas equation p V = n R T for a given pressure, volume
  # and temperature
  let R = 8.31446
  result = p * V / (R * T)

proc calcVolumeFromMol(p, n, T: float): float =
  # this function calculates the volume in m^3 follinwg
  # the ideal gas equation p V = n R T for a given pressure, amount in mol
  # and temperature
  let R = 8.31446
  result = n * R * T / p
    
proc main() =

  # TODO: checke whether diameter of 63mm for telescope is a reasonable
  # number!
  let t = getVacuumTubing()
  # first of all we need to calculate the total volume of the vacuum
  let volume = calcTotalVacuumVolume(t)
  echo volume

  # now calcualte flow rate through pipe
  let
    # 3 mm diameter
    d = 3e-3
    # 6 bar pressure diff
    p = 6.0e5
    # viscosity of air
    mu = 1.8369247e-4
    # ~2m of tubing
    x = 2.0
    flow = calcFlowRate(d, p, mu, x)

  echo(flow * 1e3, " l / s")

  # given the flow in liter, calc total gas inserted into the system
  let flow_l = flow * 1e3

  # detector volume in m^3
  let det_vol = cylinder_volume(12.0, 3.0) * 1e-6
  echo("Detector volume is : ", det_vol)
  # initial gas volume inside detector (1 bar is argon!), thus
  # only .5 bar
  let n_initial = calcGasAmount(0.5e5, det_vol, 293.15)
  # gas which came in after window ruptured
  let valve_open = 5.0
  # total volume in m^3
  let flow_vol = flow_l * 1e-3 * valve_open
  
  # since the flown volume is given for normal pressure and temp, calc
  # amount of gas
  let n_flow = calcGasAmount(1.0e5, flow_vol, 293.15)
  echo("Initial gas is : ", n_initial, " mol")
  echo("Gas from flow is : ", n_flow, " mol")
  let n_total = n_initial + n_flow
  echo("Total compressed air, which entered system : ", n_total)

  # calc volume corresponding to normal pressure
  let tot_vol_atm = calcVolumeFromMol(1e5, n_total, 293.15)
  echo("Total volume of air at normal pressure : ", tot_vol_atm * 1e3, " l")
  
when isMainModule:
  main()
