######## 
# Preparing results from the reduced model for presentation in report 
########

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
source(path(config_folder, 'global_figure_config.r'))

#set export directories
SCRIPT_NAME = '07_reduced_model_results'
data_export_folder = path(DATA_PROCESSED, SCRIPT_NAME)
dir_create(data_export_folder)
figure_export_folder = path(RESULTS_FIGURES, SCRIPT_NAME)
dir_create(figure_export_folder)
table_export_folder = path(RESULTS_TABLES, SCRIPT_NAME)
dir_create(table_export_folder)

#retrieve r object with model outputs from RMARK analysis
results_file = path(path(DATA_INTERIM, 'saved_objects', '05_mark_results.rds'))
results_list = readRDS(results_file)
#remove assemblage level analyses
results_list = results_list[names(results_list) != 'assemblage']

reduced_models = load_reduced_models(results_list) 

# expand values Phi for reduced_models to match the number of occasions for the top model
reduced_models = expand_phi_intervals(reduced_models)

#export results to file
model_results_save_name = 'reduced_model_data.xlsx'
model_results_save_path = path(data_export_folder, model_results_save_name)
write_xlsx(reduced_models, model_results_save_path)

####
# Plotting figures
####

## get global plot variables and settings
source(path(config_folder, 'global_figure_config.r'))
all_plot_config <- get_global_fig_config()

#pull column mapping for ease of reading functioni later
cm = all_plot_config$column_mapping

#filter out combined facilities
reduced_no_combined = reduced_models |> 
  filter(facility != 'Combined')

# default config file for group of figures that show Apparent survival
survival_plot_config <- list(
  parameter = "Phi",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimate of Apparent Survival",
  y_variance_upper = cm$phi_upper_ci,
  y_variance_lower = cm$phi_lower_ci,
  y_axis_scale = 'fixed',
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion_phi,
  grouping = cm$facility,
  grouping_label = all_plot_config$labels$facility,
  grouping_order = c('Combined', 'FMCC', 'Harrison Lake'),
  grouping_palette = "facility_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species, cm$facility),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_folder = figure_export_folder,
  save_file_name = 'Figure_1_survival.jpg',
  aggregate_flag = FALSE,
  variance_flag = TRUE
)
# Apparent survival faceted by speciesxfacility
build_base_plot(reduced_no_combined, all_plot_config, survival_plot_config)

# default config file for group of figures that show percentage of release
perc_release_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$perc_of_initial,
  y_label   = "Abundance Estimate as a Percent of Initial Release",
  y_variance_upper = cm$perc_of_initial_ucl,
  y_variance_lower = cm$perc_of_initial_lcl,
  y_axis_scale = 'fixed',
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion,
  grouping = cm$facility,
  grouping_label = all_plot_config$labels$facility,
  grouping_order = c('Combined', 'FMCC', 'Harrison Lake'),
  grouping_palette = "facility_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species, cm$facility),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_folder = figure_export_folder,
  save_file_name = 'Figure_2_abundance_percent_release.jpg',
  aggregate_flag = FALSE,
  variance_flag = TRUE
)
# Abundance as percent of release faceted by speciesxfacility
build_base_plot(reduced_no_combined, all_plot_config, perc_release_plot_config)

# default config file for group of figures that show abundance
abundance_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimated Abundance",
  y_variance_upper = cm$upper_ci,
  y_variance_lower = cm$lower_ci,
  y_axis_scale = 'fixed',
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion,
  grouping = cm$facility,
  grouping_label = all_plot_config$labels$facility,
  grouping_order = c('Combined', 'FMCC', 'Harrison Lake'),
  grouping_palette = "facility_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species, cm$facility),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_folder = figure_export_folder,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

# Abundance of entire release cohort faceted by speciesxfacility
config_override = list(
  save_file_name = 'Figure_3_abundance_four_graph.jpg'
)
build_base_plot(reduced_no_combined, all_plot_config, abundance_plot_config, config_override)
