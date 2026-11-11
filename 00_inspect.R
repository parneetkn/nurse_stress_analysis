# 00_inspect.R - Peek inside one session zip and the survey file.
source("config.R")
pk <- c("data.table","readxl","ggplot2","lme4","lmerTest","performance","broom.mixed")
install.packages(setdiff(pk, rownames(installed.packages())))
library(data.table); library(readxl)

zips <- list.files(STRESS_DIR, "\\.zip$", recursive = TRUE, full.names = TRUE)
cat("Zips:", length(zips), "\n"); print(table(basename(dirname(zips))))

tmp <- tempfile(); dir.create(tmp); unzip(zips[1], exdir = tmp)
fs <- list.files(tmp, recursive = TRUE, full.names = TRUE); print(basename(fs))
for (f in fs[grepl("csv$", fs)]) { cat("\n==", basename(f), "==\n"); cat(readLines(f, n = 4), sep = "\n") }

s <- read_excel(SURVEY_XLSX); str(s); print(head(s, 3))