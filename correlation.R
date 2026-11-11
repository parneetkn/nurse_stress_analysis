# correlation.R - Part 3: Spearman correlation heatmap on 1-min epochs.
# Spearman: EDA/ACC are right-skewed with outliers and relationships may be monotonic, not linear.
# NAs: pairwise deletion. Output: outputs/heatmap.png
source("config.R"); library(data.table); library(ggplot2)
epoch <- readRDS(file.path(OUT, "epoch_1min.rds"))
vars <- c("EDA","HR","TEMP","acc_mag","HR_sd60","EDA_phasic","EDA_slope","stress_level")

cm   <- cor(epoch[, ..vars], method = "spearman", use = "pairwise.complete.obs")
long <- as.data.table(as.table(cm)); setnames(long, c("v1","v2","r"))

long[, `:=`(v1 = factor(v1, levels = vars), v2 = factor(v2, levels = rev(vars)))]

p <- ggplot(long, aes(v1, v2, fill = r)) + geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", r)), size = 3.5) +
  scale_fill_gradient2(low = "#2b6cb0", mid = "white", high = "#b83280", limits = c(-1, 1)) +
  labs(title = "Spearman correlation of physiological features", x = NULL, y = NULL, fill = "rho") +
  theme_minimal(base_size = 12) + theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(OUT, "heatmap.png"), p, width = 8, height = 6.5, dpi = 300)
print(round(cm, 2))