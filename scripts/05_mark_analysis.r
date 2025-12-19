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

# mark_input = select(mark_input, ch)
#confirm data format
summary(mark_input)
mark_input[1:5,]

# TODO - define time interval

#Run Mark Model
#must use with_dir to ensure Mark files are in desired subfolder instead of cluttering up Root folder 
# subsequent data manipulation should use the assigned variable to avoid issues
cjs_analy = with_dir(path(ROOT, "temp"), {
    mark(mark_input, model = 'CJS',
      groups = c("Species", "Facility")
    )
    })

PIMS(cjs_analy, 'Phi', simplified = FALSE)
PIMS(cjs_analy, 'p')

summary(cjs_analy) #why do groups have same parameter estimates (for POPAN too)

popan_analy = with_dir(path(ROOT, "temp"), {
    mark(mark_input, model = 'POPAN',
      groups = c("Species", "Facility")
    )
    })
summary(popan_analy) 
