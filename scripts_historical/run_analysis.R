args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) stop("Usage: Rscript run_analysis.R holders_2014_2025.csv output_dir")
infile <- args[1]
outdir <- args[2]
dir.create(outdir, recursive=TRUE, showWarnings=FALSE)
extra_lib <- Sys.getenv("ENA_R_LIB", unset="")
if (nzchar(extra_lib) && dir.exists(extra_lib)) .libPaths(c(extra_lib, .libPaths()))
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu="adjust")

write_out <- function(x, name) write.csv(x, file.path(outdir,name), row.names=FALSE, na="")
x <- read.csv(infile, stringsAsFactors=FALSE, colClasses=c(CCDD="character", CCPP="character", CCDI="character"))
needed <- c("ANIO","CCDD","CONGLOMERADO","NSEGM","P1102","RESFIN","FACTOR","FACTOR_PRODUCTOR","P1103","P1104_A","P1105","REGION")
stopifnot(all(needed %in% names(x)), all(x$P1102==1), nrow(x)==330338)
years <- c(2014:2019,2021:2025)
stopifnot(setequal(unique(x$ANIO), years))
x$weight <- ifelse(x$ANIO >= 2023, x$FACTOR_PRODUCTOR, x$FACTOR)
x$psu_raw <- ifelse(x$ANIO >= 2023, x$NSEGM, x$CONGLOMERADO)
x$psu <- paste(x$ANIO, x$CCDD, x$psu_raw, sep="_")
x$stratum <- paste(x$ANIO, x$CCDD, sep="_")
flow <- data.frame(year=years, holders=as.integer(table(factor(x$ANIO,levels=years))),
                   completed=as.integer(table(factor(x$ANIO[x$RESFIN==1],levels=years))))
flow$invalid_education <- sapply(years,function(y)sum(x$ANIO==y & x$RESFIN==1 & !x$P1105 %in% 1:10))
flow$analysis <- flow$completed-flow$invalid_education
write_out(flow,"sample_flow.csv")

valid <- x$RESFIN==1 & is.finite(x$weight) & x$weight>0 & x$P1103 %in% 1:2 &
  x$P1104_A>=15 & x$P1104_A<=100 & x$P1105 %in% 1:10 & x$REGION %in% 1:3 &
  !is.na(x$psu_raw) & nzchar(as.character(x$psu_raw)) & !is.na(x$CCDD)
valid[is.na(valid)] <- FALSE
d <- x[valid,]
stopifnot(nrow(d)==330134, sum(flow$analysis)==nrow(d))
d$female <- as.integer(d$P1103==2)
d$age <- d$P1104_A
d$age2 <- (d$age/10)^2
d$education <- factor(c("None/initial","Primary","Secondary","Higher")[findInterval(d$P1105,c(1,3,5,7))], levels=c("None/initial","Primary","Secondary","Higher"))
d$region <- factor(c("Coast","Sierra","Selva")[d$REGION], levels=c("Coast","Sierra","Selva"))
d$year <- factor(d$ANIO, levels=years)
design <- svydesign(ids=~psu, strata=~stratum, weights=~weight, data=d, nest=TRUE)

diagnostics <- data.frame(metric=c("source_holders","analysis_holders","weighted_producer_rounds","PSU","strata","design_df","missing_psu_excluded"),
                          value=c(nrow(x),nrow(d),sum(d$weight),length(unique(d$psu)),length(unique(d$stratum)),degf(design),sum(x$RESFIN==1 & (is.na(x$psu_raw) | !nzchar(as.character(x$psu_raw))))))
write_out(diagnostics,"data_checks.csv")

year_stats <- do.call(rbind,lapply(years,function(y){
  z<-d[d$ANIO==y,]; data.frame(year=y,n=nrow(z),weighted_total=sum(z$weight),
    women_weighted=sum(z$weight[z$female==1]),female_pct=100*weighted.mean(z$female,z$weight))
}))
write_out(year_stats,"year_summary.csv")
educ_stats <- do.call(rbind,lapply(levels(d$education),function(g){
  z<-d[d$education==g,]; data.frame(education=g,n=nrow(z),weighted_total=sum(z$weight),
    population_pct=100*sum(z$weight)/sum(d$weight),female_pct=100*weighted.mean(z$female,z$weight))
}))
write_out(educ_stats,"education_summary.csv")
region_stats <- do.call(rbind,lapply(levels(d$region),function(g){
  z<-d[d$region==g,]; data.frame(region=g,n=nrow(z),weighted_total=sum(z$weight),
    population_pct=100*sum(z$weight)/sum(d$weight),female_pct=100*weighted.mean(z$female,z$weight))
}))
write_out(region_stats,"region_summary.csv")
age_stats <- do.call(rbind,lapply(c("All","Men","Women"),function(g){
  z<-if(g=="All") d else d[d$female==as.integer(g=="Women"),];
  data.frame(group=g,n=nrow(z),mean=weighted.mean(z$age,z$weight),
             over65_pct=100*weighted.mean(z$age>=65,z$weight),under30_pct=100*weighted.mean(z$age<30,z$weight))
}))
write_out(age_stats,"age_summary.csv")

