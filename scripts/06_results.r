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

# standardize occasion labels
all_results = all_results |> 
   mutate(
      Occasion = case_when(
      Parameter == "Phi" & str_detect(Occasion, "a0")   ~ "Interval 1",
      Parameter == "Phi" & str_detect(Occasion, "a246") ~ "Interval 2",
      Parameter == "Phi" & str_detect(Occasion, "a281") ~ "Interval 3",
      Parameter == "Phi" & str_detect(Occasion, "a310") ~ "Interval 4",
      TRUE ~ Occasion
      )
    )

# add initial release numbers of uniquely tagged individuals
#number of mussels released by species
release_summary = data.frame(
  facility = c('FMCC', 'FMCC', 'FMCC', 'FMCC', 'Harrison Lake', 'Harrison Lake'),
  species = c(
    'Alasmidonta varicosa', 'Elliptio complanata', 'Elliptio fisheriana', 'Lampsilis cardium', 
    'Alasmidonta varicosa', 'Elliptio complanata'
  ),
  releases = c(34, 565, 1, 258, 245, 487)
)
all_results = all_results |>
  left_join(
    release_summary |> 
      rename(initial_release = releases),
    by = c('facility', 'species')
  ) |> 
  mutate(
    perc_of_initial = case_when(
      Parameter == "N_derived" ~ estimate / initial_release
    ),
    perc_of_initial_lcl = case_when(
      Parameter == "N_derived" ~ lcl / initial_release
    ),
    perc_of_initial_ucl = case_when(
      Parameter == "N_derived" ~ ucl / initial_release
    )
  )

# sum values to create a 'combined' facility
combined_df = all_results |>
  filter(Parameter == 'N_derived') |> 
  group_by(mark_analysis_level, species, Parameter, Occasion) |> 
  summarise(
    estimate = sum(estimate),
    se = sum(se), # for se, lcl, and ucl, doublecheck calc and also consider only summing this way for n_derived
    lcl = sum(lcl), 
    ucl = sum(ucl),
    initial_release = sum(initial_release),
    .groups = "drop"
  ) |> 
  mutate(
    perc_of_initial = estimate/initial_release ,
    perc_of_initial_lcl = lcl / initial_release, # doublecheck calc of  this
    perc_of_initial_ucl = ucl / initial_release , # doublecheck calc of this 
    facility = 'Combined')

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
    species = "Species",
    perc_of_initial = "Percentage of Initial Release"
   ),
  palettes = list(
    analysis_level = c(
      assemblage = "steelblue",
      species    = "darkorange"
    ),
    facility_level = c(
      FMCC = "deepskyblue",
      "Harrison Lake" = "darkred",
      "Combined" = "springgreen4"
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
    upper_ci = "ucl",
    perc_of_initial = "perc_of_initial",
    perc_of_initial_lcl = "perc_of_initial_lcl",
    perc_of_initial_ucl = "perc_of_initial_ucl"
  ),
  category_order = list(
    sampling_occasion = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4'),
    sampling_occasion_phi = c('Interval 1', 'Interval 2', 'Interval 3', 'Interval 4')
  ),
  theme = theme_bw(base_size = 12),
  save_folder = path(RESULTS_FIGURES, 'mark_results')
)
#pull column mapping for ease of reading functioni later
cm = all_plot_config$column_mapping

## Figures comparing facility of just the species level analyses
### config file for this group of figures
facility_plot_config <- list(
  parameter = "N_derived",
  y_factor = cm$parameter_estimate,
  y_label   = "Estimated Abundance",
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  x_order = all_plot_config$category_order$sampling_occasion,
  grouping = cm$facility,
  grouping_label = all_plot_config$labels$facility,
  grouping_palette = "facility_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species),
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  save_file_name = NULL,
  aggregate_flag = FALSE,
  variance_flag = TRUE
)

#filter out assemblage analysis
species_results = all_results |> 
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

#convert estimates to % of initial release