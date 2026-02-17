library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(writexl)

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
# POPAN Species level analysis
#####  

#define species parameters, variables of interest, and other inputs
# group covariates
groups = c("Facility")
## define models to be examined for each parameter
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
results_list <- list()
species_list = names(species_input)

#Runs set of candidate models for each species
#saves results as a list where each item is a marklist object containing results for a single species
#each marklist object then contains the results for the candidate models run 
# e.g.: results_list$`Alasmidonta varicosa`$Phi.facility.p.time.pent.0 would contain results for the specified model
#to use most RMARK functions for extracting data, you must typically call at the level above (i.e., model level)
for (species in species_list) {
  species_df = species_input[[species]]
  popan_results = run_popan(species_df, groups, model_def, species)
  results_list[[species]] = popan_results
}

results_list$`Alasmidonta varicosa`$Phi.facility.p.time.pent.0$results$derived$`N Population Size`
#####
# POPAN Assemblage level analysis
#####  

groups = c("Facility", "Species")
## define models
model_def = list(
#phi
Phi.dot=list(formula=~1),
Phi.time = list(formula=~time),
Phi.facility = list(formula=~Facility),
Phi.species = list(formula=~Species),
#p
p.dot=list(formula=~1),
p.time=list(formula=~time),
p.facility = list(formula=~Facility),
p.species = list(formula=~Species),
#N
N.dot=list(formula=~1),
N.facility = list(formula=~Facility),
N.species = list(formula=~Species)
)
assemblage_results = run_popan(mark_input, groups, model_def, "Assemblage")
# add to results_list
results_list[["assemblage"]] = assemblage_results

####
#Export model output
####

analysis_name = names(results_list)
#analysis_name = 'assemblage'
for (analysis in analysis_name){
  print( analysis)
  #analysis = "Elliptio fisheriana"
  model_table = results_list[[analysis]]$model.table
  #get top model name
  top_model = head(model_table, 1)
  phi_model = top_model[["Phi"]][1]
  phi_model = substring(phi_model, 2, nchar(phi_model))
  phi_model = str_to_lower(phi_model)
  p_model = top_model[["p"]][1]
  p_model = substring(p_model, 2, nchar(p_model))
  p_model = str_to_lower(p_model)
  # assemblage model names include N (because we examined factors for N)
  if (analysis == 'assemblage') {
    n_model = top_model[["N"]][1]
    n_model = substring(n_model, 2, nchar(n_model))
    n_model = str_to_lower(n_model)
    top_model_name = paste0("Phi.", phi_model, ".p.", p_model, ".pent.0.N.", n_model)
  } else {
    top_model_name = paste0("Phi.", phi_model, ".p.", p_model, ".pent.0")  
  }
 top_model_name = gsub("1", "dot", top_model_name)
  # TODO Add here if statement for assemblage lefle analysis
  
  #results_list[[species]]$model.table
  #results_list[[analysis]][[top_model_name]]$results$real

  real_results = results_list[[analysis]][[top_model_name]]$results$real
  real_results_export = cbind(
    Parameter = rownames(real_results)
    ,real_results
  )
  group_label = results_list[[analysis]][[top_model_name]]$group.labels

  #None of derived results are labeled, which would be helpful
  #TODO add labels based on group_labels/number and number of estimates
  derived_pop_size_results = results_list[[analysis]][[top_model_name]]$results$derived$`N Population Size`
  derived_pop_size_results_export = cbind(
    Parameter = rownames(derived_pop_size_results)
    ,derived_pop_size_results
  )

  #write model results
  write_xlsx(
    list(
      'Model Results' = model_table,
      'Real Results (Top)' = real_results_export,
      'Derived Results (Top)' = derived_pop_size_results_export
    ),
    path = path(ROOT, "temp", sprintf("%s_Mark_results.xlsx", analysis))
  )

  #plot results
  plot_data <- results_list[[analysis]][[top_model_name]]$results$derived$`N Population Size`

  plot_data <- data.frame(
    estimate = plot_data$estimate,
    lcl = plot_data$lcl,
    ucl = plot_data$ucl
  )

  plot_data$label <- seq_len(nrow(plot_data))

  p <- ggplot(plot_data, aes(x = factor(label), y = estimate)) +
    geom_col(fill = "steelblue") +
    geom_errorbar(
      aes(ymin = lcl, ymax = ucl),
      width = 0.2
    ) +
    labs(
      x = "Group",
      y = "Estimate",
      title = "Abundance Estimates with Confidence Intervals"
    ) +
    theme_minimal()

  figure_path = path(ROOT, "temp")
  ggsave(
    filename =  sprintf("%s_abundance_estimate.png", analysis),
    plot = p,
    path = figure_path,  # <- change this
    width = 8,
    height = 5,
    dpi = 300
  )
  
  #plot
  #need to figure out how to get parameter names for these dynamically and then filter to those of interest
  plot_data <- results_list[[analysis]][[top_model_name]]$results$real
  # get.real(popan_results, "Phi")

  plot_data <- data.frame(
    estimate = plot_data$estimate,
    lcl = plot_data$lcl,
    ucl = plot_data$ucl
  )

  plot_data$label <- seq_len(nrow(plot_data))

  p_real <- ggplot(plot_data, aes(x = factor(label), y = estimate)) +
    geom_col(fill = "steelblue") +
    geom_errorbar(
      aes(ymin = lcl, ymax = ucl),
      width = 0.2
    ) +
    labs(
      x = "Group",
      y = "Estimate",
      title = "Real Parameter Estimates with Confidence Intervals"
    ) +
    theme_minimal()

  figure_path = path(ROOT, "temp")
  ggsave(
    filename =  sprintf("%s_real_parameter_estimate.png", analysis),
    plot = p_real,
    path = figure_path,  # <- change this
    width = 8,
    height = 5,
    dpi = 300
  )
  
}

####
# Results
####

plot_data <- popan_results$Phi.facility.p.time$results$derived$`N Population Size`
plot_data <- popan_results$Phi.dot.p.time.N.dot$results$derived$`N Population Size`

plot_data <- results_list$`Alasmidonta varicosa`$Phi.facility.p.time.pent.0$results$derived$`N Population Size`

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
    mark(mark_input, model = 'CJS'
    #, groups = c("Species", "Facility")
    )
    })

Psilist = get.real(cjs_analy, "Phi", se = TRUE)
Psilist$
Psilist$`Group:SpeciesAlasmidonta varicosa.FacilityFMCC`$pim
rownames((Psilist))

PIMS(cjs_analy, 'Phi', simplified = FALSE)
PIMS(cjs_analy, 'p')

summary(cjs_analy) #why do groups have same parameter estimates (for POPAN too)

  