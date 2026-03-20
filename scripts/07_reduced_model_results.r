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
object_export_folder = path(RESULTS_OBJECTS, SCRIPT_NAME)
dir_create(object_export_folder)

#retrieve r object with model outputs from RMARK analysis
results_file = path(path(DATA_INTERIM, 'saved_objects', '05_mark_results.rds'))
results_list = readRDS(results_file)
#remove assemblage level analyses
results_list = results_list[names(results_list) != 'assemblage']

reduced_models = load_reduced_models(results_list) 

# expand values Phi for reduced_models to match the number of occasions for the top model
reduced_models = expand_phi_intervals(reduced_models)

#calculate abundance estimates using total release and estimated survival values
#extract Phi values 
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
#get just abundance from main data
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


#export results to file
model_results_save_name = 'reduced_model_data.xlsx'
model_results_save_path = path(data_export_folder, model_results_save_name)
write_xlsx(reduced_models, model_results_save_path)


####
# Tables 
####

#filter out combined facilities
reduced_no_combined = reduced_models |> 
  filter(facility != 'Combined')

#summary table of apparent survival estimates
tbl_survival_summary = reduced_no_combined |> 
  filter(Parameter == 'Phi') |> 
  group_by(species, facility) |> 
  summarize(estimate = mean(estimate))
object_path = path(object_export_folder, 'survival_summary.rds')
saveRDS(tbl_survival_summary, object_path)
object_path = path(table_export_folder, 'survival_summary.csv')
write_csv(tbl_survival_summary, object_path)

#summary table of abundance estimates unique cohort
tbl_abundance_summary = reduced_no_combined |> 
  filter(Parameter == 'N_derived') |> 
  group_by(species, facility, Occasion) |> 
  summarize(estimate = mean(estimate), .groups = 'drop')
tbl_abundance_wide = tbl_abundance_summary |> 
  pivot_wider(
    names_from = 'Occasion',
    values_from = 'estimate'
  ) |> 
  select('species', 'facility', 'Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4') 
occasions = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4')
  pivot_wider(
    names_from = 'facility',
    values_from = all_of(occasions)
  )
save_object = tbl_abundance_wide
object_path = path(object_export_folder, 'abundance_summary.rds')
saveRDS(save_object, object_path)
object_path = path(table_export_folder, 'abundance_summary.csv')
write_csv(save_object, object_path)

#summary table of abundance estimates all cohort
tbl_abundance_all_summary = reduced_no_combined |> 
  filter(Parameter == 'N_derived') |> 
  group_by(species, facility, Occasion) |> 
  summarize(estimate = mean(abundance_total_release), .groups = 'drop')
tbl_abundance_all_wide = tbl_abundance_all_summary |> 
  pivot_wider(
    names_from = 'Occasion',
    values_from = 'estimate',
    names_prefix = 'Occasion '
  )
save_object = tbl_abundance_all_wide
object_path = path(object_export_folder, 'abundance_all_summary.rds')
saveRDS(save_object, object_path)
object_path = path(table_export_folder, 'abundance_all_summary.csv')
write_csv(save_object, object_path)



####
# Plotting figures
####

## get global plot variables and settings
source(path(config_folder, 'global_figure_config.r'))
all_plot_config <- get_global_fig_config()

#pull column mapping for ease of reading functioni later
cm = all_plot_config$column_mapping

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
  y_factor = cm$abundance_release,
  y_label   = "Estimated Abundance of Full Release Cohort",
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
  variance_flag = FALSE
)

# Abundance of entire release cohort faceted by speciesxfacility
config_override = list(
  save_file_name = 'Figure_3_abundance_full_cohort.jpg',
  y_axis_scale = 'free_y'
)
build_base_plot(reduced_no_combined, all_plot_config, abundance_plot_config, config_override)

