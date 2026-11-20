args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript analyse_2025_access.R input.csv output_dir")
local_lib <- Sys.getenv("ENA_R_LIB", "")
if (nzchar(local_lib)) .libPaths(c(local_lib, .libPaths()))
if (dir.exists(file.path(getwd(), "work", "Rlib")))
  .libPaths(c(file.path(getwd(), "work", "Rlib"), .libPaths()))
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "adjust", survey.adjust.domain.lonely = TRUE)
out <- args[2]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
d <- read.csv(args[1], stringsAsFactors = FALSE)
stopifnot(nrow(d) == 38449L, !anyDuplicated(d[c("ANIO", "CCDD", "CCPP", "CCDI", "NSEGM", "UA")]))
stopifnot(all(d$ANIO == 2025), all(d$P1102 == 1), all(d$RESFIN == 1))
stopifnot(all(d$P1103 %in% 1:2), all(d$P1105 %in% 1:10),
          all(d$P1104_A >= 15 & d$P1104_A <= 100),
          all(d$REGION %in% 1:3), all(d$FACTOR_PRODUCTOR > 0))

d$female <- as.integer(d$P1103 == 2)
d$age <- d$P1104_A
d$age2 <- (d$age / 10)^2
d$schooling <- factor(c("None/initial", "Primary", "Secondary", "Higher")
  [findInterval(d$P1105, c(1, 3, 5, 7))],
  levels = c("None/initial", "Primary", "Secondary", "Higher"))
d$region <- factor(c("Coast", "Sierra", "Selva")[d$REGION],
  levels = c("Coast", "Sierra", "Selva"))
d$area_missing <- as.integer(is.na(d$P104_SUP_ha))
d$log_area <- log1p(ifelse(is.na(d$P104_SUP_ha), 0, d$P104_SUP_ha))
d$psu <- interaction(d$CCDD, d$NSEGM, drop = TRUE)
stopifnot(all(is.finite(d$log_area)))

outcomes <- c(training = "P701", assistance = "P704",
              credit_request = "P901", savings_account = "P907")
for (name in names(outcomes)) {
  values <- d[[outcomes[[name]]]]
  stopifnot(all(values %in% 1:2))
  d[[name]] <- as.integer(values == 1)
}
d$credit_approved <- ifelse(d$P901 == 1 & d$P902 %in% 1:2,
                            as.integer(d$P902 == 1), NA_integer_)
stopifnot(sum(!is.na(d$credit_approved)) == sum(d$credit_request))

design <- svydesign(ids = ~psu, strata = ~ESTRATO,
  weights = ~FACTOR_PRODUCTOR, data = d, nest = TRUE)
cat("n", nrow(d), "PSUs", length(unique(d$psu)),
    "strata", length(unique(d$ESTRATO)), "df", degf(design), "\n")

