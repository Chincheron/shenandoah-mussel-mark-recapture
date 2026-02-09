library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)

# config
#TRUE if only want to use the 2024 MR occasions (i.e., ignore release data/timing)
mr_only = FALSE

#pulls path constants
source_python("config/paths.py")

source_folder = DATA_PIPELINE
output_folder = path(RESULTS_TEMP)
source_file = path(source_folder, "04_mark_input.csv")
results_figures = path(RESULTS_FIGURES)

mark_input = read_csv(path(source_file), col_types=cols('ch' = col_character()))

#Assume dead observations were not observed for modeling purposes
mark_input$ch <- str_replace_all(mark_input$ch, 'D', '0') 

# only 2024 data MR occasions
if (mr_only == TRUE) {
  mark_input$ch <- str_sub(mark_input$ch, -4, -1)
  mark_input <- filter(mark_input, ch != '0000')
} else {
  print('f')}


# mark_input = select(mark_input, ch)
#confirm data format
summary(mark_input)
mark_input[1:5,]

#split by species
species_input <- split(mark_input, mark_input$Species)

# TODO - define time interval 
# but may need to explicity split up by speciesxFacility - different release dates
#or not - most seems to be 10/11/23 and one species on 10/19. probably close enough?

#Run Mark Model
#must use with_dir to ensure Mark files are in desired subfolder instead of cluttering up Root folder 
# subsequent data manipulation should use the assigned variable to avoid issues

#####
# POPAN
#####  

## Species setups
## Elliptio complanata
# 569 FMCC and 489 Harrison released on 10/11/23
# 443 FMCC released on 10/17/2024 
#TODO - Analyze 2024 releases separately? Yes, they were not even reelase until just before the 4th sampling occasion
run_popan = function(input_file, analy_groups)
{
mark_input = input_file
#setup common analysis variables
if (mr_only == TRUE) {
  time_interval = c(35, 29, 69)
} else {
  time_interval = c(246,35, 29, 69) #TODO setup formula for calculating for each species automaically}
}
begin_time = 2024 # must be a number and not a string

## define models
#phi
Phi.dot=list(formula=~1)
Phi.time = list(formula=~time)
Phi.facility = list(formula=~Facility)
#p
p.dot=list(formula=~1)
p.time=list(formula=~time)
p.facility = list(formula=~Facility)
#N
#N.dot=list(formula=~1)
#N.facility = list(formula=~Facility)
  
#Create processed dataframe for specific model
popan_process = process.data(mark_input, 
  model = 'POPAN'
  ,begin.time = begin_time
  ,time.intervals = time_interval
  , groups = analy_groups
)
popan_process$group.covariates

#Create design data for analysis
#fix pent to 0 because we are following one release cohort with no new entries or births
pent.0 = list(formula=~1, fixed=0)
popan_ddl = make.design.data(popan_process,
  parameters=list(pent=pent.0)
  #parameters=list(pent=list(pim.type="time")
  #, N=list(pim.type="constant")
  )

#Auto create all possible models to be run based on model list of individual parameters
popan_model_list = create.model.list("POPAN")
popan_results = with_dir(path(ROOT, "temp"), {
    mark.wrapper(popan_model_list, data=popan_process, ddl=popan_ddl
    )
    })

# export for easier exploration of results
with_dir(path(ROOT, "temp"), {
      export.MARK(popan_process, "complanata_test",  popan_results
    )
    })

}


 groups = c("Facility")

run_popan(species_input$`Elliptio complanata`, groups)

groups = c("Facility", "Species")

run_popan(mark_input, groups)



####
# Results
####
summary(popan_results)
popan_results$model.table

popan_results$Phi.time.p.dot$results$real

popan_results$Phi.facility.p.time$results$real

popan_results$Phi.facility.p.time$results$derived$`N Population Size`

popan_results$Phi.dot.p.dot$results$derived

typeof(popan_results$Phi.facility.p.time$results$derived$`N Population Size`)


plot_data <- popan_results$Phi.facility.p.time$results$derived$`N Population Size`
plot_data <- popan_results$Phi.dot.p.time.N.dot$results$derived$`N Population Size`


complanata <- data.frame(
  estimate = plot_data$estimate,
  lcl = plot_data$lcl,
  ucl = plot_data$ucl
)

complanata$label <- seq_len(nrow(complanata))

p <- ggplot(complanata, aes(x = factor(label), y = estimate)) +
  geom_col(fill = "steelblue") +
  geom_errorbar(
    aes(ymin = lcl, ymax = ucl),
    width = 0.2
  ) +
  labs(
    x = "Group",
    y = "Estimate",
    title = "Estimates with Confidence Intervals"
  ) +
  theme_minimal()

ggsave(
  filename = "population_estimates_ci.png",
  plot = p,
  path = results_figures,  # <- change this
  width = 8,
  height = 5,
  dpi = 300
)

#####
# CJS
#####  

cjs_analy = with_dir(path(ROOT, "temp"), {
    mark(mark_input, model = 'CJS',
      groups = c("Species", "Facility")
    )
    })

PIMS(cjs_analy, 'Phi', simplified = FALSE)
PIMS(cjs_analy, 'p')

summary(cjs_analy) #why do groups have same parameter estimates (for POPAN too)

  