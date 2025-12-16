library(RMark)
library(reticulate)
library(withr)
library(fs)
library(dplyr)
library(tidyverse)

#pulls path constants
source_python("config/paths.py")

source_folder = DATA_PIPELINE
output_folder = path(RESULTS_TEMP)
source_file = path(source_folder, "04_mark_input.csv")

mark_input = read_csv(path(source_file), col_types=cols('ch' = col_character()))

#Run Mark Model
#must use with_dir to ensure Mark files are in desired subfolder instead of cluttering up Root folder 
# subsequent data manipulation should use the assigned variable to avoid issues
analysis_1 = with_dir(path(ROOT, "temp"), {
    mark(mark_input)
    })

summary(analysis_1)
ls()
class(analysis_1)
getwd()
#