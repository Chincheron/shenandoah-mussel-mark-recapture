# =============================================================================
# Script: 06_top_model_results.py
#
# Purpose: Explore top model results of MARK analysis (plotting, etc.). 
#  Includes final data transformation of model results (daily to annual survival
#   combine estimates for facilities, etc.)         
#
# Inputs:
# - 05_mark_results.rds 
#
# Outputs:
# - Pipeline
#   - 06_top_model_processed_results.rds (Processed results of just the top model
#       for each analysis)
# - Data:
#   - 06_top_model_results.xlsx
#   - 06_top_model_processed_results.rds
# - Results
#   - Various figures
#   - 
# 
# =============================================================================

# =============================================================================
# 1. Setup 
# =============================================================================

# -----------------------------------------------------------------------------
# Imports and Constants
# -----------------------------------------------------------------------------

library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(writexl)
library(scales)

# -----------------------------------------------------------------------------
# Pulls path constants and config files
# -----------------------------------------------------------------------------

global_paths = import("config.paths", convert = TRUE) 

config_folder = path(global_paths$ROOT, 'config')
source(path(config_folder, 'global_figure_config.r'))

# -----------------------------------------------------------------------------
# Load custom libraries
# -----------------------------------------------------------------------------

# Requires path constants to be loaded first

util_file = path(global_paths$ROOT , "src", "util.r")
graph_util_file = path(global_paths$ROOT , "src", "graph_util.r")
source(util_file)
source(graph_util_file)

# -----------------------------------------------------------------------------
# Paths and import/export directories
# -----------------------------------------------------------------------------

# Set directories
SCRIPT_NAME = '06_top_model_results'
source_folder = path(global_paths$DATA_PIPELINE, '05_mark_analysis')
pipeline_folder = path(global_paths$DATA_PIPELINE, SCRIPT_NAME)
data_save_folder = path(global_paths$DATA_PROCESSED, SCRIPT_NAME)
data_objects_folder = path(global_paths$DATA, 'objects', SCRIPT_NAME)
figure_folder = path(global_paths$RESULTS_FIGURES, SCRIPT_NAME)

# Make directories
dir_create(c(
  pipeline_folder,
  data_save_folder,
  data_objects_folder,
  figure_folder
  )
)

# =============================================================================
# 2. Load and transform MARK results
# =============================================================================

# -----------------------------------------------------------------------------
# Load ALL results from MARK analysis
# ----------------------------------------------------------------------------- 

results_file = path(source_folder, '05_mark_results.rds')
results_list = readRDS(results_file)

# -----------------------------------------------------------------------------
# Extract results from the top model
# -----------------------------------------------------------------------------

analysis_names <- names(results_list)
# Create dataframe with parameter estimates of survival, capture probability, and abundance 
#  from the top model of each analysis
top_model_results <- purrr::map_dfr(
  analysis_names,
  ~ extract_top_model_results(results_list, .x)
)

# Final processing of top model results
# e.g., standardize labels, add initial release numbers, convert daily to annual survival
#   , create estimates for 'combined' facility
top_model_results = process_model_results(top_model_results)

# =============================================================================
# 3. Export top model results 
# =============================================================================

# -----------------------------------------------------------------------------
# Export to data folder 
# ----------------------------------------------------------------------------- 

# Export top model results to file for manual review/use
data_save_path = path(data_save_folder, '06_top_model_results.xlsx')
write_xlsx(top_model_results, data_save_path)

# Export R object for later use
data_objects_path = path(data_objects_folder, '06_top_model_results.rds')
saveRDS(results_list, data_objects_path, ascii = TRUE)

# -----------------------------------------------------------------------------
# Export to pipeline
# -----------------------------------------------------------------------------

# Export top results R object for use in later scripts
file_name = path(pipeline_folder, '06_top_model_processed_results.rds')
saveRDS(results_list, file_name, ascii = TRUE)

# =============================================================================
# 4. Plot top model results
# =============================================================================

# All figures are exported to the specified figure_folder

# Only interested in species level analyses (analyzed separately)
species_results = top_model_results |> 
  filter(mark_analysis_level == 'species')

# -----------------------------------------------------------------------------
# Get global plot variables and settings
# -----------------------------------------------------------------------------

# Specifies settings for visual aspects of all figures
all_plot_config <- get_global_fig_config()
# Pull column mapping for ease of reading function later
cm = all_plot_config$column_mapping

# -----------------------------------------------------------------------------
# Figures grouping results by facility and species
# -----------------------------------------------------------------------------

# Define initial settings for group of figures
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
  save_folder = figure_folder,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

# --- Abundance ---
config_override = list(
  save_file_name = 'Figure_1_abundance_top_model.jpg' 
)
build_base_plot(species_results, all_plot_config, facility_plot_config, config_override)

# --- Abundance as a percentage of initial release ---
config_override = list(
  y_factor = cm$perc_of_initial,
  y_label = 'Percent of Initial Release',
  variance_flag = FALSE, # TODO update function so that variance are not hardcoded but reference config
  save_file_name = 'Figure_2_abundance_percent_of_initial.jpg'
)
config_override$y_factor
build_base_plot(species_results, all_plot_config, facility_plot_config, config_override)

# --- Survival ---
config_override = list(
  parameter = 'Phi',
  y_label = 'Estimated apparent survival',
  x_order = all_plot_config$category_order$sampling_occasion_phi,
  variance_flag = FALSE, #TODO how to annualize variance? see mark book?
  save_file_name = 'Figure_3_survival_top_model.jpg'
)
build_base_plot(species_results, all_plot_config, facility_plot_config, config_override)

