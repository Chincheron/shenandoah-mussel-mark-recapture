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
source(util_file)
source(graph_util_file)

#retrieve r object with model outputs from RMARK analysis
results_file = path(path(DATA_INTERIM, 'saved_objects', '05_mark_results.rds'))
results_list = readRDS(results_file)

#number of mussels released by species
release_summary = data.frame(
  Facility = c('FMCC', 'FMCC', 'FMCC', 'FMCC', 'Harrison Lake', 'Harrison Lake'),
  Species = c(
    'Alasmidonta varicosa', 'Elliptio complanata', 'Elliptio fisheriana', 'Lampsilis cardium', 
    'Alasmidonta varicosa', 'Elliptio complanata'
  ),
  releases = c(34, 565, 1, 258, 245, 487)
)

analysis_names <- names(results_list)

all_results <- purrr::map_dfr(
  analysis_names,
  ~ extract_top_model_results(results_list, .x)
)

# add facility and species columns from groups and select only relevant columns
all_results = all_results |> 
  mutate(facility = case_when(
      str_detect(all_results$Group, "FMCC") ~ "FMCC",
      str_detect(all_results$Group, "Harrison") ~ "Harrison Lake",
      .default = "None"
    )
    ,species = case_when(
      str_detect(all_results$Group, "compl") ~ "Elliptio complanata",
      str_detect(all_results$Group, "vari") ~ "Alasmidonta varicosa",
      .default = mark_analysis
    )      
  ) |> 
  mutate(mark_analysis = case_when(
    mark_analysis == 'assemblage' ~ "assemblage",
    .default = 'species'
    )
  ) |> 
  rename(mark_analysis_level = mark_analysis ) |> 
  select(mark_analysis_level, species, facility, Parameter, Occasion, estimate, se, lcl, ucl, fixed)

# sum values to create a 'combined' facility
combined_df = all_results |>
  filter(Parameter == 'N_derived') |> 
  group_by(mark_analysis_level, species, Parameter, Occasion) |> 
  summarise(
    estimate = sum(estimate),
    se = sum(se),
    lcl = sum(lcl),
    ucl = sum(ucl),
    .groups = "drop"
  ) |> 
  mutate(facility = 'Combined')

all_results = bind_rows(all_results, combined_df)

# convert daily survival to annual survival
all_results = all_results |> 
  mutate(
    estimate = case_when(
      Parameter == 'Phi' ~ estimate^365.25,
      .default = estimate
    )
  )

#export results
top_model_results_save_folder = path(ROOT, 'temp')
dir.create(top_model_results_save_folder)
top_model_results_save_name = 'top_model_results_all.xlsx'
top_model_results_save_path = path(top_model_results_save_folder, top_model_results_save_name)
write_xlsx(all_results, top_model_results_save_path)

# Plotting figures
## configure global plot variables and settings
all_plot_config <- list(
  labels = list(
    mark_analysis_level = "Analysis Level",
    Occasion = "Sampling Occasion",
    facility = "Facility",
    species = "Species"
   ),
  palettes = list(
    analysis_level = c(
      assemblage = "steelblue",
      species    = "darkorange"
    ),
    facility_level = c(
      FMCC = "deepskyblue",
      "Harrison Lake" = "darkred",
      "Combined" = "darkorange"
    )
  ),
  column_mapping = list(
    analysis_level = "mark_analysis_level",
    species = "species",
    facility = "facility",
    mark_parameter = "Parameter",
    sampling_occasion = "Occasion",
    parameter_estimate = "estimate",
    standard_error = "se",
    lower_ci = "lcl",
    upper_ci = "ucl"
  ),
  category_order = list(
    sampling_occasion = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4')

  ),
  theme = theme_bw(base_size = 12),
  save_folder = path(RESULTS_FIGURES, 'mark_results')
)
#pull column mapping for ease of reading functioni later
cm = all_plot_config$column_mapping

#set order of 

## Figures comparing assemblage level analysis to species level analysis
### Abundance figures
#### configure abundance level plot variables and settings
abundance_plot_config <- list(
  parameter = "N_derived",
  y_label   = "Estimated Abundance",
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion,
  grouping = cm$analysis_level,
  grouping_label = all_plot_config$labels$mark_analysis_level,
  grouping_palette = "analysis_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = FALSE
)

source(graph_util_file)
#TODO add lcl/ucl for each group before plotting
#TODO automate labels for total released
# assemblage vs. species level analyses abundance
build_base_plot(all_results, all_plot_config, abundance_plot_config, 
  list(title = 'Abundance estimates by species', 
  subtitle = 'Assemblage vs. species level analyses'))

#asseblage vs. species analyses abundance  split by facility
figure_config_facility <- list(
  facet_vars = c(cm$facility, cm$species),
  title = 'Abundance estimates by species and Facility', 
  subtitle = 'Assemblage vs. species level analyses'
)
build_base_plot(all_results, all_plot_config, abundance_plot_config, figure_config_facility)

# assembalge vs. species analyses survival 
figure_config_facility <- list(
  parameter = "Phi",
  y_label = "Estimated apparent survival",
  title = 'Apparent survival estimates by species', 
  subtitle = 'Assemblage vs. species level analyses'
)
build_base_plot(all_results, all_plot_config, abundance_plot_config, figure_config_facility)

#asseblage vs. species analyses survival split by facility
figure_config_facility <- list(
  parameter = "Phi",
  y_label = "Estimated apparent survival",
  facet_vars = c(cm$facility, cm$species),
  title = 'Apparent survival estimates by species and facility', 
  subtitle = 'Assemblage vs. species level analyses'
)
build_base_plot(all_results, all_plot_config, abundance_plot_config, figure_config_facility)