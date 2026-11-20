args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Usage: Rscript journal_stats.R input.csv output_dir")
if (nzchar(Sys.getenv("ENA_R_LIB", ""))) .libPaths(c(Sys.getenv("ENA_R_LIB"), .libPaths()))
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "adjust")

x <- read.csv(args[1], stringsAsFactors = FALSE, colClasses = c(CCDD = "character"))
stopifnot(nrow(x) == 330338, all(x$P1102 == 1))
x$weight <- ifelse(x$ANIO >= 2023, x$FACTOR_PRODUCTOR, x$FACTOR)
x$psu_raw <- ifelse(x$ANIO >= 2023, x$NSEGM, x$CONGLOMERADO)
x$psu <- paste(x$ANIO, x$CCDD, x$psu_raw, sep = "_")
x$stratum <- paste(x$ANIO, x$CCDD, sep = "_")
valid <- x$RESFIN == 1 & is.finite(x$weight) & x$weight > 0 &
  x$P1103 %in% 1:2 & x$P1104_A >= 15 & x$P1104_A <= 100 &
  x$P1105 %in% 1:10 & x$REGION %in% 1:3 &
  !is.na(x$psu_raw) & nzchar(as.character(x$psu_raw)) & !is.na(x$CCDD)
valid[is.na(valid)] <- FALSE
d <- x[valid, ]
stopifnot(nrow(d) == 330134)
d$female <- as.integer(d$P1103 == 2)
d$education <- factor(c("None/initial", "Primary", "Secondary", "Higher")
  [findInterval(d$P1105, c(1, 3, 5, 7))],
  levels = c("None/initial", "Primary", "Secondary", "Higher"))
d$region <- factor(c("Coast", "Sierra", "Selva")[d$REGION],
  levels = c("Coast", "Sierra", "Selva"))
d$age <- d$P1104_A
d$age2 <- (d$age / 10)^2
d$year <- factor(d$ANIO, levels = c(2014:2019, 2021:2025))
d$era <- ifelse(d$ANIO <= 2022, "2014-2022", "2023-2025")
design <- svydesign(ids = ~psu, strata = ~stratum, weights = ~weight,
  data = d, nest = TRUE)
dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
write_stat <- function(formula, name) {
  z <- svyby(~female, formula, design, svymean, vartype = c("se", "ci"),
    level = 0.95, keep.names = FALSE)
  z$female <- 100 * z$female
  z$se <- 100 * z$se
  z$ci_l <- 100 * z$ci_l
  z$ci_u <- 100 * z$ci_u
  write.csv(z, file.path(args[2], name), row.names = FALSE)
}
write_stat(~ANIO, "journal_year_ci.csv")
write_stat(~education, "journal_education_ci.csv")
write_stat(~region, "journal_region_ci.csv")
write_stat(~era, "journal_era_ci.csv")

main <- svyglm(female ~ age + age2 + education + region + year,
  design = design, family = quasibinomial())
holdout <- d[d$ANIO == 2025, ]
w <- holdout$weight / sum(holdout$weight)
standardize <- function(variable, level) {
  nd <- holdout
  nd[[variable]] <- factor(level, levels = levels(d[[variable]]))
  m <- model.matrix(delete.response(terms(main)), nd,
    contrasts.arg = main$contrasts)
  p <- plogis(drop(m %*% coef(main)))
  estimate <- sum(w * p)
  gradient <- colSums(m * (w * p * (1 - p)))
  se <- sqrt(drop(t(gradient) %*% vcov(main) %*% gradient))
  data.frame(variable = variable, level = level, probability = estimate,
    se = se, ci_l = max(0, estimate - 1.96 * se),
    ci_u = min(1, estimate + 1.96 * se))
}
standardized <- do.call(rbind, c(
  lapply(levels(d$education), function(z) standardize("education", z)),
  lapply(levels(d$region), function(z) standardize("region", z))))
write.csv(standardized, file.path(args[2], "journal_standardized_ci.csv"),
  row.names = FALSE)

z <- read.csv(file.path(args[2], "journal_year_ci.csv"))
png(file.path(args[2], "figure1_female_share_ci.png"), width = 2400,
  height = 1450, res = 250)
par(mar = c(5.2, 5.7, 1.2, 1.2), family = "sans")
plot(z$ANIO, z$female, xlim = c(2013.5, 2025.5), ylim = c(26.5, 36.5),
  xaxt = "n", xlab = "ENA survey round", ylab = "Female producers (%)",
  pch = 19, cex = 1.25, col = "#18445E")
axis(1, at = 2014:2025, labels = ifelse(2014:2025 == 2020, "", 2014:2025),
  las = 2)
abline(h = seq(28, 36, 2), col = "#E4E8EB", lty = 3)
arrows(z$ANIO, z$ci_l, z$ANIO, z$ci_u, angle = 90, code = 3,
  length = 0.035, lwd = 1.5, col = "#18445E")
