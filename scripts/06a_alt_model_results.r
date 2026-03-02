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

#alt E. complanata results (top model without the time element for survival)
complanata_alt_model = "Phi.facility.p.time.pent.0.N.dot"
complanata_alt_analysis = "Elliptio complanata"
complanata_alt_results = extract_rmark_model_results(results_list, complanata_alt_analysis, complanata_alt_model)
# processing
complanata_alt_results = process_model_results(complanata_alt_results)

#alt A. varicosa results (top model without the time element for survival)
varicosa_alt_model = "Phi.facility.p.time.pent.0.N.dot"
varicosa_alt_analysis = "Alasmidonta varicosa"
varicosa_alt_results = extract_rmark_model_results(results_list, varicosa_alt_analysis, varicosa_alt_model)
# processing
varicosa_alt_results = process_model_results(varicosa_alt_results)

#bind species together and designate as reduced from top model
alt_models = bind_rows(complanata_alt_results, varicosa_alt_results) |> 
  mutate(model = 'reduced_from_top')

#bind all data together for plotting
all_models = bind_rows(alt_models, top_model_results)


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

### figure config file for this group of figures
facility_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimated Abundance",
  x_factor = cm$sampling_occasion,
  x_factor_label = global_config$labels$Occasion,
  x_order = global_config$category_order$sampling_occasion,
  grouping = cm$facility,
  grouping_label = global_config$labels$facility,
  grouping_palette = "facility_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species, cm$model),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

build_base_plot(all_models, global_config, facility_plot_config)