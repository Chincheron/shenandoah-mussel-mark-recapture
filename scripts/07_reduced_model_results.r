######## 
# Preparing results from the reduced model for presentation in report 
########

library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(writexl)
library(scales)

#pulls path constants
source_python("config/paths.py")
#pull utility functions
util_file = path(ROOT , "src", "util.r")
graph_util_file = path(ROOT , "src", "graph_util.r")
config_folder = path(ROOT, 'config')
source(util_file)
source(graph_util_file)
source(path(config_folder, 'global_figure_config.r'))

#set export directories
SCRIPT_NAME = '07_reduced_model_results'
data_export_folder = path(DATA_PROCESSED, SCRIPT_NAME)
dir_create(data_export_folder)
figure_export_folder = path(RESULTS_FIGURES, SCRIPT_NAME)
dir_create(figure_export_folder)
table_export_folder = path(RESULTS_TABLES, SCRIPT_NAME)
dir_create(table_export_folder)

#retrieve r object with model outputs from RMARK analysis
results_file = path(path(DATA_INTERIM, 'saved_objects', '05_mark_results.rds'))
results_list = readRDS(results_file)
#remove assemblage level analyses
results_list = results_list[names(results_list) != 'assemblage']

reduced_models = load_reduced_models(results_list) 

# expand values Phi for reduced_models to match the number of occasions for the top model
reduced_models = expand_phi_intervals(reduced_models)

#export results to file
model_results_save_name = 'reduced_model_data.xlsx'
model_results_save_path = path(data_export_folder, model_results_save_name)
write_xlsx(reduced_models, model_results_save_path)
