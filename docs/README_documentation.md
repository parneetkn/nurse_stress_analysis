# Nurse stress and wearable signals (R)

Detailed reproducible R pipeline for the Sanius Health Data Analyst technical assessment. It asks whether wrist-worn
Empatica E4 signals (skin conductance, heart rate, skin temperature, movement) can flag the stress levels that
hospital nurses reported. Dataset: Nurse Stress Dataset, Dryad, doi:10.5061/dryad.5hqbzkh6f.


## 1. Headline result
After accounting for which nurse was recording, window-average skin conductance, heart rate, skin temperature,
movement and two derived features did not reliably separate "high stress" (level 2) survey windows from the rest.
All six odds-ratio 95% confidence intervals include 1. Differences between nurses (intraclass correlation about 0.17)
outweighed physiology (marginal R2 about 0.05). A wrist band alone is a weak stress marker; personalised baselines
are worth testing.

## 2. Results at a glance
| Item | Value |
|---|---|
| Nurses / session recordings / recorded time | 15 / 609 / about 1,251 hours |
| Analytical dataset | 4,505,058 nurse-seconds (1 Hz) |
| Seconds carrying a stress label | 356,561 (7.9%) |
| Survey rows: sheet / numeric stress level / distinct / with sensor data | 358 / 245 / 242 / 214 |
| Modelled windows (high stress / not) | 214 (161 / 53) |
| Largest correlation with reported stress | skin temperature, Spearman rho 0.13 |
| Skin conductance (EDA) odds ratio per 1 SD | 1.36 (95% CI 0.89 to 2.06, p = 0.152) |
| Other odds ratios | heart rate 0.78, skin temperature 1.08, movement 0.82, EDA short-term change 0.88, heart rate fluctuation 1.04 (all CIs include 1) |
| Variance explained | marginal R2 0.046, conditional R2 0.211, adjusted ICC 0.172 |

### Visualisations
All figures are saved in the outputs/ folder and committed to the repository, so you can view them without running any code.

## 3. Repository layout
```
nurse_stress_analysis/
  README.md, .gitignore
  config.R               shared paths; finds the dataset anywhere under data/
  run_all.R              runs the whole pipeline and knits the report
  data_loading.R         Part 1  ingestion and integration
  data_quality.R         Part 6  data quality gate and cleaning
  features.R             Part 2  derived features and 1-minute epochs
  correlation.R          Part 3  Spearman heatmap
  stats.R                Part 4  mixed-effects logistic regression
  plots_branded.R        optional Sanius-colour versions of both plots
  00_inspect.R           one-off diagnostic: peek inside one zip and the survey sheet
  01b_clock_check.R      one-off diagnostic: survey-to-sensor clock offset test
  docs/                  documentation PDF and presentation
  data/                  dataset goes here (not committed)
  outputs/               generated files: plots (viewable on GitHub) and model CSV committed; .rds ignored
```

## 4. Requirements
- R 4.3 or later (developed on R 4.4). RStudio is optional; pandoc is needed to knit the report (bundled with RStudio).
- Packages (installed automatically by `run_all.R`): data.table, readxl, ggplot2, lme4, performance, broom.mixed, digest, knitr, rmarkdown.
- About 3 GB of free disk for the dataset and outputs. A full run took about 3 minutes on an Apple M-series laptop, mostly in `data_loading.R`.

## 5. Setup
1. Clone the repository and enter the folder:
   ```bash
   git clone https://github.com/<you>/nurse_stress_analysis.git
   cd nurse_stress_analysis
   ```
2. Download the dataset from https://doi.org/10.5061/dryad.5hqbzkh6f. Unzip `Stress_dataset.zip` into `data/` and put `SurveyResults.xlsx` in `data/`. The layout can be flat or inside the Dryad folder, for example:
   ```
   data/doi_10_5061_dryad_5hqbzkh6f__v20210917/Stress_dataset/<nurse_id>/<nurse_id>_<unix_start>.zip
   data/doi_10_5061_dryad_5hqbzkh6f__v20210917/SurveyResults.xlsx
   ```
   Keep the 609 session zips zipped. `config.R` looks for a `Stress_dataset` folder and `SurveyResults.xlsx` anywhere under `data/`.
3. Open the folder as the R working directory (in RStudio: File > Open Project, or Session > Set Working Directory).
4. Check the data is found:
   ```r
   source("config.R"); STRESS_DIR; SURVEY_XLSX
   length(list.files(STRESS_DIR, "\\.zip$", recursive = TRUE))   # should print 609
   ```

