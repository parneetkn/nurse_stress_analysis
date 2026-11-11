# run_all.R - run the full pipeline from the project root
stopifnot("Run from the project root (config.R not found)" = file.exists("config.R"))
pk <- c("data.table","readxl","ggplot2","lme4","performance","broom.mixed","digest","knitr","rmarkdown")
miss <- setdiff(pk, rownames(installed.packages()))
if (length(miss)) install.packages(miss, repos = "https://cloud.r-project.org")

steps <- c("data_loading.R","data_quality.R","features.R","correlation.R","stats.R","plots_branded.R")
for (s in steps) {
  message("== ", s, "  ", format(Sys.time(), "%H:%M:%S"))
  source(s, local = new.env()); gc()
}
#rmarkdown::render("report.Rmd")