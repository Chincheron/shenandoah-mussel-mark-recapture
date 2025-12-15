library(RMark)
library(reticulate)
library(withr)
library(fs)

#pulls path constants
source_python("config/paths.py")

source_folder = DATA_PIPELINE
output_folder = path(RESULTS_TEMP)
source_file = path(source_folder, "04_mark_input.inp")

mark_input = read.csv(path(source_file))

with_dir(path(ROOT, "temp"), {
    mark(mark_input)
    })

#