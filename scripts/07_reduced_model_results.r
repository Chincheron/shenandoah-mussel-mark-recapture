# =============================================================================
# Script: 07_reduced_model_results.py
#
# Purpose: Create tables and figures based on the reduced model for inclusion in the report  
#
# Inputs:
# -  05_mark_results.rds
#
# Outputs:
# - Results
#   - Various tables for report
#   - Various figures for report
# - Data:
#   - reduced_model_results_total_cohort.xlsx (Estimates, SE, etc. for reduced model;
#       includes estimates for total cohort (unique, non-unique, and untagged))
#   - Various .csv and .rds files that are equivalent to the tables for the report
# Notes:
# - Also calculates the abundance of the total release cohort (unique, non-unique, 
# and untagged mussels) by applying the survival rates estimated based on just 
# uniquely tagged mussels to the total release cohort
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
SCRIPT_NAME = '07_reduced_model_results'
source_folder = path(global_paths$DATA_PIPELINE, '05_mark_analysis')
pipeline_folder = path(global_paths$DATA_PIPELINE, SCRIPT_NAME)
data_save_folder = path(global_paths$DATA_PROCESSED, SCRIPT_NAME)
data_objects_folder = path(global_paths$DATA, 'objects', SCRIPT_NAME)
figure_folder = path(global_paths$RESULTS_FIGURES, SCRIPT_NAME)
table_folder = path(global_paths$RESULTS_TABLES, SCRIPT_NAME)

# Make directories
dir_create(c(
  pipeline_folder,
  data_save_folder,
  data_objects_folder,
  figure_folder,
  table_folder
  )
)

# =============================================================================
# 2. Load and transform reduced model MARK results
# =============================================================================

# -----------------------------------------------------------------------------
# Load reduced model results from MARK analysis
# ----------------------------------------------------------------------------- 

results_file = path(source_folder, '05_mark_results.rds')
results_list = readRDS(results_file)

# --- Remove assemblage level analyses ---
results_list = results_list[names(results_list) != 'assemblage']

# --- Extract and process reduced model results ---
reduced_models = load_reduced_models(results_list)
# Reduced models have only one survival value. To calculate abundance across all occasions, 
#  add identical values of Phi for reduced model to  match the number 
#  of sampling intervals (i.e., identical survival estimates for interval 1, 2, etc.)
reduced_models = expand_phi_intervals(reduced_models)

# --- Calculate abundance estimates using total release and estimated survival values ---
# Abundance estimates from MARK models apply only to the uniquely tagged release cohort
# Because FMCC released many non-uniquley tagged and untagged mussels, we apply the survival 
#   estimates to the total release cohort to calculate estimated abundance of the entire
#   release cohort (unique, non-unique, and untagged) over all sampling occasions 

# Extract Phi values 
phi_lookup = reduced_models |> 
  filter(Parameter == 'Phi') |> 
  mutate(Occasion = str_replace(Occasion, 'Interval', 'MR')) |> 
  select(species, facility, Occasion, phi_est = estimate)  
time_interval = c('MR 1' = 246, 'MR 2' = 35, 'MR 3' = 29, 'MR 4' = 69)
  phi_lookup = phi_lookup |> 
    mutate(
    interval_days = time_interval[Occasion]
  ) |> 
    mutate(interval_survival = phi_est^(interval_days/365))
# Get just abundance from main data
abundance = reduced_models |> 
  filter(Parameter == 'N_derived')
abundance = abundance |> 
  left_join(phi_lookup,
            by = c("species","facility","Occasion")) |>
  arrange(species, facility, Occasion) |>
  group_by(species, facility) |>
  mutate(
    abundance_total_release = total_release * cumprod(interval_survival)
  ) |>
  ungroup() |> 
  select(facility, species, Occasion, Parameter, interval_survival, abundance_total_release) #TODO join back to main table
reduced_models = reduced_models |> 
  left_join(
    abundance,
    by = c('species', 'facility', 'Occasion', 'Parameter')
  ) |> 
  mutate(abundance_total_release = case_when(
      Occasion == 'Release' ~ total_release,
      .default = abundance_total_release
    )
  )

# =============================================================================
# 3. Export top model results 
# =============================================================================

# -----------------------------------------------------------------------------
# Export to data folder 
# ----------------------------------------------------------------------------- 

model_results_save_name = 'reduced_model_results_total_cohort.xlsx'
model_results_save_path = path(data_save_folder, model_results_save_name)
write_xlsx(reduced_models, model_results_save_path)

# =============================================================================
# 4. Create tables for Report
# =============================================================================

# Filter out combined facilities
reduced_no_combined = reduced_models |> 
  filter(facility != 'Combined')

