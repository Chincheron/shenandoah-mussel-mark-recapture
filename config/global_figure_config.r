get_global_fig_config = function() {
  all_plot_config <- list(
  labels = list(
    mark_analysis_level = "Analysis Level",
    Occasion = "Sampling Occasion",
    facility = "Facility",
    species = "Species",
    perc_of_initial = "Percentage of Initial Release",
    model = 'Model Type'
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
    ),
    model_level = c(
      reduced_from_top = 'darkorange',
      top = 'steelblue'
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
    initial_release = 'initial_release',
    perc_of_initial = "perc_of_initial",
    perc_of_initial_lcl = "perc_of_initial_lcl",
    perc_of_initial_ucl = "perc_of_initial_ucl",
    model = 'model',
    phi_lower_ci = 'phi_lcl',
    phi_upper_ci = 'phi_ucl'
  ),
  category_order = list(
    sampling_occasion = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4'),
    sampling_occasion_phi = c('Interval 1', 'Interval 2', 'Interval 3', 'Interval 4')
  ),
  theme = theme_bw(base_size = 12),
  save_folder = path(RESULTS_FIGURES, 'mark_results')
)
  return(all_plot_config)
}