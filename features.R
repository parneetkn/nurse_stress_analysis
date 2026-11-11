# features.R - Part 2: Feature engineering. Rolling windows are computed per SESSION (not per nurse)
# so windows never span recording breaks. Short gaps (<=5 s) forward-filled. Then 1-min epochs.
# Output: outputs/dat_features.rds, outputs/epoch_1min.rds
source("config.R"); library(data.table)
dat <- readRDS(file.path(OUT, "dat_clean.rds")); setorder(dat, session, sec)

#dat[, c("EDA","HR","TEMP") := lapply(.SD, nafill, type = "locf", maxgap = 5), by = session,
 #   .SDcols = c("EDA","HR","TEMP")]

# Forward-fill NA runs of at most 5 s; longer runs stay NA
fill5 <- function(x) {
  f <- nafill(x, type = "locf")
  r <- sequence(rle(is.na(x))$lengths)          # position within each NA / non-NA run
  f[is.na(x) & r > 5] <- NA                     # undo fill beyond 5 s
  f
}
dat[, c("EDA","HR","TEMP") := lapply(.SD, fill5), by = session, .SDcols = c("EDA","HR","TEMP")]

rsd <- function(x, n) sqrt(pmax(frollmean(x^2, n, na.rm = TRUE) - frollmean(x, n, na.rm = TRUE)^2, 0))
dat[, `:=`(
  HR_roll60  = frollmean(HR, 60, na.rm = TRUE),    # 1) smoothed HR (1 min)
  HR_sd60    = rsd(HR, 60),                        # 2) short-term heart rate fluctuation proxy
  EDA_roll30 = frollmean(EDA, 30, na.rm = TRUE),
  acc_roll60 = frollmean(acc_mag, 60, na.rm = TRUE)
), by = session]
dat[, EDA_phasic := EDA - EDA_roll30]              # 3) phasic-like arousal (deviation from local tonic)
dat[, EDA_slope  := (EDA - shift(EDA, 10)) / 10, by = session]  # 4) EDA rate of change (uS/s)
#dat[, hour := as.integer(format(datetime, "%H"))]
dat[, hour := as.integer(format(datetime, "%H", tz = "America/Chicago"))]
dat[, day_part := fcase(hour >= 6 & hour < 12, "Morning", hour >= 12 & hour < 18, "Afternoon",
                        default = "Evening/Night")]  # 5) time-based segment

saveRDS(dat, file.path(OUT, "dat_features.rds"))

#first_nonNA <- function(x) { x <- x[!is.na(x)]; if (length(x)) x[1] else NA_real_ }

first_nonNA <- function(x) { x <- as.numeric(x[!is.na(x)]); if (length(x)) x[1] else NA_real_ }

epoch <- dat[, c(lapply(.SD, mean, na.rm = TRUE),
                 list(stress_level = first_nonNA(stress_level), survey_row = first_nonNA(survey_row),
                      day_part = day_part[1])),
             by = .(id, session, min = floor(sec/60)),
             .SDcols = c("EDA","HR","TEMP","acc_mag","HR_roll60","HR_sd60","EDA_phasic","EDA_slope")]
saveRDS(epoch, file.path(OUT, "epoch_1min.rds"))
print(table(epoch$stress_level, useNA = "ifany"))