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
source(util_file)

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
#analysis = 'assemblage'
extract_top_model_results = function(results_list, analysis) {

  model_table = results_list[[analysis]]$model.table

  top_model = head(model_table, 1)
  
  #get top model name 
  phi_model = top_model[["Phi"]][1] %>% 
    substring(2, nchar(.)) |> 
    str_to_lower()
  p_model = top_model[["p"]][1] %>% 
    substring(2, nchar(.)) |> 
    str_to_lower()
  
  # assemblage model names include N (because we examined factors for N) so we need to account for when N is in model name
  if ("N" %in% colnames(top_model)) {
    n_model = top_model[["N"]][1] %>% 
      substring(2, nchar(.)) |> 
      str_to_lower()
    top_model_name = paste0("Phi.", phi_model, ".p.", p_model, ".pent.0.N.", n_model)
  } else {
    top_model_name = paste0("Phi.", phi_model, ".p.", p_model, ".pent.0")  
  }

  #Set top model name to pull results from marklist object
  top_model_name = gsub("1", "dot", top_model_name)
  #deal with inconsistent naming of interaction models between row names and model names
  top_model_name = str_replace_all(top_model_name, fixed(' + '), 'plus')
  top_model_name = str_replace_all(top_model_name, fixed(' * '), '.')
  
  # TODO Add here if statement for assemblage lefle analysis
  #extract real results from top model
  real_results = results_list[[analysis]][[top_model_name]]$results$real

  real_df = as.data.frame(real_results) |>
    tibble::rownames_to_column("Parameter") |>
    separate_wider_regex(Parameter, patterns = c(
      Parameter = "^[^ ]+",
      " ",
      Group = ".*",
      " ",
      Occasion = "a[0-9]+ t[0-9]+$"
    ))
  
  #extract derived results from top model
  derived_pop_size_results = results_list[[analysis]][[top_model_name]]$results$derived$`N Population Size`
  occasions = nrow(derived_pop_size_results)
  derived_pop_size_groups = results_list[[analysis]][[top_model_name]]$group.labels
  length_derived_pop_size_groups = length(derived_pop_size_groups)
  number_of_mr_occasions = (occasions / length_derived_pop_size_groups)
  suffixes = c('Release', paste('MR', 1:(number_of_mr_occasions-1)))
  row_names = paste(
    rep(derived_pop_size_groups, each = number_of_mr_occasions),
    "_",
    rep(suffixes, times = length(derived_pop_size_groups))
  )  
  row_names = str_remove(row_names, "Facility")

  derived_df = as.data.frame(derived_pop_size_results) |> 
    mutate(
      Parameter = row_names
    ) |> 
    separate_wider_delim(Parameter, delim = ' _ ', names = c('Group', 'Occasion'), too_many = "merge") |> 
    mutate(Parameter = "N_derived")

return (bind_rows(real_df, derived_df) |> 
    mutate(mark_analysis = analysis)
)
}

analysis_names <- names(results_list)

all_results <- purrr::map_dfr(
  analysis_names,
  ~ extract_top_model_results(results_list, .x)
)

analysis_name = names(results_list)
#analysis_name = 'Alasmidonta varicosa'
for (analysis in analysis_name){
  # analysis = "Alasmidonta varicosa"
  # analysis = "Elliptio complanata"
  results_save_path = path(ROOT, "temp", sprintf("%s_Results", analysis))
  dir.create(results_save_path, recursive = TRUE)
  print( analysis)
  model_table = results_list[[analysis]]$model.table
  #get top model name
  top_model = head(model_table, 1)
  phi_model = top_model[["Phi"]][1]
  phi_model = substring(phi_model, 2, nchar(phi_model))
  phi_model = str_to_lower(phi_model)
  p_model = top_model[["p"]][1]
  p_model = substring(p_model, 2, nchar(p_model))
  p_model = str_to_lower(p_model)
  # assemblage model names include N (because we examined factors for N)
  if ("N" %in% colnames(top_model)) {
    n_model = top_model[["N"]][1]
    n_model = substring(n_model, 2, nchar(n_model))
    n_model = str_to_lower(n_model)
    top_model_name = paste0("Phi.", phi_model, ".p.", p_model, ".pent.0.N.", n_model)
  } else {
    top_model_name = paste0("Phi.", phi_model, ".p.", p_model, ".pent.0")  
  }
  top_model_name = gsub("1", "dot", top_model_name)
  #deal with inconsistent naming of interaction models between row names and model names
  top_model_name = str_replace_all(top_model_name, fixed(' + '), 'plus')
  top_model_name = str_replace_all(top_model_name, fixed(' * '), '.')
  # TODO Add here if statement for assemblage lefle analysis
  #results_list[[species]]$model.table
  #results_list[[analysis]][[top_model_name]]$results$real
  real_results = results_list[[analysis]][[top_model_name]]$results$real
  real_results_export = cbind(
    Parameter = rownames(real_results)
    ,real_results
  )

  #TODO convert daily to annual apparent survial



  #None of derived results are labeled, which would be helpful
  #TODO add labels based on group_labels/number and number of estimates
  derived_pop_size_results = results_list[[analysis]][[top_model_name]]$results$derived$`N Population Size`
  occasions = nrow(derived_pop_size_results)
  derived_pop_size_groups = results_list[[analysis]][[top_model_name]]$group.labels
  length_derived_pop_size_groups = length(derived_pop_size_groups)
  number_of_mr_occasions = (occasions / length_derived_pop_size_groups)
  suffixes = c('Release', paste('MR', 1:(number_of_mr_occasions-1)))
  row_names = paste(
    rep(derived_pop_size_groups, each = number_of_mr_occasions),
    rep(suffixes, times = length(derived_pop_size_groups))
  )  
  row_names = str_remove(row_names, "Facility")

  derived_pop_size_results_export = cbind(
    Parameter = row_names
    ,derived_pop_size_results
  )

  #write model results
  write_xlsx(
    list(
      'Model Results' = model_table,
      'Real Results (Top)' = real_results_export,
      'Derived Results (Top)' = derived_pop_size_results_export
    ),
    path = path(results_save_path, sprintf("%s_Mark_results.xlsx", analysis))
  )

####
# Results
####
  #generate group labels for each loop for labeling purposes
  group_label = results_list[[analysis]][[top_model_name]]$group.labels   
  
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
  
}