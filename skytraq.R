
# 0 – GPS 1 – SBAS 2 – GLONASS 3 – Galileo 4 – QZSS 5 – BeiDou 6 - IRNSS
skytraq.getObsType <- function(type, svrID) {
  name = switch(type + 1, "PG", "SBAS", "PR", "PE", "PJ", "PC", "IRNSS")
  id = switch(type + 1, svrID, svrID - 120, svrID, svrID, svrID - 192, svrID)
  return(paste(name, sprintf("%02d", as.numeric(id)), sep = ""))
}

skytraq.findHeader <- function(msg, val) {
  e5_pos = which(msg %in% as.raw(val))
  e5_head = e5_len = 0
  for (i in e5_pos) {
    if (msg[i - 4] == as.raw(0xa0) && msg[i - 3] == as.raw(0xa1)) {
      e5_head = i
      e5_len = bitwShiftL(as.numeric(msg[i - 2]), 8) + as.numeric(msg[i - 1])
      break
      
    }
  }
  res <- list("head" = e5_head, "len" = e5_len)
  return(res)
}

skytraq.parseE5 <- function(msg) {
  e5.st = skytraq.findHeader(msg, 0xE5)
  i = e5.st$head
  MsgID = msg[i]
  i = i + 1
  Version = msg[i]
  i = i + 1
  IOD = msg[i]
  i = i + 1
  WN = bitwShiftL(as.numeric(msg[i]), 8) + as.numeric(msg[i + 1])
  i = i + 2
  TOW = readBin(msg[i:(i + 3)], integer(), size = 4, endian = "big")
  i = i + 4
  Measurement_period = bitwShiftL(as.numeric(msg[i]), 8) + as.numeric(msg[i + 1])
  i = i + 2
  Measurement_indicator = msg[i]
  i = i + 2
  NMEAS = as.numeric(msg[i])
  
  if (NMEAS > 0) {
    df = data.frame()
  } else {
    print("no data")
    return(NA)
  }
  for (loop in (1:NMEAS)) {
    i = i + 1
    GNSS_TYPE = bitwAnd(as.numeric(msg[i]), 7)
    Signal_type = bitwAnd(bitwShiftR(as.numeric(msg[i]), 4), 0xF)
    i = i + 1
    SVID = as.numeric(msg[i])
    i = i + 1
    FreqIDnLTI = msg[i]
    i = i + 1
    CNR = as.numeric(msg[i])
    i = i + 1
    Pseudorange = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
    i = i + 8
    carrier_phase = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
    i = i + 8
    Doppler = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
    i = i + 4
    Pseudorange_SD = msg[i]
    i = i + 1
    carrier_cycle_SD = msg[i]
    i = i + 1
    doppler_SD = msg[i]
    i = i + 1
    Channel_Indicator = msg[i]
    i = i + 3
    df <-
      rbind(
        df,
        c(
          GNSS_TYPE,
          Signal_type,
          SVID,
          CNR,
          Pseudorange,
          carrier_phase,
          Doppler,
          skytraq.getObsType(GNSS_TYPE, SVID)
        ),
        stringsAsFactors = FALSE
      )
  }
  i = i + 1
  colnames(df) <-
    c(
      "GNSS Type",
      "Signal Type",
      "Server ID",
      "CNR",
      "Pseudorange",
      "Accumulated carrier cycle ",
      "Doppler frequency",
      "Observation Type"
    )
  return (list(
    "WeekNum" = WN,
    "TimeOfWeek" = TOW,
    "DataFrame" = df
  ))
}

skytraq.parseE8 <- function(msg) {
  e8.st = skytraq.findHeader(msg, 0xE8)
  i = e8.st$head
  MsgID = msg[i]
  i = i + 1
  version = msg[i]
  i = i + 1
  IOD = msg[i]
  i = i + 1
  NSVS = as.numeric(msg[i])
  i = i + 1
  if (NSVS > 0) {
    df = data.frame()
  } else {
    print("no data")
    return(NA)
  }
  for (loop in (1:NSVS)) {
    GNSS_TYPE = as.numeric(msg[i])
    i = i + 1
    SVID = as.numeric(msg[i])
    i = i + 1
    Elev = readBin(
      msg[i:(i + 1)],
      integer(),
      size = 2,
      signed = TRUE,
      endian = "big"
    )
    Elev = Elev * pi/180
    i = i + 2
    Azim = readBin(
      msg[i:(i + 1)],
      integer(),
      size = 2,
      signed = TRUE,
      endian = "big"
    )
    Azim = Azim * pi/180
    i = i + 2
    df <-
      rbind(df,
            c(
              GNSS_TYPE,
              SVID,
              Elev,
              Azim,
              skytraq.getObsType(GNSS_TYPE, SVID)
            ),
            stringsAsFactors = FALSE)
    print(i - e8.st$head)
  }
  colnames(df) <-
    c("GNSS Type",
      "SV ID",
      "Elevation",
      "Azimuth",
      "Observation Type")
  return(df)
}

skytraq.parseDF <- function(msg) {
  df.st = skytraq.findHeader(msg, 0xDF)
  i= df.st$head
  MsgID = msg[i]
  i = i + 1
  IOD = msg[i]
  i = i + 1
  NaviState = msg[i]
  i = i + 1
  WN = bitwShiftL(as.numeric(msg[i]), 8) + as.numeric(msg[i + 1])
  i = i + 2
  tow = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
  i = i + 8
  pos.x = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
  i = i + 8
  pos.y = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
  i = i + 8
  pos.z = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
  i = i + 8
  vel.x = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  vel.y = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  vel.z = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  ClockBias = readBin(msg[i:(i + 7)], numeric(), size = 8, endian = "big")
  i = i + 8
  ClockDrift = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  GDOP = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  PDOP = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  HDOP = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  VDOP = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  TDOP = readBin(msg[i:(i + 3)], numeric(), size = 4, endian = "big")
  i = i + 4
  return (list(WN, tow, pos.x, pos.y, pos.z))
}
# a = ms(msg = msg)
# b = skytraq.parseE8(msg = msg)
# c = skytraq.parseDF(msg = msg)

# R program to illustrate
# Joining of dataframes

# df = merge(
#   x = b[c("Elevation", "Azimuth", "Observation Type")],
#   y = a$DataFrame[c(
#     "Signal Type",
#     "CNR",
#     "Pseudorange",
#     "Accumulated carrier cycle ",
#     "Doppler frequency",
#     "Observation Type"
#   )],
#   by = "Observation Type",
#   all.x = TRUE,
#   all.y = TRUE
# )
# View(df)


skytraq.extract <- function(msg) {
  
}
