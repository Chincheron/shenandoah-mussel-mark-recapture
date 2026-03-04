library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(writexl)
library(scales)


#pulls path constants
source_python("config/paths.py")
#pull utility functions
util_file = path(ROOT , "src", "util.r")
graph_util_file = path(ROOT , "src", "graph_util.r")
config_folder = path(ROOT, 'config')
source(util_file)
source(graph_util_file)

#retrieve r object with model outputs from RMARK analysis
saved_objects_folder = path(DATA_INTERIM, 'saved_objects')
dir.create(saved_objects_folder)
results_file = path(path(saved_objects_folder, '05_mark_results.rds'))
results_list = readRDS(results_file)

analysis_names <- names(results_list)

top_model_results <- purrr::map_dfr(
  analysis_names,
  ~ extract_top_model_results(results_list, .x)
)

#final processing of top model results
top_model_results = process_model_results(top_model_results)

#export results to file
top_model_results_save_folder = path(ROOT, 'temp')
dir.create(top_model_results_save_folder)
top_model_results_save_name = 'top_model_results_all.xlsx'
top_model_results_save_path = path(top_model_results_save_folder, top_model_results_save_name)
write_xlsx(top_model_results, top_model_results_save_path)

#export top_model_results object for later comparison to other models
file_name = path(saved_objects_folder, '06_top_model_processed_results.rds')
saveRDS(results_list, file_name, ascii = TRUE)

# Plotting figures
## get global plot variables and settings
source(path(config_folder, 'global_figure_config.r'))
all_plot_config <- get_global_fig_config()

#pull column mapping for ease of reading functioni later
cm = all_plot_config$column_mapping

## Figures comparing facility of just the species level analyses
### config file for this group of figures
facility_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimated Abundance",
  y_variance_upper = cm$upper_ci,
  y_variance_lower = cm$lower_ci,
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion,
  grouping = cm$facility,
  grouping_label = all_plot_config$labels$facility,
  grouping_order = c('Combined', 'FMCC', 'Harrison Lake'),
  grouping_palette = "facility_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_folder = figure_export_folder,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

#filter out assemblage analysis
species_results = top_model_results |> 
  filter(mark_analysis_level == 'species')

source(graph_util_file)
# Abundance split by facility
config_override = list(
  save_file_name = 'Figure_1_abundance_top_model.jpg' 
)
build_base_plot(species_results, all_plot_config, facility_plot_config, config_override)

#abundance as percentage of initial release
config_override = list(
  y_factor = cm$perc_of_initial,
  y_label = 'Percent of Initial Release',
  variance_flag = FALSE, # TODO update function so that variancec are not hardcoded but reference config
  save_file_name = 'Figure_2_abundance_percent_of_initial.jpg'
)
config_override$y_factor
build_base_plot(species_results, all_plot_config, facility_plot_config, config_override)

# Survival split by facility
#config overrides
config_override = list(
  parameter = 'Phi',
  y_label = 'Estimated apparent survival',
  x_order = all_plot_config$category_order$sampling_occasion_phi,
  variance_flag = FALSE, #TODO how to annualize variance? see mark book?
  save_file_name = 'Figure_3_survival_top_model.jpg'
)
build_base_plot(species_results, all_plot_config, facility_plot_config, config_override)

