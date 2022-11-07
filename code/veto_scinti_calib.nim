import ggplotnim, sequtils
let df = toDf({ "Thr" : tbl["Threshold / mV"],
                "Szinti" : tbl["Counts Szinti"],
                "Coinc" : tbl["Counts Coincidence"] })
ggplot(df, aes("Thr", "Szinti")) +
  geom_point() + geom_line() +
  xlab(r"Threshold \[mV\]") + ylab(r"Counts \[#\]") +
  ggtitle(r"Calibration measurements of \SI{10}{min} each") + 
  ggsave("/home/basti/phd/Figs/detector/calibration/veto_scintillator_calibration_rd51.pdf",
         useTeX = true, standalone = true)

ggplot(df, aes("Thr", "Coinc")) +
  geom_point() + geom_line() +
  xlab(r"Threshold \[mV\]") + ylab(r"Counts \[#\]") +
  ggtitle(r"Calibration measurements of \SI{10}{min} each in 3-way coincidence") + 
  ggsave("/home/basti/phd/Figs/detector/calibration/veto_scintillator_calibration_coinc_rd51.pdf",
         useTeX = true, standalone = true)
