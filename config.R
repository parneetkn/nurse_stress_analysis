# config.R - shared paths. Looks for the dataset anywhere under data/.
DATA_DIR <- "data"
dirs        <- list.dirs(DATA_DIR, recursive = TRUE, full.names = TRUE)
STRESS_DIR  <- dirs[basename(dirs) == "Stress_dataset"][1]
SURVEY_XLSX <- list.files(DATA_DIR, "^SurveyResults\\.xlsx$", recursive = TRUE, full.names = TRUE)[1]
if (is.na(STRESS_DIR) || is.na(SURVEY_XLSX))
  stop("Dataset not found under '", DATA_DIR, "/'. Expected a 'Stress_dataset' folder and ",
       "SurveyResults.xlsx. Run from the project root.")
OUT <- "outputs"
dir.create(OUT, showWarnings = FALSE)