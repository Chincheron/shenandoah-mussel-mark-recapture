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

  #for readability
  cm = global_config$column_mapping

  #filter to parameter of interest
  p = data |> 
  filter(.data[[cm$mark_parameter]]  == 
    config$parameter) |> 
  #base plot
  ggplot(
    aes(
      x = factor(.data[[config$x_factor]]), #pull to global or family config?
      y = .data[[cm$parameter_estimate]],
      fill = .data[[config$grouping]]
    )
  ) +
  geom_col(position = position_dodge()) +
  labs(
    x = config$x_factor_label,
    y = config$y_label,
    fill = config$grouping_label
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
  
  return(p)
}
