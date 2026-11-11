# data_quality.R - Part 6: Data quality assessment, then cleaning.
# Reports missingness, gaps, implausible values, duplicates, label coverage; then sets implausible
# readings to NA (not deleted, so timing is preserved). Output: outputs/dat_clean.rds
source("config.R"); library(data.table)
dat <- readRDS(file.path(OUT, "dat_raw_1hz.rds"))
sig <- c("EDA","HR","TEMP","acc_mag")

cat("\n1. Missingness (%)\n"); print(dat[, lapply(.SD, function(x) round(mean(is.na(x))*100, 2)), .SDcols = sig])

cat("\n2. Gaps >5 s within session (irregular sampling)\n")
dat[, gap := sec - shift(sec), by = session]
print(dat[gap > 5, .(n_gaps = .N, longest_min = round(max(gap)/60, 1)), by = id][order(-n_gaps)])

cat("\n3. Implausible values\n")
print(dat[, .(HR_bad = sum(HR < 30 | HR > 220, na.rm = TRUE),
              TEMP_bad = sum(TEMP < 25 | TEMP > 42, na.rm = TRUE),
              EDA_bad = sum(EDA < 0.01 | EDA > 60, na.rm = TRUE))])   # EDA<0.01 uS = no skin contact

cat("\n4. Duplicates (id, sec):", sum(duplicated(dat, by = c("id","sec"))), "\n")
cat("\n5. Scale check (acc_mag in g; ~1 at rest)\n"); print(summary(dat$acc_mag))
cat("\n6. Hours recorded & labelled per nurse\n")
print(dat[, .(hours = round(.N/3600, 1), labelled_pct = round(mean(!is.na(stress_level))*100, 1)), by = id][order(id)])

# Handling
dat[HR < 30 | HR > 220, HR := NA]
dat[TEMP < 25 | TEMP > 42, TEMP := NA]
dat[EDA < 0.01 | EDA > 60, EDA := NA]
dat[, gap := NULL]
saveRDS(dat, file.path(OUT, "dat_clean.rds"))