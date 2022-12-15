import tables

type
  # defines the TubesMap datatype, which is a combined object to
  # store the different parts of the tubing each sequences of tuples
  TubesMap* = object
    static_tubes* : seq[tuple[diameter: float, length: float]]
    flexible_tubes* : seq[tuple[diameter: float, length: float]]
    t_pieces* : seq[tuple[diameter: float, length_long: float, length_short: float]]
    crosses* : seq[tuple[diameter: float, length: float]]

proc getVacuumTubing*(): TubesMap =
  # this function returns the data (originally written in calc_vacuum_volume.org
  # as a set of hash maps as a "TubesMap" datatype
  let st_tubing = @[(63.0, 10.0),
                    (63.0, 51.0),
                    (63.0, 21.5),
                    (25.0, 33.7),
                    (63.0, 20.0),
                    (63.0, 50.0),
                    (40.0, 15.5),
                    (16.0, 13.0),
                    (40.0, 10.0)]

  let fl_tubing = @[(16.0,  25.0),
                    (16.0,  25.0 ),
                    (16.0,  25.0 ),
                    (16.0,  25.0 ),
                    (16.0,  40.0 ),
                    (25.0,  90.0 ),
                    (25.0,  80.0 ),
                    (40.0,  50.0 ),
                    (16.0, 150.0 ),
                    (40.0,  80.0 ),
                    (40.0,  80.0)]

  let t_pieces = @[(40.0, 18.0, 21.0),
                   (16.0, 7.0, 4.5),
                   (40.0, 10.0, 10.0)]

  let crosses = @[(16.0, 10.0),
                  (40.0, 14.0),
                  (40.0, 14.0),
                  (40.0, 14.0)]
                    
  let t = TubesMap(static_tubes: st_tubing, flexible_tubes: fl_tubing, t_pieces: t_pieces, crosses: crosses)
  echo "Vacuum tubing is as follows:"
  echo t
  return t
