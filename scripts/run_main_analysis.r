library(here)

setwd(here::here())

python_scripts = c(
  'scripts/01_load_raw_data.py',
  'scripts/02_occasion_cleanup.py',
  'scripts/03_join_release_occasion.py',
  'scripts/04_mark_input.py'
)

for (script in python_scripts) {
  script_path = here::here(script)
  message('Running Python script: ', script)
  system2('uv', c('run', 'python', script_path))
}

renv::restore(prompt = FALSE)

r_scripts = c(
  'scripts/05_mark_analysis.r',
  'scripts/06_top_model_results.r',
  'scripts/06a_reduced_model_comparison.r',
  'scripts/07_reduced_model_results.r'
)

for (script in r_scripts) {
  message('Running R Script: ', script)
  source(script, local = TRUE)
} 

