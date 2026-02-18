library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)

run_popan = function(input_file, analy_groups, model_def, analysis_name)
{
  analysis_name = analysis_name
  save_directory = path(ROOT, 'temp', analysis_name)
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

graph_mark_results = function(plot_data, save_path, save_filename, graph_title) {  
  
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
    scale_x_discrete(labels = label_wrap(width = 10)) # Automatically wraps labels to max 10 characters per line

  ggsave(
    filename =  save_filename,
    plot = p,
    path = save_path,  # <- change this
    width = 8,
    height = 5,
    dpi = 300
  )  

}