rows <- list()
models <- list()
standardized <- list()
for (name in names(outcomes)) {
  demo_form <- as.formula(paste(name, "~ female + age + age2 + schooling + region"))
  form <- as.formula(paste(name, "~ female + age + age2 + schooling + region + log_area + area_missing"))
  demo_fit <- svyglm(demo_form, design = design, family = quasibinomial())
  fit <- svyglm(form, design = design, family = quasibinomial())
  models[[name]] <- fit
  raw_fit <- svyglm(as.formula(paste(name, "~ female")),
                    design = design, family = gaussian())
  raw_gap <- coef(raw_fit)["female"]
  raw_gap_se <- sqrt(vcov(raw_fit)["female", "female"])
  b <- coef(fit)["female"]
  se <- sqrt(vcov(fit)["female", "female"])
  raw <- svyby(as.formula(paste0("~", name)), ~female, design, svymean,
               vartype = c("se", "ci"), keep.names = FALSE)
  nd0 <- d; nd0$female <- 0L
  nd1 <- d; nd1$female <- 1L
  mm0 <- model.matrix(delete.response(terms(fit)), nd0, contrasts.arg = fit$contrasts)
  mm1 <- model.matrix(delete.response(terms(fit)), nd1, contrasts.arg = fit$contrasts)
  p0 <- plogis(drop(mm0 %*% coef(fit)))
  p1 <- plogis(drop(mm1 %*% coef(fit)))
  w <- d$FACTOR_PRODUCTOR / sum(d$FACTOR_PRODUCTOR)
  e0 <- sum(w * p0); e1 <- sum(w * p1)
  g0 <- colSums(mm0 * (w * p0 * (1 - p0)))
  g1 <- colSums(mm1 * (w * p1 * (1 - p1)))
  gap <- e1 - e0
  gap_se <- sqrt(drop(t(g1-g0) %*% vcov(fit) %*% (g1-g0)))
  demo_mm0 <- model.matrix(delete.response(terms(demo_fit)), nd0,
    contrasts.arg = demo_fit$contrasts)
  demo_mm1 <- model.matrix(delete.response(terms(demo_fit)), nd1,
    contrasts.arg = demo_fit$contrasts)
  demo_p0 <- plogis(drop(demo_mm0 %*% coef(demo_fit)))
  demo_p1 <- plogis(drop(demo_mm1 %*% coef(demo_fit)))
  demo_gap <- sum(w * (demo_p1 - demo_p0))
  demo_g0 <- colSums(demo_mm0 * (w * demo_p0 * (1 - demo_p0)))
  demo_g1 <- colSums(demo_mm1 * (w * demo_p1 * (1 - demo_p1)))
  demo_se <- sqrt(drop(t(demo_g1-demo_g0) %*% vcov(demo_fit) %*% (demo_g1-demo_g0)))
  rows[[name]] <- data.frame(outcome = name, n = nrow(d),
    male_raw = raw[[name]][raw$female == 0],
    female_raw = raw[[name]][raw$female == 1],
    male_raw_l = raw$ci_l[raw$female == 0], male_raw_u = raw$ci_u[raw$female == 0],
    female_raw_l = raw$ci_l[raw$female == 1], female_raw_u = raw$ci_u[raw$female == 1],
    raw_gap = raw_gap, raw_gap_l = raw_gap - 1.96 * raw_gap_se,
    raw_gap_u = raw_gap + 1.96 * raw_gap_se,
    male_standardized = e0, female_standardized = e1,
    demographic_gap = demo_gap,
    demographic_gap_l = demo_gap - 1.96 * demo_se,
    demographic_gap_u = demo_gap + 1.96 * demo_se,
    adjusted_gap = gap, gap_l = gap - 1.96 * gap_se,
    gap_u = gap + 1.96 * gap_se,
    adjusted_or = exp(b), or_l = exp(b - 1.96 * se), or_u = exp(b + 1.96 * se))
  for (sex in 0:1) {
    dd <- subset(design, female == sex)
    z <- svyby(as.formula(paste0("~", name)), ~region, dd, svymean,
               vartype = c("se", "ci"), keep.names = FALSE)
    names(z)[names(z) == name] <- "estimate"
    z$outcome <- name; z$female <- sex
    standardized[[length(standardized) + 1L]] <- z
  }
}

credit_design <- subset(design, credit_request == 1)
credit_fit <- svyglm(credit_approved ~ female + age + age2 + schooling + region + log_area + area_missing,
  design = credit_design, family = quasibinomial())
credit_forms <- list(
  crude = credit_approved ~ female,
  demographics = credit_approved ~ female + age + age2 + schooling + region,
  area = credit_approved ~ female + age + age2 + schooling + region + log_area + area_missing,
  department = credit_approved ~ female + age + age2 + schooling + factor(CCDD) + log_area + area_missing
)
credit_sensitivity <- do.call(rbind, lapply(names(credit_forms), function(spec) {
  m <- svyglm(credit_forms[[spec]], design = credit_design, family = quasibinomial())
  b <- coef(m)["female"]; se <- sqrt(vcov(m)["female", "female"])
  data.frame(specification = spec, n = nobs(m), or = exp(b),
             lower = exp(b - 1.96 * se), upper = exp(b + 1.96 * se))
}))
department_design <- svydesign(ids = ~psu, strata = ~CCDD,
  weights = ~FACTOR_PRODUCTOR, data = d, nest = TRUE)
