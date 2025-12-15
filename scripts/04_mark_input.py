import chincheron_util.file_util as file_util
from config.paths import DATA_RAW, RESULTS_TABLES, RESULTS_TEMP, DATA_INTERIM, ROOT, DATA_PIPELINE
import polars as pl
from pathlib import Path
import src.util as util
import csv
import pandas as pd

#set folder locations
source_file = DATA_PIPELINE / '03_cleaned_data.csv'
output_path = DATA_PIPELINE

# Load occasion data
columns_to_load = [
 'ID',
 'sampling_occasion_1',
 'sampling_occasion_2',
 'sampling_occasion_3',
 'sampling_occasion_4'   
]
occasion_df = pl.read_csv(source_file, columns=columns_to_load)

#concantenate encounter histories
encounter_col = [
    'sampling_occasion_1',
    'sampling_occasion_2',
    'sampling_occasion_3',
    'sampling_occasion_4'
]
occasion_df = occasion_df.with_columns(
    pl.concat_str(encounter_col).alias('encounter_history')
)

#just encounter history
encounter_history = occasion_df.select('encounter_history').filter(pl.col('encounter_history').is_not_null())

#write to file
encounter_history.write_csv(DATA_PIPELINE / '04_mark_input.inp', include_header=False, line_terminator=' 1;\n')
