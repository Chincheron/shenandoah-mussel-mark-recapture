# =============================================================================
# Script: 06a_reduced_model_comparison.py
#
# Purpose: Compares the top model for E. complanata and A. varicosa to their 
#     respective sub-models without a time factor for apparent survival         
#
# Inputs:
# - '05_mark_results.rds'
#
# Outputs:
# - Pipeline
#   - 06a_top_sub_model_results_comparison.rds (R object of estimates, SE, etc. for both models)
# - Results
#   - Various figures comparing top and reduced models
# - Data:
#   - 06a_top_sub_model_results_comparison.xlsx (Estimates, SE, etc. for both models)
#   - 06a_top_sub_model_results_comparison.rds (R object of estimates, SE, etc. for both models)
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

# Config for figures
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
SCRIPT_NAME = '06a_reduced_model_comparison'
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

# --- Remove assemblage level analyses ---
results_list = results_list[names(results_list) != 'assemblage']

# -----------------------------------------------------------------------------
# Extract top model and sub-model results and combine for comparison
# -----------------------------------------------------------------------------

# --- Extract top model results and process --- 
analysis_names <- names(results_list)
top_model_results <- purrr::map_dfr(
  analysis_names,
  ~ extract_top_model_results(results_list, .x)
)
# Final processing of top models 
# Add field to designate which model results are from (top vs. sub)
top_model_results = process_model_results(top_model_results) |> 
  mutate(model = 'top')

# --- Extract reduced model results, process, and combine with top model results ---
# Note that final processing of reduced models is done within this function 
#  (i.e., process_model_results)
reduced_models = load_reduced_models(results_list) 
# Reduced models have only one survival value. For comparison to the time-dependent
#  top model, add identical values of Phi for reduced model to  match the number 
#  of occasions for the top model
reduced_models = expand_phi_intervals(reduced_models)
# Combine top and reduced models for export/plotting
all_models = bind_rows(top_model_results, reduced_models)

# =============================================================================
# 3. Export top model results 
# =============================================================================

# -----------------------------------------------------------------------------
# Export to data folder 
# ----------------------------------------------------------------------------- 
data_save_path = path(data_save_folder, '06a_top_sub_model_results_comparison.xlsx')
write_xlsx(all_models, data_save_path)

# Export R object for later use
data_objects_path = path(data_objects_folder, '06a_top_sub_model_results_comparison.rds')
saveRDS(all_models, data_objects_path)

# -----------------------------------------------------------------------------
# Export to pipeline
# -----------------------------------------------------------------------------

# Export top results R object for use in later scripts
data_objects_path = path(pipeline_folder, '06a_top_sub_model_results_comparison.rds')
saveRDS(all_models, data_objects_path)

# =============================================================================
# 4. Plot top/sub model comparison results
# =============================================================================

# All figures are exported to the specified figure_folder

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

# NOTE - CIs are only accurate as presented below if all groups are completely broken up
#   such that each bar represents a single line in the data. 
#   Any other grouping will require variance/CIs to be properly recalculated before plotting
#TODO ? - function to recalculate variance/CIs when summing abundance across groups?

# Define initial settings for group of figures
facility_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimated Abundance",
  y_variance_lower = cm$lower_ci,
  y_variance_upper = cm$upper_ci,
  y_axis_scale = 'free_full_y',
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion,
  grouping = cm$model,
  grouping_label = all_plot_config$labels$model,
  grouping_order = all_plot_config$category_order$reduced_model_order,
  grouping_palette = "model_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species, cm$facility),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_folder = figure_folder,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

build_base_plot(all_models, all_plot_config, facility_plot_config)

survival_fig_override = list(
  parameter = 'Phi',
  y_variance_lower = cm$phi_lower_ci,
  y_variance_upper = cm$phi_upper_ci,
  x_order = all_plot_config$category_order$sampling_occasion_phi
)
build_base_plot(all_models, all_plot_config, facility_plot_config, survival_fig_override)

# =============================================================================
# Create table comparing values from figures above
# =============================================================================

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
summary_save_name = 'model_comparison_summary.xlsx'
summary_save_path = path(data_save_folder, summary_save_name)
write_xlsx(summary_comparison, summary_save_path)