# -----------------------------------------------------------------------------
# Summary table of apparent survival estimates
# -----------------------------------------------------------------------------

tbl_survival_summary = reduced_no_combined |> 
  filter(Parameter == 'Phi') |> 
  group_by(species, facility) |> 
  summarize(estimate = mean(estimate)) |> 
  mutate(estimate = round(estimate, 2))
tbl_save_object = tbl_survival_summary
# Save R object for future use
object_path = path(data_objects_folder, 'survival_summary.rds')
saveRDS(tbl_save_object, object_path)
# Save csv to data folder
object_path = path(data_save_folder, 'survival_summary.csv')
saveRDS(tbl_save_object, object_path)
# Save csv to results folder (for report)
object_path = path(table_folder, 'survival_summary.csv')
write_csv(tbl_save_object, object_path)

# -----------------------------------------------------------------------------
# Summary table of abundance estimates unique cohort
# -----------------------------------------------------------------------------

tbl_abundance_summary = reduced_no_combined |> 
  filter(Parameter == 'N_derived') |> 
  group_by(species, facility, Occasion) |> 
  summarize(estimate = mean(estimate), .groups = 'drop') |> 
  mutate(estimate = round(estimate, 0))
tbl_abundance_wide = tbl_abundance_summary |> 
  pivot_wider(
    names_from = 'Occasion',
    values_from = 'estimate'
  ) |> 
  select('species', 'facility', 'Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4') 
# Save R object for future use
object_path = path(data_objects_folder, 'abundance_summary.rds')
tbl_save_object = tbl_abundance_summary
saveRDS(tbl_save_object, object_path)
# Save csv to data folder
object_path = path(data_save_folder, 'abundance_summary.csv')
saveRDS(tbl_save_object, object_path)
# Save csv to results folder (for report)
object_path = path(table_folder, 'abundance_summary.csv')
write_csv(tbl_save_object, object_path)

# -----------------------------------------------------------------------------
# Summary table of abundance estimates all cohort
# -----------------------------------------------------------------------------

tbl_abundance_all_summary = reduced_no_combined |> 
  filter(Parameter == 'N_derived') |> 
  group_by(species, facility, Occasion) |> 
  summarize(estimate = mean(abundance_total_release), .groups = 'drop') |> 
  mutate(estimate = round(estimate, 0))
tbl_abundance_all_wide = tbl_abundance_all_summary |> 
  pivot_wider(
    names_from = 'Occasion',
    values_from = 'estimate',
  ) |> 
  select('species', 'facility', 'Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4')
tbl_save_object = tbl_abundance_all_summary
# Save R object for future use
object_path = path(data_objects_folder, 'abundance_all_summary.rds')
saveRDS(tbl_save_object, object_path)
# Save csv to data folder
object_path = path(data_save_folder, 'abundance_all_summary.csv')
saveRDS(tbl_save_object, object_path)
# Save csv to results folder (for report)
object_path = path(table_folder, 'abundance_all_summary.csv')
write_csv(tbl_save_object, object_path)

# =============================================================================
# 5. Create figures for report
# =============================================================================

# -----------------------------------------------------------------------------
# Get global plot variables and settings
# -----------------------------------------------------------------------------

# Specifies settings for visual aspects of all figures
all_plot_config <- get_global_fig_config()
# Pull column mapping for ease of reading function later
cm = all_plot_config$column_mapping

# =============================================================================
# Apparent survival figures
# =============================================================================

# Define initial settings for survival figures
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
  save_folder = figure_folder,
  save_file_name = 'Figure_1_survival.jpg',
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

# --- Apparent survival faceted by speciesxfacility ---
build_base_plot(reduced_no_combined, all_plot_config, survival_plot_config)

# -----------------------------------------------------------------------------
# Abundance figures
# -----------------------------------------------------------------------------

# Define initial settings for abundance figures
abundance_plot_config <- list(
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
  save_folder = figure_folder,
  save_file_name = 'Figure_2_abundance_percent_release.jpg',
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

# --- Abundance as percent of release (unique cohort) faceted by speciesxfacility ---
build_base_plot(reduced_no_combined, all_plot_config, abundance_plot_config)

# --- Abundance of entire release cohort faceted by speciesxfacility ---
config_override = list(
  y_factor = cm$abundance_release,
  y_label   = "Estimated Abundance of Full Release Cohort",
  y_variance_upper = cm$upper_ci,
  y_variance_lower = cm$lower_ci,
  save_file_name = 'Figure_3_abundance_full_cohort.jpg',
  y_axis_scale = 'free_y',
  variance_flag = FALSE
)
build_base_plot(reduced_no_combined, all_plot_config, abundance_plot_config, config_override)

