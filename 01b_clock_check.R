# 01b_clock_check.R - find survey->sensor clock offset (hours) that matches the most surveys per nurse
source("config.R"); library(data.table)
dat <- readRDS(file.path(OUT, "dat_raw_1hz.rds"))[, .(id, sec)]
s   <- readRDS(file.path(OUT, "survey_parsed.rds"))

res <- rbindlist(lapply(-10:10, function(h) {
  s2 <- copy(s)[, `:=`(a = start_sec + h*3600, b = end_sec + h*3600)]   # sensor_utc = survey_time + h
  x  <- dat[s2, on = .(id, sec >= a, sec <= b), nomatch = 0L, .(id, sr = i.survey_row)]
  if (!nrow(x)) return(NULL)
  x[, .(h = h, rows = .N, surveys = uniqueN(sr)), by = id]
}))

print(res[, .(rows = sum(rows), surveys = sum(surveys)), by = h][order(-surveys)][1:6])
print(res[order(id, -surveys), .SD[1], by = id][, .(id, best_h = h, surveys)]
      [s[, .(total = .N), by = id], on = "id"][order(id)])