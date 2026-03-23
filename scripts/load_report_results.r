library(tidyverse)
library(readxl)
library(flextable)
library(fs)

set_flextable_defaults(fonts_ignore = TRUE)

SCRIPT_NAME = '07_reduced_model_results'
TABLE_PATH = path(RESULTS_TABLES, SCRIPT_NAME)

max_species_abundance = function(species, table){
  #columns to use for max/min for abundance
  stat_columns = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4')
  
  max_abundance = table |> 
  filter(.data$species == .env$species) |> 
  select(all_of(stat_columns)) |> 
  unlist() |> 
  max()
  return(max_abundance)
} 

min_species_abundance = function(species, table){
  #columns to use for max/min for abundance
  stat_columns = c('Release', 'MR 1', 'MR 2', 'MR 3', 'MR 4')
  
  min_abundance = table |> 
  filter(.data$species == .env$species) |> 
  select(all_of(stat_columns)) |> 
  unlist() |> 
  min()
  return(min_abundance)
} 

# Table showing unique release abundance (i.e., actual estimates from MARK)
path = path(TABLE_PATH, 'abundance_summary.csv')
tbl_abundance_summary = read_csv(path)  
stat_species = 'Elliptio complanata'
max_abundance_complanata = max_species_abundance(stat_species, tbl_abundance_summary)
min_abundance_complanata = min_species_abundance(stat_species, tbl_abundance_summary)
stat_species = 'Alasmidonta varicosa'
max_abundance_varicosa = max_species_abundance(stat_species, tbl_abundance_summary)
min_abundance_varicosa = min_species_abundance(stat_species, tbl_abundance_summary)

# Table showing all release abundance 
path = path(TABLE_PATH, 'abundance_all_summary.csv')
tbl_abundance_all_summary = read_csv(path)  
stat_species = 'Elliptio complanata'
max_abundance_all_complanata = max_species_abundance(stat_species, tbl_abundance_all_summary)
min_abundance_all_complanata = min_species_abundance(stat_species, tbl_abundance_all_summary)
stat_species = 'Alasmidonta varicosa'
max_abundance_all_varicosa = max_species_abundance(stat_species, tbl_abundance_all_summary)
min_abundance_all_varicosa = min_species_abundance(stat_species, tbl_abundance_all_summary)

max_species_survival = function(species, table){
  #columns to use for max/min for abundance
  stat_columns = c('estimate')
  
  max_abundance = table |> 
  filter(.data$species == .env$species) |> 
  select(all_of(stat_columns)) |> 
  unlist() |> 
  max()
  return(max_abundance)
} 

min_species_survival = function(species, table){
  #columns to use for max/min for abundance
  stat_columns = c('estimate')


  max_abundance = table |> 
  filter(.data$species == .env$species) |> 
  select(all_of(stat_columns)) |> 
  unlist() |> 
  min()
} 

# Table showing survival estimates 
path = path(TABLE_PATH, 'survival_summary.csv')
tbl_survival_summary = read_csv(path)  
stat_species = 'Elliptio complanata'
max_survival_complanata = max_species_survival(stat_species, tbl_survival_summary)
min_survival_complanata = min_species_survival(stat_species, tbl_survival_summary)
stat_species = 'Alasmidonta varicosa'
max_survival_varicosa = max_species_survival(stat_species, tbl_survival_summary)
min_survival_varicosa = min_species_survival(stat_species, tbl_survival_summary)

# function for making table object out of two abundance tables for rendering 
# Called in main document
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
      `species` = "Species",
      `Release_FMCC` = "FMCC",
      `Release_Harrison Lake` = "Harrison Lake",
      `MR 1_FMCC` = "FMCC",
      `MR 1_Harrison Lake` = "Harrison Lake",
      `MR 2_FMCC` = "FMCC",
      `MR 2_Harrison Lake` = "Harrison Lake",
      `MR 3_FMCC` = "FMCC",
      `MR 3_Harrison Lake` = "Harrison Lake",
      `MR 4_FMCC` = "FMCC",
      `MR 4_Harrison Lake` = "Harrison Lake"
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
  width(j = 2:ncol(test_load), width = (6.5 - .8) / 10) |>  # distribute remaining width evenly across data cols
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
