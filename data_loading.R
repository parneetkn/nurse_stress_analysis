# data_loading.R - Part 1: Ingestion & integration
# Unzips every session zip, reads EDA/HR/TEMP/ACC, downsamples each to 1 Hz (mean per second),
# outer-merges signals on the 1-second unix timestamp, stacks all sessions, then attaches the
# self-reported stress level by joining on nurse ID and survey start/end window.
# Output: outputs/dat_raw_1hz.rds
source("config.R"); library(data.table); library(readxl)

# Read one E4 csv: line 1 = unix start, line 2 = sample rate (Hz), then data. Returns 1 Hz table.
# ACC is converted to magnitude in g (E4 raw units are 1/64 g).
read_e4 <- function(path, cols) {
  hdr   <- readLines(path, n = 2)
  start <- as.numeric(strsplit(hdr[1], ",")[[1]][1])
  hz    <- as.numeric(strsplit(hdr[2], ",")[[1]][1])
  dt <- fread(path, skip = 2, header = FALSE, col.names = cols)
  dt[, sec := floor(start + (seq_len(.N) - 1) / hz)]
  if (all(c("X","Y","Z") %in% cols)) {
    dt[, acc_mag := sqrt(X^2 + Y^2 + Z^2) / 64]
    dt <- dt[, .(sec, acc_mag)]; cols <- "acc_mag"
  }
  dt[, lapply(.SD, mean, na.rm = TRUE), by = sec, .SDcols = cols]
}

# Load one session zip -> merged 1 Hz table with id and session columns. NULL if unreadable.
load_session <- function(zip_path) {
  tryCatch({
    tmp <- tempfile(); dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE))
    unzip(zip_path, exdir = tmp)
    f <- function(n) list.files(tmp, paste0("^", n, "\\.csv$"), recursive = TRUE, full.names = TRUE)[1]
    parts <- list(read_e4(f("EDA"), "EDA"), read_e4(f("HR"), "HR"),
                  read_e4(f("TEMP"), "TEMP"), read_e4(f("ACC"), c("X","Y","Z")))
    m <- Reduce(function(a, b) merge(a, b, by = "sec", all = TRUE), parts)
    m[, `:=`(id = sub("_.*", "", basename(zip_path)),
             session = tools::file_path_sans_ext(basename(zip_path)))]
  }, error = function(e) { message("SKIPPED ", basename(zip_path), ": ", conditionMessage(e)); NULL })
}

# ---- Survey parsing helpers (handle Excel time/date stored as datetime, number or text)
tod_secs <- function(x) {
  if (inherits(x, "POSIXt")) return(as.numeric(format(x, "%H", tz = "UTC")) * 3600 +
                                      as.numeric(format(x, "%M", tz = "UTC")) * 60 +
                                      as.numeric(format(x, "%S", tz = "UTC")))
  if (is.numeric(x)) return(round((x %% 1) * 86400))
  p <- tstrsplit(as.character(x), ":")
  as.numeric(p[[1]]) * 3600 + as.numeric(p[[2]]) * 60 + ifelse(length(p) > 2, as.numeric(p[[3]]), 0)
}
to_date <- function(x) {
  if (inherits(x, "POSIXt")) as.Date(x, tz = "UTC") else if (inherits(x, "Date")) x
  else if (is.numeric(x)) as.Date(x, origin = "1899-12-30") else as.Date(x, "%m/%d/%y")
}

# ---- 1. Load all sessions
zips <- list.files(STRESS_DIR, "\\.zip$", recursive = TRUE, full.names = TRUE)
dat  <- rbindlist(lapply(seq_along(zips), function(i) {
  if (i %% 100 == 0) message(i, "/", length(zips)); load_session(zips[i]) }), fill = TRUE)
cat("Rows before de-dup:", nrow(dat), "\n")
setorder(dat, id, sec); dat <- unique(dat, by = c("id", "sec"))   # overlapping sessions -> duplicate seconds
cat("Rows after de-dup:", nrow(dat), "\n")

# ---- 2. Survey -> epoch-second windows (survey times are local America/Chicago, converted to UTC)
s <- as.data.table(read_excel(SURVEY_XLSX))
setnames(s, tolower(gsub("[^A-Za-z]+", "_", names(s))))
s[, `:=`(id = trimws(as.character(id)), stress_level = suppressWarnings(as.numeric(stress_level)))]
s[, `:=`(t0 = tod_secs(start_time), t1 = tod_secs(end_time), d = to_date(date))]
#s[, `:=`(start_sec = as.numeric(as.POSIXct(d, tz = "UTC")) + t0,
#        end_sec   = as.numeric(as.POSIXct(d, tz = "UTC")) + t1 + ifelse(t1 < t0, 86400, 0))]  # past-midnight

to_utc <- function(d, secs) {
  secs <- round(secs)
  as.numeric(as.POSIXct(sprintf("%s %02d:%02d:%02d", format(d), secs %/% 3600, (secs %% 3600) %/% 60, secs %% 60),
                        tz = "America/Chicago"))
}
s[, `:=`(start_sec = to_utc(d, t0),
         end_sec   = to_utc(d + (t1 < t0), t1))]

s <- s[!is.na(start_sec) & !is.na(end_sec) & !is.na(stress_level)]
s[, survey_row := .I]
print(s[, .(id, d, start_time, end_time, stress_level)][1:5]); print(table(s$stress_level))

# ---- 3. Attach label by ID + time window
dat[, `:=`(stress_level = NA_real_, survey_row = NA_integer_)]
dat[s, on = .(id, sec >= start_sec, sec <= end_sec),
    `:=`(stress_level = i.stress_level, survey_row = i.survey_row)]
dat[, datetime := as.POSIXct(sec, origin = "1970-01-01", tz = "UTC")]

cat("Labelled rows:", round(mean(!is.na(dat$stress_level)) * 100, 1), "%\n")
cat("Survey rows with no matching sensor data:", s[!survey_row %in% dat$survey_row, .N], "of", nrow(s), "\n")
print(table(dat$stress_level, useNA = "ifany"))

saveRDS(dat, file.path(OUT, "dat_raw_1hz.rds")); saveRDS(s, file.path(OUT, "survey_parsed.rds"))
str(dat)