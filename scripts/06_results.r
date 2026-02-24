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
  mutate(facility = 'combined')

all_results = bind_rows(all_results, combined_df)

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
    Occasion = "Sampling Occasion"
   ),
  palettes = list(
    analysis_level = c(
      assemblage = "steelblue",
      species    = "darkorange"
    ),
    facility_level = c(
      FMCC = "deepskyblue",
      "Harrison Lake" = "darkred"
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
    lower_ci = "lcI",
    upper_ci = "ucI"
  ),
  theme = theme_bw(base_size = 12)
)
#pull column mapping for ease of reading functioni later
cm = all_plot_config$column_mapping

## Figures comparing assemblage level analysis to species level analysis
### Abundance figures
#### configure abundance level plot variables and settings
abundance_plot_config <- list(
  parameter = "N_derived",
  y_label   = "Estimated Abundance",
  x_factor = cm$sampling_occasion,
  x_factor_label = all_plot_config$labels$Occasion,
  grouping = cm$analysis_level,
  grouping_label = all_plot_config$labels$mark_analysis_level,
  grouping_palette = "analysis_level",
  #NULL if 0 facets, 1 if single. If 2, then first will be rows and second columns
  facet_vars = c(cm$species) 
)

# assemblage vs. species level analyses abundance
build_base_plot(all_results, all_plot_config, abundance_plot_config)

# assembalge vs. species analyses abundance split by facility 
figure_config_facility <- list(
  parameter = "Phi",
  y_label = "Estimated apparent survival"
)
build_base_plot(all_results, all_plot_config, abundance_plot_config, figure_config_facility)

#asseblage vs. species analyses survival split by facility
figure_config_facility <- list(
  parameter = "Phi",
  y_label = "Estimated apparent survival",
  facet_vars = c(cm$facility, cm$species)
)
build_base_plot(all_results, all_plot_config, abundance_plot_config, figure_config_facility)




#### Big picture - aggregated at only the species level for each occasion 

####
# Results
####
  #generate group labels for each loop for labeling purposes
  group_label = 
    results_list[[analysis]][[top_model_name]]$group.labels   
  
  #plot derived population size
  save_file_name = sprintf("%s_abundance_estimate.png", analysis)
  release_label = generate_release_label((group_label), release_summary, analysis)    
  plot_data <- data.frame(
    label = derived_pop_size_results_export$Parameter,
    estimate = derived_pop_size_results_export$estimate,
    lcl = derived_pop_size_results_export$lcl,
    ucl = derived_pop_size_results_export$ucl
  )
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, 'Abundance Estimates (95% CI)', release_label)

  #plot apparent survival 
  save_file_name = sprintf("%s_apparent_survival.png", analysis)
  release_label = generate_release_label((group_label), release_summary, analysis)    
  plot_data <- data.frame(
    label = real_results_export$Parameter,
    estimate = real_results_export$estimate,
    lcl = real_results_export$lcl,
    ucl = real_results_export$ucl
  ) %>% 
    filter(., str_detect(real_results_export$Parameter, 'Phi'))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, 'Apparent Survival (95% CI)', release_label)

  #plot capture probability
  save_file_name = sprintf("%s_capture_probability.png", analysis)
  release_label = generate_release_label((group_label), release_summary, analysis)    
  plot_data <- data.frame(
    label = real_results_export$Parameter,
    estimate = real_results_export$estimate,
    lcl = real_results_export$lcl,
    ucl = real_results_export$ucl
  ) %>% 
    filter(., str_detect(label, 'p'))%>%
    filter(., !str_detect(label, 'pent'))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, 'Capture Probability (95% CI)', release_label)

  ## split by facility
  # FMCC
  facility = 'FMCC'
  save_file_name = sprintf("%s_abundance_estimate_%s.png", analysis, facility)
  release_label = generate_release_label((group_label), release_summary, analysis)    
  graph_title = sprintf('%s Abundance Estimates (95%% CI)', facility) 
  plot_data <- data.frame(
    label = derived_pop_size_results_export$Parameter,
    estimate = derived_pop_size_results_export$estimate,
    lcl = derived_pop_size_results_export$lcl,
    ucl = derived_pop_size_results_export$ucl
  ) %>%
    filter(., str_detect(label, facility))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, graph_title, release_label)

  #plot apparent survival 
  save_file_name = sprintf("%s_apparent_survival_%s.png", analysis, facility)
  release_label = generate_release_label((group_label), release_summary, analysis)
  graph_title = sprintf('%s Apparent Survival (95%% CI)', facility) 
  plot_data <- data.frame(
    label = real_results_export$Parameter,
    estimate = real_results_export$estimate,
    lcl = real_results_export$lcl,
    ucl = real_results_export$ucl
  ) %>% 
    filter(., str_detect(label, 'Phi')) %>%
    filter(., str_detect(label, facility))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, graph_title, release_label)

  #plot capture probability
  save_file_name = sprintf("%s_capture_probability_%s.png", analysis, facility)
  release_label = generate_release_label((group_label), release_summary, analysis)
  graph_title = sprintf('%s Capture Probability (95%% CI)', facility) 
  plot_data <- data.frame(
    label = real_results_export$Parameter,
    estimate = real_results_export$estimate,
    lcl = real_results_export$lcl,
    ucl = real_results_export$ucl
  ) %>% 
    filter(., str_detect(label, 'p'))%>%
    filter(., !str_detect(label, 'pent'))%>%
    filter(., str_detect(label, facility))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, graph_title, release_label)

  # Harrison Lake
  facility = 'Harrison Lake'
  save_file_name = sprintf("%s_abundance_estimate_%s.png", analysis, facility)
  release_label = generate_release_label((group_label), release_summary, analysis)
  graph_title = sprintf('%s Abundance Estimates (95%% CI)', facility) 
  plot_data <- data.frame(
    label = derived_pop_size_results_export$Parameter,
    estimate = derived_pop_size_results_export$estimate,
    lcl = derived_pop_size_results_export$lcl,
    ucl = derived_pop_size_results_export$ucl
  ) %>%
    filter(., str_detect(label, facility))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, graph_title, release_label)

  #plot apparent survival 
  save_file_name = sprintf("%s_apparent_survival_%s.png", analysis, facility)
  release_label = generate_release_label((group_label), release_summary, analysis)
  graph_title = sprintf('%s Apparent Survival (95%% CI)', facility) 
  plot_data <- data.frame(
    label = real_results_export$Parameter,
    estimate = real_results_export$estimate,
    lcl = real_results_export$lcl,
    ucl = real_results_export$ucl
  ) %>% 
    filter(., str_detect(label, 'Phi')) %>%
    filter(., str_detect(label, facility))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, graph_title, release_label)

  #plot capture probability
  save_file_name = sprintf("%s_capture_probability_%s.png", analysis, facility)
  release_label = generate_release_label((group_label), release_summary, analysis)
  graph_title = sprintf('%s Capture Probability (95%% CI)', facility) 
  plot_data <- data.frame(
    label = real_results_export$Parameter,
    estimate = real_results_export$estimate,
    lcl = real_results_export$lcl,
    ucl = real_results_export$ucl
  ) %>% 
    filter(., str_detect(label, 'p'))%>%
    filter(., !str_detect(label, 'pent'))%>%
    filter(., str_detect(label, facility))
  source(util_file)
  graph_mark_results(plot_data, results_save_path, save_file_name, graph_title, release_label)
  