## 6. Run
**Everything in one command** (from the project root):
```r
source("run_all.R")
```
It installs missing packages, runs the six scripts in order (each in its own environment).

## Details of each step in the pipeline 'run_all.R': 

### Step 1: `data_loading.R` (Part 1, ingestion and integration)
Unzips the 609 session files, averages each signal to 1 Hz, merges them on the Unix second, converts survey times from America/Chicago to UTC and attaches each survey's stress level to the sensor seconds inside its window.
```
== data_loading.R
100/609
200/609
...
600/609
Rows before de-dup: 4506559
Rows after de-dup: 4505058

  0   1   2
 46  20 179
Labelled rows: 7.9 %
Survey rows with no matching sensor data: 31 of 245

      0       1       2    <NA>
  67606   24189  264766 4148497
```

### Step 2: `data_quality.R` (Part 6, data quality gate)
Reports missingness, gaps, implausible values, duplicates and scale, then sets implausible readings to missing (not deleted).
```
== data_quality.R

1. Missingness (%)
     EDA    HR  TEMP acc_mag
1:  0.01  0.14  0.05       0

2. Gaps >5 s within session (irregular sampling)
Empty data.table (0 rows and 3 cols): id,n_gaps,longest_min

3. Implausible values
   HR_bad TEMP_bad EDA_bad
1:      0    22202  128973

4. Duplicates (id, sec): 0

5. Scale check (acc_mag in g; ~1 at rest)
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max.    NA's
 0.3905  0.9910  1.0037  1.0237  1.0187  2.8694      28

6. Hours recorded & labelled per nurse
        id hours labelled_pct
 1:     15  72.9          3.7
 2:     5C  99.4          7.6
 ...
15:     F5  69.7          5.9
```
The empty gaps table and the `max(gap)` warning are expected: no gap over 5 s exists inside any session.

### Step 3: `features.R` (Part 2, feature engineering)
Builds the rolling-window features and 1-minute epochs, then prints the epoch counts by stress level.
```
== features.R

    0     1     2  <NA>
 1164   420  4568 69535
```

### Step 4: `correlation.R` (Part 3, correlation heatmap)
Spearman correlation on 1-minute epochs with pairwise deletion. Writes `outputs/heatmap.png`.
```
== correlation.R
               EDA    HR  TEMP acc_mag HR_sd60 EDA_phasic EDA_slope stress_level
EDA           1.00  0.16  0.47    0.17   -0.09      -0.10     -0.10         0.07
HR            0.16  1.00  0.03    0.20    0.36       0.02      0.01        -0.03
TEMP          0.47  0.03  1.00    0.11   -0.25      -0.09     -0.09         0.13
acc_mag       0.17  0.20  0.11    1.00    0.09       0.04      0.04         0.07
HR_sd60      -0.09  0.36 -0.25    0.09    1.00       0.05      0.04        -0.07
EDA_phasic   -0.10  0.02 -0.09    0.04    0.05       1.00      0.91        -0.04
EDA_slope    -0.10  0.01 -0.09    0.04    0.04       0.91      1.00        -0.04
stress_level  0.07 -0.03  0.13    0.07   -0.07      -0.04     -0.04         1.00
```

### Step 5: `stats.R` (Part 4, statistical analysis)
Mixed-effects logistic regression on 214 survey windows with a random intercept for nurse, followed by assumption checks. Writes `outputs/model_odds_ratios.csv` and `outputs/forest_plot.png`.
```
== stats.R

  0   1
 53 161

Random effects:
 Groups Name        Variance Std.Dev.
 id     (Intercept) 0.6855   0.828
Number of obs: 214, groups:  id, 15

Fixed effects:
            Estimate Std. Error z value Pr(>|z|)
(Intercept)  1.27219    0.29651   4.291 1.78e-05 ***
EDA          0.30488    0.21300   1.431    0.152
HR          -0.24632    0.21133  -1.166    0.244
TEMP         0.07969    0.22924   0.348    0.728
acc_mag     -0.19259    0.19806  -0.972    0.331
EDA_phasic  -0.12683    0.24265  -0.523    0.601
HR_sd60      0.04317    0.20537   0.210    0.834

# Odds ratios per 1 SD
  term        estimate std.error statistic   p.value conf.low conf.high
1 (Intercept)    3.57      1.06      4.29  0.0000178    2.00       6.38
2 EDA            1.36      0.289     1.43  0.152        0.894      2.06
3 HR             0.782     0.165    -1.17  0.244        0.517      1.18
4 TEMP           1.08      0.248     0.348 0.728        0.691      1.70
5 acc_mag        0.825     0.163    -0.972 0.331        0.559      1.22
6 EDA_phasic     0.881     0.214    -0.523 0.601        0.547      1.42
7 HR_sd60        1.04      0.214     0.210 0.834        0.698      1.56

# Check for Multicollinearity: maximum VIF 1.45 (Low Correlation)
  Conditional R2: 0.211
     Marginal R2: 0.046
    Adjusted ICC: 0.172
Warning: About 80% of the residuals are inside the error bounds (~95% or higher would be good).
13 outliers detected: cases 4, 30, 33, 37, 84, 106, 112, 119, 133, 144, 179, 181, 202.
```
The `hatvalues` warnings that follow are expected: the hat matrix is not valid for mixed logistic models, so the outlier check is not acted on.


