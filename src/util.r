library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)

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
  if (mr_only == TRUE) {
    time_interval = c(35, 29, 69)
  } else {
    time_interval = c(246,35, 29, 69) #TODO setup formula for calculating for each species automaically}
  }
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