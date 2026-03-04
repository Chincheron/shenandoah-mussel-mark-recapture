library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(writexl)
library(scales)

#this script compares the top model for E. complanata and A. varicosa 
# to their respective submodels without a time factor for apparent survival

#pulls path constants
source_python("config/paths.py")
#pull utility functions
util_file = path(ROOT , "src", "util.r")
graph_util_file = path(ROOT , "src", "graph_util.r")
config_folder = path(ROOT, 'config')
source(util_file)
source(graph_util_file)
source(path(config_folder, 'global_figure_config.r'))

#retrieve r object with model outputs from RMARK analysis
results_file = path(path(DATA_INTERIM, 'saved_objects', '05_mark_results.rds'))
results_list = readRDS(results_file)
#remove assemblage level analyses
results_list = results_list[names(results_list) != 'assemblage']

#top model results
analysis_names <- names(results_list)
top_model_results <- purrr::map_dfr(
  analysis_names,
  ~ extract_top_model_results(results_list, .x)
)
#process and add category for model
top_model_results = process_model_results(top_model_results) |> 
  mutate(model = 'top')

#reduced E. complanata results (top model without the time element for survival)
complanata_reduced_model = "Phi.facility.p.time.pent.0.N.dot"
complanata_reduced_analysis = "Elliptio complanata"
complanata_reduced_results = extract_rmark_model_results(results_list, complanata_reduced_analysis, complanata_reduced_model)
# processing
complanata_reduced_results = process_model_results(complanata_reduced_results)
rm(complanata_reduced_model, complanata_reduced_analysis)

#reduced A. varicosa results (top model without the time element for survival)
varicosa_reduced_model = "Phi.facility.p.time.pent.0.N.dot"
varicosa_reduced_analysis = "Alasmidonta varicosa"
varicosa_reduced_results = extract_rmark_model_results(results_list, varicosa_reduced_analysis, varicosa_reduced_model)
# processing
varicosa_reduced_results = process_model_results(varicosa_reduced_results)
rm(varicosa_reduced_model, varicosa_reduced_analysis)

#bind species together and designate as reduced from top model
reduced_models = bind_rows(complanata_reduced_results, varicosa_reduced_results) |> 
  mutate(model = 'reduced_from_top')
rm(complanata_reduced_results, varicosa_reduced_results) 

## expand values Phi for reduced_models to match the number of occasions for the top model
#get list of top model occasions for Phi
top_occasions_phi = top_model_results |> 
  filter(Parameter == 'Phi') |> 
  select(species, facility, Parameter, Occasion)
#get only reduced model rows for Phi
reduced_rows_phi = reduced_models |> 
    filter(Parameter == 'Phi') |> 
    select(-Occasion)
#join so that same value for Phi from reduced model is used for all occasions
reduced_expanded_phi = top_occasions_phi |> 
  left_join(
    reduced_rows_phi,
    by = c('species', 'facility', 'Parameter')
  )
#remove Phi values from original reduced models
reduced_models_no_phi = reduced_models |> 
  filter(Parameter != 'Phi')
rm(top_occasions_phi, reduced_rows_phi, reduced_models)

#bind all data together for plotting
all_models = bind_rows(top_model_results, reduced_expanded_phi, reduced_models_no_phi)
rm(top_model_results, reduced_expanded_phi, reduced_models_no_phi)

#export results to file
model_results_save_folder = path(ROOT, 'temp')
dir.create(model_results_save_folder)
model_results_save_name = 'model_results_comparison.xlsx'
model_results_save_path = path(model_results_save_folder, model_results_save_name)
write_xlsx(all_models, model_results_save_path)

#get global plot config for plotting
global_config = get_global_fig_config()
#pull column mapping for ease of reading functioni later
cm = global_config$column_mapping

## Next set of figures compares the top model estimates to the submodel without time as factor for Phi
### figure config file for this abundance comparison of figures
#NOTE - CIs are only accurate as presented below if all groups are completely broken up
# such that each bar represents a single line in the data. 
# Any other grouping will require variance/CIs to be properly recalculated before plotting
#TODO ? - function to recalculate variance/CIs when summing abundance across groups?
facility_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimated Abundance",
  y_variance_lower = cm$lower_ci,
  y_variance_upper = cm$upper_ci,
  x_factor = cm$sampling_occasion,
  x_factor_label = global_config$labels$Occasion,
  x_order = global_config$category_order$sampling_occasion,
  grouping = cm$model,
  grouping_label = global_config$labels$model,
  grouping_palette = "model_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species, cm$facility),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

build_base_plot(all_models, global_config, facility_plot_config)

survival_fig_override = list(
  parameter = 'Phi',
  y_variance_lower = cm$phi_lower_ci,
  y_variance_upper = cm$phi_upper_ci,
  x_order = global_config$category_order$sampling_occasion_phi
)
build_base_plot(all_models, global_config, facility_plot_config, survival_fig_override)

#table comparing values from figures above
summary_comparison = all_models |> 
  filter(Parameter == "N_derived" | Parameter == 'Phi') |> 
  group_by(Parameter, Occasion, species, facility, model) |> 
  summarize(
    count = n(),
    estimate = sum(estimate)
  )

summary_comparison = summary_comparison |> 
  pivot_wider(
    names_from = model,
    values_from = estimate
  ) |> 
  mutate(
    top_minus_reduced = top - reduced_from_top,
    percent_difference =  (reduced_from_top / top)*100 
  ) 

#export summary table
summary_save_folder = path(ROOT, 'temp')
dir.create(summary_save_folder)
summary_save_name = 'model_comparison_summary.xlsx'
summary_save_path = path(summary_save_folder, summary_save_name)
write_xlsx(summary_comparison, summary_save_path)
