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

#Assume dead observations were not observed for modeling purposes
mark_input$ch <- str_replace_all(mark_input$ch, 'D', '0') 

# mark_input = select(mark_input, ch)
#confirm data format
summary(mark_input)
mark_input[1:5,]

#split by species
species_input <- split(mark_input, mark_input$Species)

# TODO - define time interval 
# but may need to explicity split up by speciesxFacility - different release dates
#or not - most seems to be 10/11/23 and one species on 10/19. probably close enough?

#Run Mark Model
#must use with_dir to ensure Mark files are in desired subfolder instead of cluttering up Root folder 
# subsequent data manipulation should use the assigned variable to avoid issues

#####
# POPAN
#####  

## Species setups
## Elliptio complanata
# 569 FMCC and 489 Harrison released on 10/11/23
# 443 FMCC released on 10/17/2024 
#TODO - Analyze 2024 releases separately? Yes, they were not even reelase until just before the 4th sampling occasion

mark_input = species_input$`Elliptio complanata`
#setup common analysis variables
time_interval = c(246,35, 29, 69) #TODO setup formula for calculating for each species automaically
begin_time = 2024 # must be a number and not a string

## define models
#phi
Phi.dot=list(formula=~1)
Phi.time = list(formula=~time)
Phi.species = list(formula=~Facility)

#p
p.dot=list(formula=~1)
p.time=list(formula=~time)
p.species = list(formula=~Facility)

#Create processed dataframe for specific model
popan_process = process.data(mark_input, 
  model = 'POPAN'
  ,begin.time = begin_time
  ,time.intervals = time_interval
  , groups = c("Facility")
)
popan_process$group.covariates

#Create design data for analysis
popan_ddl = make.design.data(popan_process)

#Auto create all possible models to be run based on model list of individual parameters
#TODO - Move individual parameter definiiton to function (from above to below)
popan_model_list = create.model.list("POPAN")
popan_results = with_dir(path(ROOT, "temp"), {
    mark.wrapper(popan_model_list, data=popan_process, ddl=popan_ddl
    )
    })

popan_results$Phi.dot.p.dot$results$real

popan_results$Phi.time.p.time$results$real

popan_results$Phi.time.p.time$results$derived

popan_results$Phi.dot.p.dot$results$derived

popan_results$model.table


with_dir(path(ROOT, "temp"), {
      export.MARK(popan_process, "complanata_test",  popan_results
    )
    })


popan_analy = with_dir(path(ROOT, "temp"), {
    mark(popan_process, popan_ddl
    )
    })
summary(popan_analy) 




popan_analy = with_dir(path(ROOT, "temp"), {
    mark(mark_input, model = 'POPAN',
      groups = c("Species", "Facility")
      , model.parameters = list(Phi = Phi.species, p = p.dot)
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