### Step 6: `plots_branded.R` (optional)
Redraws the heatmap and forest plot with plain-language labels and the project colours. It prints nothing; check `outputs/heatmap_branded.png` and `outputs/forest_branded.png` (shown in the Visualisations section above).

### Step 7: `rmarkdown::render("report.Rmd")`
Note: I am excluding this step, as I have already provided a detailed documentation and a report file.

Also,
`00_inspect.R` and `01b_clock_check.R` are diagnostics and are not part of the pipeline. `01b_clock_check.R` was run on survey times assumed to be UTC; re-running it now, on the converted times, should show the best offset as 0.

**How to verify a run.** The console should show: 4,505,058 rows after de-duplication; labelled rows 7.9%; 31 survey rows with no labelled seconds out of 245; the epoch table 1,164 / 420 / 4,568 / 69,535 (levels 0, 1, 2, unlabelled); model counts 53 / 161; EDA odds ratio 1.36; marginal R2 0.046; ICC 0.172.

## 7. Troubleshooting
| Symptom | Fix |
|---|---|
| `Dataset not found under 'data/'` | The `Stress_dataset` folder or `SurveyResults.xlsx` is missing; unzip Stress_dataset.zip into `data/`. Run from the project root. |
| `Run from the project root` | Set the working directory to the project folder. |
| `there is no package called 'digest'` | Run `install.packages("digest")`, then `install.packages("broom.mixed")`. |
| Report fails with "Cannot find the file(s)" | Run `run_all.R` (or `stats.R` and `correlation.R`) first so `outputs/` has the plots and CSV; knit from the project root. |
| Warnings about `hatvalues`, `max(gap)` or "built under R 4.4.3" | Expected and harmless (hat matrix is not valid for mixed logistic models; the gap table is empty by design). |

## 8. Data dictionary: full forms and units
| Name in code | Full name | Unit | Source file | Native rate |
|---|---|---|---|---|
| `EDA` | Electrodermal activity (skin conductance) | microsiemens (uS) | `EDA.csv` | 4 Hz |
| `HR` | Heart rate | beats per minute (bpm) | `HR.csv` | 1 Hz |
| `TEMP` | Skin temperature | degrees Celsius | `TEMP.csv` | 4 Hz |
| `acc_mag` | Accelerometer movement magnitude | g (see A5) | `ACC.csv` (x, y, z) | 32 Hz |
| `stress_level` | Stress level reported by the nurse | 0, 1, 2 (see A12) | `SurveyResults.xlsx` | per survey window |
| `survey_row` | Row index of the survey window (analysis key) | n/a | derived | n/a |
| `BVP`, `IBI`, `tags` | Blood volume pulse, inter-beat interval, button tags | n/a | not used | n/a |

Derived features: `HR_roll60` (heart rate, 60 s rolling mean), `HR_sd60` (heart rate, 60 s rolling standard deviation; a short-term heart rate fluctuation proxy, not clinical heart rate variability), `EDA_roll30` (EDA 30 s rolling mean), `EDA_phasic` (EDA minus `EDA_roll30`), `EDA_slope` (EDA change per second over 10 s), `acc_roll60` (movement 60 s rolling mean), `day_part` (time-of-day segment).

"Nurse E4" is a participant ID that happens to share its name with the Empatica E4 wristband.

