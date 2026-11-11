# plots_branded.R - Re-draws the heatmap (Part 3) and forest plot (Part 4) in Sanius-style colours.
# Run after correlation.R and stats.R. Inputs: outputs/epoch_1min.rds, outputs/model_odds_ratios.csv
# Outputs: outputs/heatmap_branded.png, outputs/forest_branded.png
# Palette sampled from the Sanius logo in the assessment PDF (verify hex codes against brand guidelines).
source("config.R"); library(data.table); library(ggplot2)
INDIGO <- "#0C0549"; VIOLET <- "#A868E8"; ORCHID <- "#E080C8"; MUTED <- "#5B5780"

lab <- c(EDA = "Skin conductance (EDA)", HR = "Heart rate", TEMP = "Skin temperature",
         acc_mag = "Movement", EDA_phasic = "EDA short-term change", EDA_slope = "EDA rate of change",
         HR_sd60 = "Heart rate fluctuation (1-min SD)", stress_level = "Reported stress level")
theme_sanius <- function() theme_minimal(base_size = 12) +
  theme(text = element_text(colour = INDIGO), axis.text = element_text(colour = INDIGO),
        plot.title = element_text(face = "bold", size = 14), plot.subtitle = element_text(colour = MUTED),
        plot.title.position = "plot",
        panel.grid = element_blank())

# ---- Heatmap (same Spearman method and pairwise deletion as correlation.R)
epoch <- readRDS(file.path(OUT, "epoch_1min.rds"))
vars  <- names(lab)
cm    <- cor(epoch[, ..vars], method = "spearman", use = "pairwise.complete.obs")
long  <- as.data.table(as.table(cm)); setnames(long, c("v1", "v2", "r"))
long[, `:=`(v1 = factor(lab[as.character(v1)], levels = lab), v2 = factor(lab[as.character(v2)], levels = rev(lab)))]
p1 <- ggplot(long, aes(v1, v2, fill = r)) + geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", r), colour = abs(r) > 0.6), size = 3.3, show.legend = FALSE) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = INDIGO)) +
  scale_fill_gradient2(low = ORCHID, mid = "white", high = VIOLET, limits = c(-1, 1), name = "Spearman\ncorrelation") +
  labs(title = "How the wearable signals relate to each other and to reported stress",
       subtitle = "Links to reported stress are weak (all |rho| 0.13 or less)", x = NULL, y = NULL) +
  theme_sanius() + theme(axis.text.x = element_text(angle = 40, hjust = 1))
ggsave(file.path(OUT, "heatmap_branded.png"), p1, width = 9, height = 6.8, dpi = 300)

# ---- Forest plot
res <- fread(file.path(OUT, "model_odds_ratios.csv"))[term != "(Intercept)"]
res[, term := factor(lab[term], levels = lab[res$term[order(res$estimate)]])]
p2 <- ggplot(res, aes(estimate, term)) + geom_vline(xintercept = 1, linetype = 2, colour = MUTED) +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high), colour = VIOLET, size = 0.8) +
  scale_x_log10(breaks = c(0.5, 0.75, 1, 1.5, 2)) +
  labs(title = "Odds of a high-stress period per 1 SD increase",
       subtitle = "Every interval crosses 1, so no measure reliably separates high-stress periods", 
       x = "Odds ratio (log scale); 1 = no effect", y = NULL) + theme_sanius() +
  theme(panel.grid.major.x = element_line(colour = "#E4DDF3"))
ggsave(file.path(OUT, "forest_branded.png"), p2, width = 9, height = 4.4, dpi = 300)