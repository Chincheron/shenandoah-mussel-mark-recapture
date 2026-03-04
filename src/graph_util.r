library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(writexl)
library(scales)

build_base_plot = function(data, global_config, family_config, figure_config = list()){

  #overide family_config with figure specific settings, if provided
  config = modifyList(family_config, figure_config)

  #TODO modify so that names are unique, right now some are being overridden
  #set default save name if one is not provided
  if (is.null(config$save_file_name)) {
    facet_name = if (!is.null(config$facet_vars)) {
      paste(config$facet_vars, collapse = "_")
    } else {
      'no_facet'
    }
    
    config$save_file_name = sprintf(
      '%s_%s_%s.png',
      config$parameter,
      config$y_label,
      facet_name
    )
  }

  #create save directory if needed
  dir_create(config$save_folder)

  #for readability
  cm = global_config$column_mapping

  #set dodge to make sure groups and error bars are on same alignment
  dodge = position_dodge(width=0.9)

  #filter to parameter of interest
  p = data |> 
  filter(.data[[cm$mark_parameter]]  == 
    config$parameter) |> 
  #base plot
  ggplot(
    aes(
      x = factor(
        .data[[config$x_factor]],
        levels = config$x_order
      ), #pull to global or family config?
      y = .data[[config$y_factor]],
      fill = factor(
        .data[[config$grouping]],
        levels = config$grouping_order
      )
    )
  ) +
  geom_col(position = dodge) +
  labs(
    x = config$x_factor_label,
    y = config$y_label,
    fill = config$grouping_label,
    title = config$title,
    subtitle = config$subtitle,
    caption = config$caption
  ) +
  scale_fill_manual(
    values = global_config$palettes[[config$grouping_palette]]
  ) + 
  global_config$theme
  
  # faceting logic
  if (length(config$facet_vars) == 0) {
    #do nothing to alter plot
  } else if
    (length(config$facet_vars) == 1) {
    p = p +
      facet_wrap(vars(.data[[config$facet_vars]]))
  } else if (length(config$facet_vars) == 2){
    p = p +
      facet_grid(
        rows = vars(.data[[config$facet_vars[1]]]),
        cols = vars(.data[[config$facet_vars[2]]])
      )
  } else {
    stop(("facet_vars in family config file must have either 1, 2, or 0 variables"))
  }

  # add error bars if config flag is TRUE
  if (config$variance_flag == TRUE) {
    p = p +  
      geom_errorbar(
      aes(ymin = .data[[config$y_variance_lower]], ymax = .data[[config$y_variance_upper]]),
      width = 0.2,
      position = dodge
      ) 
    } else {
  }


  ggsave(
  filename =  config$save_file_name,
  plot = p,
  path = config$save_folder,  
  width = 8,
  height = 5,
  dpi = 300
  )  

  return(p)
}

add_release_label_to_graph = function(p) {
  
  p = p +
    annotate(
    "text",
    x = -Inf,
    y = Inf,
    label = 'label_released',
    hjust = -0.1,
    vjust = 1.1
    ) 
  
  print(p)
}