## 9. Assumptions register
| ID | Stage | Assumption or decision | Justification | Risk if wrong |
|---|---|---|---|---|
| A1 | Loading | One zip = one recording session. Nurse ID is the filename prefix before `_`. | Folder and file names match the participant IDs in the survey sheet. | Mislabelled nurse; none observed (all 15 IDs matched survey IDs). |
| A2 | Loading | Each CSV: line 1 = Unix start time (UTC seconds), line 2 = sample rate (Hz), then data. Sample `i` is timed `start + (i-1)/rate`. Only the first value of each header line is read. | Matches the file contents inspected (`00_inspect.R`) and the Dryad description. | Time shifts if the device clock drifted. |
| A3 | Loading | Every signal is reduced to 1 Hz by taking the mean of all samples in each whole second. | HR is recorded at 1 Hz, so 1 Hz is the common resolution without inventing HR data. | Loses within-second detail (EDA peaks, fast movement). |
| A4 | Loading | Signals are outer-merged on the Unix second, so no second is dropped. HR starts 10 s after the other files, leaving NA at the start of each session. | The shift is visible in the file headers. | Slightly more missing HR (0.14%). |
| A5 | Loading | Movement = sqrt(x^2 + y^2 + z^2) / 64, in g. Raw E4 accelerometer values are taken to be 1/64 g counts. | Checked empirically: median 1.004 g at rest, range 0.39 to 2.87 g. | Wrong scale would change movement units but not correlations or odds ratios per SD. |
| A6 | Loading | Duplicate (nurse, second) rows from overlapping sessions are dropped, keeping the first row after sorting by nurse and second. 4,506,559 rows became 4,505,058 (1,501 removed). | A second can belong to only one reading. | Mild: the discarded duplicate may differ slightly. |
| A7 | Loading | Unreadable zips are skipped with a console message and do not stop the run. | Prevents one bad file halting the pipeline. | None in practice: all 609 zips found were loaded (609 sessions, no `SKIPPED` messages). |
| A8 | Survey | Only the first Excel sheet is read (358 rows, 20 columns). Stress level is converted to a number; rows that are not numeric are dropped (358 to 245). | The workbook has a single sheet, named "in", covering all 15 IDs. The 113 dropped rows contain the text "na" in the stress-level column; the file does not say why. | The cause of the 113 missing levels is unknown, so nothing is assumed about them. |
| A9 | Survey | Survey times are local hospital time (`America/Chicago`, daylight-saving aware) and are converted to UTC. Sensor clocks are UTC. | First test (survey times treated as UTC): UTC-5 matched best for most nurses (summer) and UTC-6 for 7E, 83 and BG (after the 1 Nov clock change). After converting, the same test finds offset 0 as the best for all 15 nurses (217 surveys overlap sensor data at offset 0, against 163 at +1 h and 157 at -1 h; EG ties at 4 surveys for -2, -1 and 0 h, and offset 0 has the most rows). Labelled data rose from 2% to 7.9% of seconds. | The test is hourly only; sub-hour drift was not tested. |
| A10 | Survey | Excel time cells carry the dummy date 1899-12-31, so only the clock time is used. The date comes from the `date` column. A window that ends before it starts is assumed to cross midnight (end + 1 day). | Visible in the file structure. | Wrong date for any entry typed incorrectly. |
| A11 | Labelling | Every sensor second between a survey's start and end (inclusive) inherits that survey's stress level. Where windows overlap, the survey with the higher row number in the sheet overwrites the other (not the later one in time). | A survey describes the whole window. | Five overlaps exist (6B, 7A, E4, F5 twice; about 3,300 s in total, under 1% of labelled time). Three are exact duplicate rows (7A rows 39 and 52, F5 rows 167 and 169, F5 rows 170 and 171) and the two partial overlaps (6B rows 66 and 67, 240 s; E4 rows 74 and 75, 60 s) have the same stress level in both rows, so no label was contradicted. |
| A12 | Outcome | Stress levels are coded 0, 1, 2 in increasing intensity. "Stressed" = level 2; "not stressed" = levels 0 and 1. | Of 245 numeric rows (242 distinct after removing 3 duplicates): 46 level 0, 19 level 1 and 177 level 2, so level 1 is too small to stand alone. The coding is inferred, not documented in the files we received. | Different coding would reverse or blur the outcome. A level 1 sensitivity run has not been done. |
| A13 | Quality | Implausible readings are set to NA, not deleted, so timing is preserved (see cutoffs below). | Keeps rolling windows aligned. | Over-strict limits drop real data. |
| A14 | Features | Gaps of 5 s or less in EDA, HR and TEMP are forward-filled within a session; longer gaps stay NA. | Short dropouts are unlikely to change the physiology; long ones would invent data. | Minimal: no gaps over 5 s exist within sessions. |
| A15 | Features | Rolling windows are computed within a session and look backwards (trailing). | Windows must not span recording breaks. | First 59 s of each session have no 60 s feature. |
| A16 | Features | `EDA_phasic` is a simple proxy (current EDA minus its trailing 30 s mean), not a formal tonic/phasic decomposition. `HR_sd60` uses the population formula. | Fast, transparent, reproducible. | Cruder than model-based decomposition. |
| A17 | Features | `day_part` uses local (Chicago) hour: Morning 06:00-11:59, Afternoon 12:00-17:59, Evening/Night otherwise, taken from the first second of each epoch. | Standard shift-like segments. | It is computed but not used in the model. |
| A18 | Epochs | A 1-minute epoch is the mean of each signal over `floor(second/60)`, per session. Its label is the first non-missing label in that minute. | Cuts autocorrelation and size. | An epoch can straddle a window boundary. |
| A19 | Modelling | The unit of analysis is the survey window: epochs are averaged per (nurse, survey row), and a window needs at least 3 one-minute epochs (counted whether or not every signal is present). Windows whose averaged value is missing for any predictor are then dropped. | The label is constant within a window, so minutes are not independent observations. | None in practice: all 214 windows with sensor labels have 3 or more epochs (median 16, mean 28.8, maximum 324), so the rule removed nothing. Each window counts once however long it is. |
| A20 | Modelling | Predictors are z-scored across the 214 windows, so odds ratios are per 1 SD. A random intercept for nurse is assumed normal. | Puts predictors on one scale and handles repeated windows per nurse. | Differences between nurses are not separated from within-nurse changes (no within-nurse centring). |
| A21 | Modelling | `EDA_slope` is excluded from the model; `EDA_phasic` is kept. | Spearman rho between them is 0.91. | None for conclusions. |

