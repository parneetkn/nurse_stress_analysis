# stats.R - Part 4: Window-level mixed-effects logistic regression.
# H0: mean physiology during a survey window is unrelated to reported stress (level >= 2), after accounting for nurse.
# H1: higher arousal markers (EDA, HR, TEMP, movement, heart rate fluctuation) raise the odds of a high-stress window.
# Why: the label is constant within a survey window, so the window (not the minute) is the unit of analysis.
#      Random intercept for nurse handles repeated windows per person.
source("config.R"); library(data.table); library(lme4); library(performance)
library(broom.mixed); library(ggplot2)
STRESS_CUT <- 2; MIN_EPOCHS <- 3

epoch <- readRDS(file.path(OUT, "epoch_1min.rds"))
x <- c("EDA","HR","TEMP","acc_mag","EDA_phasic","HR_sd60")
m <- epoch[!is.na(survey_row), c(lapply(.SD, mean, na.rm = TRUE),
                                 list(stress_level = stress_level[1], n_min = .N)), by = .(id, survey_row), .SDcols = x]
m <- na.omit(m[n_min >= MIN_EPOCHS])
m[, stress := as.integer(stress_level >= STRESS_CUT)]
print(table(m$stress)); m[, (x) := lapply(.SD, scale), .SDcols = x]

fit <- glmer(stress ~ EDA + HR + TEMP + acc_mag + EDA_phasic + HR_sd60 + (1 | id),
             data = m, family = binomial, control = glmerControl(optimizer = "bobyqa"))
print(summary(fit))
res <- tidy(fit, effects = "fixed", conf.int = TRUE, exponentiate = TRUE)   # odds ratios per 1 SD
print(res); fwrite(res, file.path(OUT, "model_odds_ratios.csv"))

# Assumption checks
print(check_collinearity(fit)); print(r2(fit)); print(icc(fit))
print(binned_residuals(fit))
print(check_outliers(fit))

# Forest plot: plain-language labels, ordered by effect size
lab <- c(EDA = "Skin conductance (EDA)", HR = "Heart rate", TEMP = "Skin temperature",
         acc_mag = "Movement", EDA_phasic = "EDA short-term change",
         HR_sd60 = "Heart rate fluctuation (1-min SD)")
pd <- res[res$term != "(Intercept)", ]
pd$term <- factor(lab[pd$term], levels = lab[pd$term[order(pd$estimate)]])
ggsave(file.path(OUT, "forest_plot.png"),
       ggplot(pd, aes(estimate, term)) + geom_vline(xintercept = 1, linetype = 2, colour = "grey40") +
         geom_pointrange(aes(xmin = conf.low, xmax = conf.high), colour = "#6b46c1", size = 0.7) +
         scale_x_log10(breaks = c(0.5, 0.75, 1, 1.5, 2)) +
         labs(x = "Odds ratio per 1 SD (log scale); 1 = no effect", y = NULL) +
         theme_minimal(base_size = 13), width = 7, height = 4, dpi = 300)