department_credit <- subset(department_design, credit_request == 1)
department_fit <- svyglm(credit_forms$area, design = department_credit,
                         family = quasibinomial())
db <- coef(department_fit)["female"]
ds <- sqrt(vcov(department_fit)["female", "female"])
credit_sensitivity <- rbind(credit_sensitivity,
  data.frame(specification = "area_department_strata", n = nobs(department_fit),
    or = exp(db), lower = exp(db - 1.96 * ds), upper = exp(db + 1.96 * ds)))
write.csv(credit_sensitivity, file.path(out, "credit_approval_sensitivity.csv"),
          row.names = FALSE)
credit_raw <- svyby(~credit_approved, ~female, credit_design, svymean,
  vartype = c("se", "ci"), keep.names = FALSE)
credit_row <- data.frame(outcome = "credit_approved_among_applicants",
  n = sum(d$credit_request), male_raw = credit_raw$credit_approved[credit_raw$female == 0],
  female_raw = credit_raw$credit_approved[credit_raw$female == 1],
  male_raw_l = credit_raw$ci_l[credit_raw$female == 0],
  male_raw_u = credit_raw$ci_u[credit_raw$female == 0],
  female_raw_l = credit_raw$ci_l[credit_raw$female == 1],
  female_raw_u = credit_raw$ci_u[credit_raw$female == 1],
  raw_gap = NA_real_, raw_gap_l = NA_real_, raw_gap_u = NA_real_,
  male_standardized = NA_real_, female_standardized = NA_real_,
  demographic_gap = NA_real_, demographic_gap_l = NA_real_,
  demographic_gap_u = NA_real_,
  adjusted_gap = NA_real_, gap_l = NA_real_, gap_u = NA_real_,
  adjusted_or = exp(coef(credit_fit)["female"]),
  or_l = exp(coef(credit_fit)["female"] - 1.96 * sqrt(vcov(credit_fit)["female", "female"])),
  or_u = exp(coef(credit_fit)["female"] + 1.96 * sqrt(vcov(credit_fit)["female", "female"])))
rows[["credit_approved"]] <- credit_row
write.csv(do.call(rbind, rows), file.path(out, "access_estimates.csv"), row.names = FALSE)
write.csv(do.call(rbind, standardized), file.path(out, "access_by_region.csv"), row.names = FALSE)

checks <- data.frame(item = c("records", "female_unweighted", "female_weighted",
  "weight_total", "psus", "strata", "design_df", "credit_applicants", "missing_area"),
  value = c(nrow(d), sum(d$female), as.numeric(coef(svymean(~female, design))),
            sum(d$FACTOR_PRODUCTOR), length(unique(d$psu)),
            length(unique(d$ESTRATO)), degf(design), sum(d$credit_request),
            sum(d$area_missing)))
write.csv(checks, file.path(out, "data_checks.csv"), row.names = FALSE)
weighted_median <- function(v, w) {
  keep <- is.finite(v) & is.finite(w) & w > 0
  v <- v[keep]; w <- w[keep]
  idx <- order(v); v <- v[idx]; w <- w[idx]
  v[which(cumsum(w) / sum(w) >= .5)[1L]]
}
composition <- do.call(rbind, lapply(0:1, function(sex) {
  x <- d[d$female == sex, ]; w <- x$FACTOR_PRODUCTOR
  data.frame(female = sex, n = nrow(x), weighted_total = sum(w),
    mean_age = weighted.mean(x$age, w),
    median_area_ha = weighted_median(x$P104_SUP_ha, w),
    none_initial = weighted.mean(x$schooling == "None/initial", w),
    primary = weighted.mean(x$schooling == "Primary", w),
    secondary = weighted.mean(x$schooling == "Secondary", w),
    higher = weighted.mean(x$schooling == "Higher", w),
    sierra = weighted.mean(x$region == "Sierra", w))
}))
write.csv(composition, file.path(out, "sample_composition.csv"), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(out, "sessionInfo.txt"))
print(do.call(rbind, rows), digits = 4)