## 10. Cutoffs and parameters
| Parameter | Value | Where | Basis |
|---|---|---|---|
| Heart rate plausible range | 30 to 220 bpm | `data_quality.R` | Physiological limits; no values fell outside. |
| Skin temperature plausible range | 25 to 42 degrees C | `data_quality.R` | Below 25 suggests off-wrist. 22,202 s removed, all below 25; none above 42, so the upper limit never triggered. |
| EDA plausible range | 0.01 to 60 uS | `data_quality.R` | Below 0.01 is consistent with no skin contact (an explanation not tested). 128,973 s (2.9%) removed, all below 0.01; none above 60 uS (or above 100 uS), so the upper limit never triggered. |
| Gap flagged as irregular | more than 5 s | `data_quality.R` | None found within sessions. |
| Forward-fill limit | 5 s | `features.R` | See A14. |
| Rolling windows | HR mean 60 s, HR SD 60 s, EDA mean 30 s, movement 60 s | `features.R` | See A15. |
| EDA slope lag | 10 s | `features.R` | Short-term change. |
| Epoch length | 60 s | `features.R` | See A18. |
| Daily segments | 06-12, 12-18, otherwise Evening/Night (local time) | `features.R` | See A17. |
| Survey clock | `America/Chicago` to UTC | `data_loading.R` | See A9. |
| Outcome cutoff `STRESS_CUT` | 2 | `stats.R` | See A12. |
| Minimum epochs per window `MIN_EPOCHS` | 3 | `stats.R` | See A19. |
| Correlation | Spearman, pairwise deletion | `correlation.R` | Skewed signals; monotonic relationships. |
| Significance level | 0.05, two-sided Wald z test; no correction for six tests | `stats.R` | Standard default; exploratory. |
| Confidence intervals | 95%, Wald | `stats.R` | `broom.mixed` default. |
| Optimiser | `bobyqa`, Laplace approximation | `stats.R` | Stable convergence. |
| Collinearity check | VIF below 5 acceptable (observed maximum 1.45) | `stats.R` | `performance` default. |
| Residual check | about 95% of binned residuals inside bounds desired (observed 80%) | `stats.R` | `performance` default. |
| Outlier check | Cook's distance 0.9 | `stats.R` | `performance` default; not reliable for mixed logistic models. |

