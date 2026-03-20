library(tidyverse)
library(readxl)
library(flextable)

SCRIPT_NAME = '07_reduced_model_results'
TABLE_PATH = path(RESULTS_TABLES, SCRIPT_NAME)

path = path(TABLE_PATH, 'abundance_summary.csv')
test_load = read_csv(path) |> 

make_abundance_table = function(test_load) {
  occasions = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4')
  test_load = test_load |>
    pivot_wider(
      names_from = 'facility',
      values_from = all_of(occasions),
      names_glue = '{.value}_{facility}'
    ) |> 
    select(species, 
         map(occasions, ~ paste0(.x, "_", c("FMCC", "Harrison Lake"))) |> unlist()
  )

  ft = flextable(test_load) |> 
     set_header_labels(
    values = setNames(
      rep(c("FMCC", "Harrison Lake"), 5),
      paste0(rep(occasions, each = 2), "_", c("FMCC", "Harrison Lake"))
    ) |> c(species = "Species") |> as.list()
  ) |>
  # Add spanning top header row for occasions
  add_header_row(
    values    = c("", occasions),
    colwidths = c(1, rep(2, 5))
  ) |>
  # Style
  theme_vanilla() |>
  align(align = "center", part = "header") |>
  align(align = 'center', part = 'body') |> 
  align(j = 1, align = "left", part = "all") |>
  fontsize(size = 8, part = "all") |> 
  padding(padding.top = 2, padding.bottom = 2, 
          padding.left = 3, padding.right = 3, part = "all") |> 
  width(j = -1, width = (6.5 - .8) / 10) |>  # distribute remaining width evenly across data cols
  width(j = 1, width = .8) 
    # autofit() |> 
  # fit_to_width(max_width = 6.5) |> 
  # set_table_properties(
  #   layout= 'fixed',
  #   width = 1,
  #   align = 'left'
  # )

ft
}
