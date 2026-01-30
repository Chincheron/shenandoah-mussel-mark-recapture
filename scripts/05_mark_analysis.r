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
# but may need to explicity split up by speciesxFacility - different release dates
#or not - most seems to be 10/11/23 and one species on 10/19. probably close enough?

#Run Mark Model
#must use with_dir to ensure Mark files are in desired subfolder instead of cluttering up Root folder 
# subsequent data manipulation should use the assigned variable to avoid issues

#####
# POPAN
#####  

#setup common analysis variables
time_interval = c(1,1,1,1)
begin_time = 2024 # must be a number and not a string

popan_process = process.data(mark_input, 
  model = 'POPAN'
  ,begin.time = begin_time
  ,time.intervals = time_interval
  , groups = c("Species", "Facility")
)
popan_process$group.covariates

popan_ddl = make.design.data(popan_process)




popan_analy = with_dir(path(ROOT, "temp"), {
    mark(popan_process, popan_ddl
    )
    })
summary(popan_analy) 


popan_analy = with_dir(path(ROOT, "temp"), {
    mark(mark_input, model = 'POPAN',
      groups = c("Species", "Facility")
    )
    })
summary(popan_analy) 

PIMS(popan_analy, 'Phi')

#####
# CJS
#####  

cjs_analy = with_dir(path(ROOT, "temp"), {
    mark(mark_input, model = 'CJS',
      groups = c("Species", "Facility")
    )
    })

PIMS(cjs_analy, 'Phi', simplified = FALSE)
PIMS(cjs_analy, 'p')

summary(cjs_analy) #why do groups have same parameter estimates (for POPAN too)

