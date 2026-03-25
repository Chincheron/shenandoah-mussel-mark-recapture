library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(readxl)

run_popan = function(input_file, analy_groups, model_def, analysis_name, save_directory = path(ROOT, 'temp'))
{
  analysis_name = analysis_name

  #create output_directory for mark objects
  save_directory = path(save_directory, analysis_name)
  dir.create(save_directory, recursive = TRUE)

  # Must create a environment then inject parameter definitions and assign other variables to be used (e.g. fixing pent to 0)
  model_env = new.env(parent=environment())
  list2env(model_def, envir = model_env)
  assign("pent.0", list(formula=~1, fixed=0), envir = model_env)
  ls(model_env)

  mark_input = input_file
  #setup common analysis variables
  time_interval = c(246,35, 29, 69) #TODO setup formula for calculating for each species automaically}
 
  begin_time = 2024 # must be a number and not a string


    
  #Create processed dataframe for specific model
  popan_process = process.data(mark_input, 
    model = 'POPAN'
    ,begin.time = begin_time
    ,time.intervals = time_interval
    , groups = analy_groups
  )
  popan_process$group.covariates

  #Create design data for analysis
  #fix pent to 0 because we are following one release cohort with no new entries or births
  #pent.0 = list(formula=~1, fixed=0)
  popan_ddl = evalq(make.design.data(popan_process,
    parameters=list(pent=pent.0)
    #parameters=list(pent=list(pim.type="time")
    #, N=list(pim.type="constant")
    ), envir = model_env)
    head(popan_ddl$pent)

  #Auto create all possible models to be run based on model list of individual parameters
    ls(model_env)
  popan_model_list = evalq(create.model.list("POPAN"), envir = model_env)
  popan_results = evalq(with_dir(save_directory, {
      mark.wrapper(popan_model_list, data=popan_process, ddl=popan_ddl
      )
      })
      , envir = model_env)

  # export for easier exploration of results
  with_dir(save_directory, {
        export.MARK(popan_process, analysis_name,  popan_results
      )
      })
  
  return(popan_results)

}

graph_mark_results = function(plot_data, save_path, save_filename, graph_title, label_released) {  
  
  #force graph order to be same as row order
  plot_data$label <- factor(plot_data$label, levels = plot_data$label)

  p <- ggplot(plot_data, aes(x = factor(label), y = estimate)) +
    geom_col(fill = "steelblue") +
    geom_errorbar(
      aes(ymin = lcl, ymax = ucl),
      width = 0.2
    ) +
    labs(
      x = "Group",
      y = "Estimate",
      title = graph_title
    ) +
    theme_minimal() +
    scale_x_discrete(labels = label_wrap(width = 10)) + # Automatically wraps labels to max 10 characters per line 
    annotate(
      "text",
      x = -Inf,
      y = Inf,
      label = label_released,
      hjust = -0.1,
      vjust = 1.1
    )
  
  ggsave(
    filename =  save_filename,
    plot = p,
    path = save_path,  # <- change this
    width = 8,
    height = 5,
    dpi = 300
  )  

}

generate_release_label = function(group_label, release_summary, analysis) {
  
  release_label = ''
  group_label = group_label %>%
    str_remove(., 'Facility')

  release_label = paste(
     analysis, 'released:'
  )

  for (i in group_label) {
    release_number = release_summary %>%
      filter(., Facility == i) %>%
      filter(., Species == analysis) %>%
      pull(releases)
    release_label = paste(
      release_label, sprintf('%s: %s', i, release_number)
      , sep = '\n'
    )
  }    
  return(release_label) 
}


extract_top_model_results = function(results_list, analysis) {
  #analysis = 'assemblage'
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
  #extract real and derived results from top model
  final_results = extract_rmark_model_results(real_results, analysis, top_model_name) 
  
  return(final_results)
}

