# Nurse stress and wearable signals (R)

Analysis of the Nurse Stress Dataset (Empatica E4): do wrist-worn signals flag
reported stress in hospital nurses? Full write-up: `docs/Nurse_Stress_Analysis_Documentation.pdf`.

## Requirements
- R 4.3 or later, RStudio (optional)
- About 3 GB free disk for the dataset and outputs; the load step takes several minutes

## Setup
1. Clone: `git clone https://github.com/<you>/nurse-stress-analysis.git`
2. Download the dataset from https://doi.org/10.5061/dryad.5hqbzkh6f, unzip
   Stress_dataset.zip into data/ and put SurveyResults.xlsx in data/, so you have
   data/Stress_dataset/<nurse>/<session>.zip and data/SurveyResults.xlsx.
   Keep the session zips zipped. config.R finds them anywhere under data/.
3. Open the project folder in R/RStudio and set it as the working directory.

## Run everything
    source("run_all.R")

## Or run step by step
| Step | Script | Output |
|---|---|---|
| 1 | data_loading.R | outputs/dat_raw_1hz.rds |
| 2 | data_quality.R | outputs/dat_clean.rds |
| 3 | features.R | outputs/epoch_1min.rds |
| 4 | correlation.R | outputs/heatmap.png |
| 5 | stats.R | outputs/model_odds_ratios.csv, forest_plot.png |
| 6 | plots_branded.R (optional) | outputs/*_branded.png |
| 7 | rmarkdown::render("report.Rmd") | report.html |

