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
util_file = path(ROOT , "src", "util.r")
source(util_file)

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

groups = c("Facility")
## define models
model_def = list(
#phi
Phi.dot=list(formula=~1),
Phi.time = list(formula=~time),
Phi.facility = list(formula=~Facility),
#p
p.dot=list(formula=~1),
p.time=list(formula=~time),
p.facility = list(formula=~Facility)
#N
#N.dot=list(formula=~1)
#N.facility = list(formula=~Facility)
)
popan_results = run_popan(species_input$`Elliptio complanata`, groups, model_def)

groups = c("Facility", "Species")
## define models
model_def = list(
#phi
Phi.dot=list(formula=~1),
Phi.time = list(formula=~time),
Phi.facility = list(formula=~Facility),
#p
p.dot=list(formula=~1),
p.time=list(formula=~time),
p.facility = list(formula=~Facility)
#N
#N.dot=list(formula=~1)
#N.facility = list(formula=~Facility)
)
run_popan(mark_input, groups, model_def)

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

  