## 11. Hypotheses and statistical decisions
- **H0:** mean physiology during a survey window (EDA, heart rate, skin temperature, movement, EDA short-term change, heart rate fluctuation) is unrelated to whether the window was rated high stress (level 2), after accounting for nurse.
- **H1:** higher arousal markers raise the odds of a high-stress window.
- **Method:** mixed-effects logistic regression (`glmer`, binomial, logit link) with a random intercept per nurse. Chosen because windows are repeated within 15 nurses and the outcome is binary.
- **Rejected first model:** a minute-level model with nested window effects was discarded. The label is constant within a window, so the random effect absorbed the outcome (ICC 1.0, intercept odds ratio of 42 million).
- **Result:** 214 windows (161 high stress, 53 not). No predictor was significant. Skin conductance was largest (odds ratio 1.36 per SD, 95% CI 0.89 to 2.06, p = 0.15). Nurse variance 0.69; marginal R2 0.046; conditional R2 0.211; ICC 0.17. H0 is not rejected for any predictor.
- **Events per variable:** 53 events in the smaller class over six predictors is about 8.8, below the common guide of 10.
- **Not done:** level 1 sensitivity, interactions, within-nurse centring, time-of-day terms, multiplicity correction, EDA upper-limit sensitivity.

## 12. Data quality findings (Part 6)
| Issue | Result | Handling |
|---|---|---|
| Clock mismatch | Survey labels first matched 2% of seconds | Timezone-aware conversion (A9); now 7.9%, and the best offset is 0 h for all 15 nurses. |
| Surveys without sensor data | 28 of 242 distinct windows have no sensor data at all. They cluster by date (for example nurse 15 on 17 July 2020 and seven surveys on 7 July 2020), which points to missing recordings, not clock error. | Reported; excluded from modelling. |
| Duplicate survey rows | 3 exact duplicates (7A rows 39 and 52, F5 rows 167 and 169, F5 rows 170 and 171) | The higher row number is kept in overlaps; no label lost or contradicted. |
| Survey rows with no stress level | 113 of 358 rows contain "na" | Dropped; cause unknown. |
| Missing values | EDA 0.01%, HR 0.14%, TEMP 0.05%, movement 0% | Left as NA. |
| Irregular sampling | No gaps over 5 s within sessions | None needed. |
| Implausible values | HR 0; TEMP 22,202 s (all below 25 C); EDA 128,973 s (all below 0.01 uS) | Set to NA. Upper limits (42 C, 60 uS) never triggered. |
| Duplicate sensor rows | 1,501 overlapping nurse-seconds | Removed. |
| Scaling | Movement median 1.004 g | Converted from raw counts. |
| Sparse labels | 3.7% to 21.4% of each nurse's time labelled | Modelling on labelled windows only. |

**Survey accounting:** 358 rows in the sheet, of which 113 have no stress level, leaving 245 numeric rows. After removing 3 duplicates, 242 distinct windows, of which 28 have no sensor data, leaving 214 modelled windows. Of the 245 rows, 31 had no labelled seconds: the 28 plus the 3 overwritten duplicates.

## 13. Limitations and open items
**Limitations**
- Few labelled windows (214; 53 not high stress) for six predictors, about 8.8 events per predictor; estimates are imprecise.
- About 8% of recorded time is labelled; one label per period, not minute by minute.
- Windows range from 3 to 324 minutes but each counts once, and averaging smooths over long, mixed periods.
- The heatmap weights every one-minute epoch equally, so long windows dominate it; the model weights each window once. The two are not directly comparable.
- Outcome dichotomised at level 2 (A12).
- Cook's distance flagged 13 windows but is unreliable for mixed logistic models; no action taken.
- Observational data: associations only.
- Stressor categories and free-text descriptions were not used.
- Cutoffs in section 10 are analyst choices and were not varied to test sensitivity. The upper limits on temperature and EDA never triggered.

**Resolved by re-running everything from scratch (all outputs reproduced exactly)**
- All 609 session zips loaded. The survey workbook has one sheet. The 113 dropped rows hold "na".
- 31 unmatched surveys = 28 with no sensor data plus 3 overwritten duplicates.
- Clock offset is 0 h for all nurses (no anomaly for EG).



## 14. Data source and reuse
The dataset is not included in this repository, it was obtained from the given dryad repo link.

### Author: Parneet, Nov 11, 2026