main <- svyglm(female ~ age + age2 + education + region + year, design=design, family=quasibinomial())
coef_table <- function(model, name){
  a<-coef(summary(model)); ci<-confint(model); out<-data.frame(model=name,term=rownames(a),estimate=a[,1],se=a[,2],p=a[,4],
    OR=exp(a[,1]),OR_low=exp(ci[,1]),OR_high=exp(ci[,2]),row.names=NULL)
  out
}
model_table <- coef_table(main,"pooled")
write_out(model_table,"model_pooled.csv")

pre <- svyglm(female ~ age + age2 + education + region + year,
              design=subset(design, ANIO<=2022), family=quasibinomial())
post <- svyglm(female ~ age + age2 + education + region + year,
               design=subset(design, ANIO>=2023), family=quasibinomial())
write_out(rbind(coef_table(pre,"2014-2022"),coef_table(post,"2023-2025")),"model_era_sensitivity.csv")

# Out-of-time validation uses a separate model without year indicators.
train <- subset(design, ANIO<2025)
holdout <- d[d$ANIO==2025,]
prediction_model <- svyglm(female ~ age + age2 + education + region, design=train, family=quasibinomial())
pred <- pmin(pmax(as.numeric(predict(prediction_model,newdata=holdout,type="response")),1e-9),1-1e-9)
w <- holdout$weight; y <- holdout$female
baseline <- weighted.mean(d$female[d$ANIO<2025],d$weight[d$ANIO<2025])
weighted_auc <- function(y,p,w){
  ix<-order(p); y<-y[ix];p<-p[ix];w<-w[ix]
  group<-cumsum(c(1,diff(p)!=0))
  neg<-as.numeric(rowsum(w*(1-y),group))
  pos<-as.numeric(rowsum(w*y,group))
  sum(pos*(cumsum(neg)-0.5*neg))/(sum(pos)*sum(neg))
}
validation <- data.frame(holdout_year=2025,n=nrow(holdout),weighted_observed=weighted.mean(y,w),
  weighted_predicted=weighted.mean(pred,w),brier=weighted.mean((y-pred)^2,w),
  baseline_brier=weighted.mean((y-baseline)^2,w),auc=weighted_auc(y,pred,w))
write_out(validation,"temporal_validation.csv")

std_prob <- function(var, values){
  do.call(rbind,lapply(values,function(v){
    nd<-holdout;nd[[var]]<-factor(v,levels=base::levels(d[[var]]))
    data.frame(variable=var,level=v,standardized_probability=weighted.mean(
      predict(main,newdata=nd,type="response"),w))
  }))
}
write_out(rbind(std_prob("education",levels(d$education)),std_prob("region",levels(d$region))),"marginal_probabilities_2025.csv")

png(file.path(outdir,"fig_gender_trend.png"),width=2200,height=1300,res=220)
par(mar=c(5,6,3,1),family="sans")
plot(year_stats$year,year_stats$female_pct,type="b",pch=19,lwd=3,col="#7F1D1D",
     xlab="ENA survey round",ylab="Women among producers (%)",ylim=c(27,35),xaxt="n",main="Women among agricultural producers, 2014-2025")
axis(1,at=years,labels=years,las=2)
abline(v=2020,col="gray60",lty=3)
grid(nx=NA,ny=NULL,col="gray90")
dev.off()
png(file.path(outdir,"fig_education_gender.png"),width=2200,height=1300,res=220)
par(mar=c(8,6,3,1),family="sans")
barplot(educ_stats$female_pct,names.arg=educ_stats$education,col="#17365D",ylim=c(0,70),
        ylab="Women within education category (%)",main="Gender composition by education")
abline(h=50,lty=3,col="gray50")
dev.off()

capture.output(sessionInfo(),file=file.path(outdir,"sessionInfo.txt"))
cat("ANALYSIS_COMPLETE",nrow(d),"PSU",length(unique(d$psu)),"DF",degf(design),"\n")
print(validation)
print(model_table[model_table$term %in% c("educationPrimary","educationSecondary","educationHigher","regionSierra","regionSelva","year2025"),])