for (a in list(2014:2019, 2021:2022, 2023:2025)) {
  zz <- z[z$ANIO %in% a, ]
  lines(zz$ANIO, zz$female, col = "#18445E", lwd = 2)
}
abline(v = 2022.5, col = "#9A5E20", lty = 2, lwd = 1.5)
text(2020, 27.2, "No round", col = "#5A6066", cex = 0.75, srt = 90)
legend("topleft", legend = c("Weighted estimate and approximate 95% CI",
  "2023 frame change"), pch = c(19, NA), lty = c(1, 2),
  col = c("#18445E", "#9A5E20"), bty = "n", cex = 0.83)
dev.off()

education_ci <- read.csv(file.path(args[2], "journal_education_ci.csv"))
region_ci <- read.csv(file.path(args[2], "journal_region_ci.csv"))
png(file.path(args[2], "figure2_subgroup_shares_ci.png"), width = 2400,
  height = 1200, res = 250)
par(mfrow = c(1, 2), mar = c(4.5, 6.6, 2.4, 0.8), family = "sans")
draw_subgroups <- function(z, labels, heading) {
  yy <- rev(seq_len(nrow(z)))
  plot(z$female, yy, xlim = c(0, 70), ylim = c(0.5, nrow(z) + 0.5),
    xlab = "Female producers (%)", ylab = "", yaxt = "n", pch = 19,
    cex = 1.25, col = "#18445E", main = heading)
  axis(2, at = yy, labels = labels, las = 1, tick = FALSE)
  abline(v = 50, col = "#A7A7A7", lty = 3)
  segments(z$ci_l, yy, z$ci_u, yy, col = "#18445E", lwd = 2)
  segments(z$ci_l, yy - 0.09, z$ci_l, yy + 0.09,
    col = "#18445E", lwd = 2)
  segments(z$ci_u, yy - 0.09, z$ci_u, yy + 0.09,
    col = "#18445E", lwd = 2)
  points(z$female, yy, pch = 19, cex = 1.25, col = "#18445E")
}
draw_subgroups(education_ci,
  c("No/initial", "Primary", "Secondary", "Higher"), "Schooling")
draw_subgroups(region_ci, c("Coast", "Sierra", "Selva"), "Natural region")
dev.off()

train <- subset(design, ANIO < 2025)
prediction_model <- svyglm(female ~ age + age2 + education + region,
  design = train, family = quasibinomial())
pred <- as.numeric(predict(prediction_model, newdata = holdout,
  type = "response"))
ord <- order(pred)
cum_weight <- cumsum(holdout$weight[ord]) / sum(holdout$weight)
decile <- integer(length(pred))
decile[ord] <- pmin(10L, floor(10 * pmax(0, cum_weight - 1e-12)) + 1L)
holdout$decile <- factor(decile, levels = 1:10)
design25 <- svydesign(ids = ~psu, strata = ~stratum, weights = ~weight,
  data = holdout, nest = TRUE)
cal <- svyby(~female, ~decile, design25, svymean, vartype = c("se", "ci"),
  level = 0.95, keep.names = FALSE)
pred_total <- tapply(pred * holdout$weight, holdout$decile, sum)
weight_total <- tapply(holdout$weight, holdout$decile, sum)
cal$predicted <- as.numeric((pred_total / weight_total)[as.character(cal$decile)])
cal$n <- as.integer(table(holdout$decile)[as.character(cal$decile)])
write.csv(cal, file.path(args[2], "journal_2025_calibration.csv"),
  row.names = FALSE)

png(file.path(args[2], "figure3_2025_calibration.png"), width = 1700,
  height = 1500, res = 250)
par(mar = c(5.2, 5.8, 1.2, 1.2), family = "sans")
limits <- c(10, 60)
plot(100 * cal$predicted, 100 * cal$female, xlim = limits, ylim = limits,
  xlab = "Mean predicted female probability (%)",
  ylab = "Observed female share (%)", pch = 19, cex = 1.35,
  col = "#18445E")
abline(0, 1, col = "#9A5E20", lty = 2, lwd = 2)
arrows(100 * cal$predicted, 100 * cal$ci_l,
  100 * cal$predicted, 100 * cal$ci_u, angle = 90, code = 3,
  length = 0.035, lwd = 1.4, col = "#18445E")
points(100 * cal$predicted, 100 * cal$female, pch = 19, cex = 1.35,
  col = "#18445E")
legend("topleft", legend = c("Weighted decile with approximate 95% CI",
  "Perfect calibration"), pch = c(19, NA), lty = c(NA, 2),
  col = c("#18445E", "#9A5E20"), bty = "n", cex = 0.8)
dev.off()
cat("JOURNAL_STATS_COMPLETE", nrow(d), degf(design), "\n")
