args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript make_2025_figures.R results_dir")
out <- args[1]
a <- read.csv(file.path(out, "access_estimates.csv"), stringsAsFactors = FALSE)
r <- read.csv(file.path(out, "access_by_region.csv"), stringsAsFactors = FALSE)
labels <- c(training = "Training", assistance = "Technical assistance",
            credit_request = "Credit application", savings_account = "Savings account")
sel <- a[match(names(labels), a$outcome), ]
col_raw <- "#B45F31"; col_adj <- "#1A5875"; col_female <- "#8B4478"; col_male <- "#1A5875"

png(file.path(out, "figure1_access_gaps.png"), width = 2400, height = 1450, res = 260)
par(mar = c(5.3, 9, 1.8, 1), family = "sans")
yy <- rev(seq_len(nrow(sel)))
plot(100 * sel$raw_gap, yy + 0.14, xlim = c(-8, 8), ylim = c(.5, 4.5),
  yaxt = "n", xlab = "Female minus male prevalence (percentage points)", ylab = "",
  pch = 16, cex = 1.4, col = col_raw)
axis(2, at = yy, labels = unname(labels), las = 1, tick = FALSE)
abline(v = 0, col = "#777777", lty = 2)
segments(100*sel$raw_gap_l, yy+.14, 100*sel$raw_gap_u, yy+.14,
         col = col_raw, lwd = 2.8)
segments(100*sel$gap_l, yy-.14, 100*sel$gap_u, yy-.14,
         col = col_adj, lwd = 2.8)
points(100*sel$adjusted_gap, yy-.14, pch = 17, cex = 1.5, col = col_adj)
legend("bottomright", legend = c("Unadjusted", "Adjusted"),
       pch = c(16, 17), col = c(col_raw, col_adj), bty = "n")
dev.off()

png(file.path(out, "figure2_region_access.png"), width = 2500, height = 1350, res = 260)
par(mfrow = c(1,2), mar = c(5.2, 5.4, 2.8, .6), family = "sans")
for (outcome in c("training", "credit_request")) {
  x <- r[r$outcome == outcome, ]
  x$y <- match(x$region, c("Coast", "Sierra", "Selva")) + ifelse(x$female == 1, -.11, .11)
  plot(100*x$estimate, x$y, xlim = c(0, ifelse(outcome == "training", 22, 31)),
    ylim = c(.5,3.5), yaxt = "n", xlab = "Survey-weighted prevalence (%)", ylab = "",
    main = labels[[outcome]], pch = ifelse(x$female == 1, 17, 16),
    col = ifelse(x$female == 1, col_female, col_male), cex = 1.2)
  axis(2, at = 1:3, labels = c("Coast", "Sierra", "Selva"), las = 1, tick = FALSE)
  segments(100*x$ci_l, x$y, 100*x$ci_u, x$y,
    col = ifelse(x$female == 1, col_female, col_male), lwd = 2)
  points(100*x$estimate, x$y, pch = ifelse(x$female == 1, 17, 16),
    col = ifelse(x$female == 1, col_female, col_male), cex = 1.2)
}
legend("topright", legend = c("Male", "Female"),
  pch = c(16,17), col = c(col_male,col_female), bty = "n", cex = .8)
dev.off()

credit <- a[a$outcome %in% c("credit_request", "credit_approved_among_applicants"), ]
png(file.path(out, "figure3_credit_stages.png"), width = 2250, height = 1150, res = 260)
par(mfrow = c(1,2), mar = c(5.2, 5.8, 2.6, 1.2), family = "sans")
for (i in seq_len(nrow(credit))) {
  x <- credit[i, ]
  vals <- 100*c(x$male_raw, x$female_raw)
  lows <- 100*c(x$male_raw_l, x$female_raw_l)
  highs <- 100*c(x$male_raw_u, x$female_raw_u)
  xrange <- if (x$outcome == "credit_request") c(0, 19) else c(69, 101)
  plot(vals, c(2,1), xlim = xrange, ylim = c(.5, 2.5),
    xlab = "Survey-weighted prevalence (%)", ylab = "", yaxt = "n",
    main = if (x$outcome == "credit_request") "Applied for credit" else "Obtained credit after applying",
    col = c(col_male,col_female), pch = c(16,17), cex = 1.5)
  axis(2, at = c(2,1), labels = c("Male", "Female"), las = 1, tick = FALSE)
  segments(lows, c(2,1), highs, c(2,1), col = c(col_male,col_female), lwd = 2.8)
  points(vals, c(2,1), col = c(col_male,col_female), pch = c(16,17), cex = 1.5)
  text(vals, c(2,1), sprintf("%.1f%%", vals), pos = 3, cex = .8)
}
dev.off()