extract_rmark_model_results = function(data, analysis, model_name) {
  
  real_results = results_list[[analysis]][[model_name]]$results$real

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
  derived_pop_size_results = results_list[[analysis]][[model_name]]$results$derived$`N Population Size`
  occasions = nrow(derived_pop_size_results)
  derived_pop_size_groups = results_list[[analysis]][[model_name]]$group.labels
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

process_model_results = function(data) {
  data = data |> 
  mutate(facility = case_when(
      str_detect(data$Group, "FMCC") ~ "FMCC",
      str_detect(data$Group, "Harrison") ~ "Harrison Lake",
      .default = "None"
    )
    ,species = case_when(
      str_detect(data$Group, "compl") ~ "Elliptio complanata",
      str_detect(data$Group, "vari") ~ "Alasmidonta varicosa",
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
data = data |> 
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
release_summary_path = path(DATA_RAW, 'release_summary.xlsx')
release_summary = read_excel(release_summary_path) |> 
  select(species, facility, total_release, total_unique_tag)
data = data |>
  left_join(
    release_summary |> 
      rename(total_unique_tag_release = total_unique_tag),
    by = c('facility', 'species')
  ) |> 
  mutate(
    perc_of_initial = case_when(
      Parameter == "N_derived" ~ estimate / total_unique_tag_release
    ),
    perc_of_initial_lcl = case_when(
      Parameter == "N_derived" ~ lcl / total_unique_tag_release
    ),
    perc_of_initial_ucl = case_when(
      Parameter == "N_derived" ~ ucl / total_unique_tag_release
    )
  )

# sum values to create a 'combined' facility
combined_df = data |>
  filter(Parameter == 'N_derived') |> 
  group_by(mark_analysis_level, species, Parameter, Occasion) |> 
  summarise(
    estimate = sum(estimate),
    se = sum(se), # for se, lcl, and ucl, doublecheck calc and also consider only summing this way for n_derived
    lcl = sum(lcl), 
    ucl = sum(ucl),
    total_unique_tag_release = sum(total_unique_tag_release),
    .groups = "drop"
  ) |> 
  mutate(
    perc_of_initial = estimate/total_unique_tag_release ,
    perc_of_initial_lcl = lcl / total_unique_tag_release, # doublecheck calc of  this
    perc_of_initial_ucl = ucl / total_unique_tag_release , # doublecheck calc of this 
    facility = 'Combined')

data = bind_rows(data, combined_df)

# convert daily survival to annual survival
data = data |> 
  mutate(
    estimate = case_when(
      Parameter == 'Phi' ~ estimate^365.25,
      .default = estimate
    ),
    phi_lcl = case_when(
      Parameter == 'Phi' ~ lcl^365.25,
      .default = lcl
    ),
    phi_ucl = case_when(
      Parameter == 'Phi' ~ ucl^365.25,
      .default = ucl
    )
  )

return(data)

}

load_reduced_models = function(results_list) {
  #reduced E. complanata results (top model without the time element for survival)
  complanata_reduced_model = "Phi.facility.p.time.pent.0.N.dot"
  complanata_reduced_analysis = "Elliptio complanata"
  complanata_reduced_results = extract_rmark_model_results(results_list, complanata_reduced_analysis, complanata_reduced_model)
  # processing
  complanata_reduced_results = process_model_results(complanata_reduced_results)

  #reduced A. varicosa results (top model without the time element for survival)
  varicosa_reduced_model = "Phi.facility.p.time.pent.0.N.dot"
  varicosa_reduced_analysis = "Alasmidonta varicosa"
  varicosa_reduced_results = extract_rmark_model_results(results_list, varicosa_reduced_analysis, varicosa_reduced_model)
  # processing
  varicosa_reduced_results = process_model_results(varicosa_reduced_results)

  #bind species together and designate as reduced from top model
  reduced_models = bind_rows(complanata_reduced_results, varicosa_reduced_results) |> 
    mutate(model = 'reduced_from_top')
  
  return(reduced_models)
}

expand_phi_intervals = function(reduced_models) {
  ## expand values Phi for reduced_models to match the number of occasions for time dependent model
  
  # get list of intervals to replicate
  intervals_to_replicate = c('Interval 1', 'Interval 2', 'Interval 3', 'Interval 4')
  # get only reduced model rows for Phi
  reduced_rows_phi = reduced_models |> 
      filter(Parameter == 'Phi') |> 
      select(-Occasion)
  # expand to all intervals
  reduced_expanded_phi = reduced_rows_phi |> 
    expand_grid(Occasion = intervals_to_replicate)
  #remove Phi values from original reduced models
  reduced_models_no_phi = reduced_models |> 
    filter(Parameter != 'Phi')
  # bind phi and no phi together again
  df = bind_rows(reduced_models_no_phi, reduced_expanded_phi)

  return (df)

}