library(tidyverse)
library(readxl)

path = path(DATA_PROCESSED, '07_reduced_model_results', 'reduced_model_data.xlsx')
test_load = read_xlsx(path)
