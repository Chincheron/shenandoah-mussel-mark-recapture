'''
Script: 04_mark_input.py

Purpose: Final preparation of  processed release/occasion data for use as a MARK input file.  
 
Inputs:
- 03_cleaned_data.csv 

Outputs:
- Pipeline:
    - 04_mark_input.csv (Ready to go for use as RMARK input file)
- Various QC files
'''
# =============================================================================
# 1. Setup 
# =============================================================================

# -----------------------------------------------------------------------------
# Imports and Constants
# -----------------------------------------------------------------------------

import chincheron_util.file_util as file_util
from config.paths import DATA_INTERIM, DATA_PIPELINE
import polars as pl

# -----------------------------------------------------------------------------
# Paths and import/export directories
# -----------------------------------------------------------------------------

# Set directories
SCRIPT_NAME = '04_mark_input'
source_folder = DATA_PIPELINE / '03_join_release_occasion'
qc_folder = DATA_INTERIM / SCRIPT_NAME
qc_folder_final_data = qc_folder / 'final_qc'
pipeline_folder = DATA_PIPELINE / SCRIPT_NAME

# Make directories
file_util.make_directory(qc_folder)
file_util.make_directory(qc_folder_final_data)
file_util.make_directory(pipeline_folder)

# =============================================================================
# 2. Load and transform combined release/occasion data
# =============================================================================

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------

source_file = source_folder / '03_cleaned_data.csv'
columns_to_load = [
 'ID',
 'Species',
 'Facility',
 'release_length',
 'max_length',
 'A or D',
 'last_status',
 'PIT_tag_no',
 'sampling_occasion_1',
 'sampling_occasion_2',
 'sampling_occasion_3',
 'sampling_occasion_4'   
]
# Import was reading these columns as numeric even though some had a value of 'D' 
# Specified as string 
occasion_schema_override = {
 'sampling_occasion_1': pl.String,
 'sampling_occasion_2': pl.String,
 'sampling_occasion_3': pl.String,
 'sampling_occasion_4': pl.String
}
occasion_df = pl.read_csv(source_file, columns=columns_to_load, schema_overrides=occasion_schema_override)

# -----------------------------------------------------------------------------
# Create encounter history column
# -----------------------------------------------------------------------------

# Combine occasions into single encounter history column
encounter_cols = [
    'sampling_occasion_1',
    'sampling_occasion_2',
    'sampling_occasion_3',
    'sampling_occasion_4'
]
# Column title must be 'ch' for later use with RMARK
occasion_df = occasion_df.with_columns(
    pl.concat_str(encounter_cols).alias('ch')  
)

# Add release occasion to mark recapture encounter history
# Fill out missing encounter histories where released mussels were never observed
#   (identified by null sampling_occasion_1)
occasion_df = occasion_df.with_columns(
    pl.when(pl.col('sampling_occasion_1').is_null())
    .then(pl.lit('10000'))
    .otherwise(pl.concat_str(pl.lit('1'), pl.col('ch')))
    .alias('ch')
)

# -----------------------------------------------------------------------------
# Create column indicating whether there was a PIT tag
# -----------------------------------------------------------------------------

occasion_df = occasion_df.with_columns(
    pl.when(pl.col('PIT_tag_no').is_not_null())
    .then(pl.lit(1))
    .otherwise(pl.lit(0))
    .alias('PIT_status')
)

# -----------------------------------------------------------------------------
# Export occasion_df for manual review before creating MARK input file
# -----------------------------------------------------------------------------

file_name = qc_folder_final_data / 'qc_occasion_final.csv'
occasion_df.write_csv(file_name)

# -----------------------------------------------------------------------------
# Filter to final columns needed for MARK input file
# -----------------------------------------------------------------------------

# Include just following columns 
include_list = [
    'ch',
    'Species',
    'Facility',
    'PIT_status', 
    'release_length', 
    'max_length']
# filter by rows where 'ch' is not null (should be same number of rows as occasion_df)
mark_input = occasion_df.select(include_list).filter(pl.col('ch').is_not_null())


# =============================================================================
# 05. Export mark_input
# =============================================================================

# -----------------------------------------------------------------------------
# Export for final QC check
# -----------------------------------------------------------------------------

file_name = qc_folder_final_data / 'mark_input.csv'
mark_input.write_csv(file_name)

# -----------------------------------------------------------------------------
# Export for Pipeline
# -----------------------------------------------------------------------------

file_name = pipeline_folder / '04_mark_input.csv'
mark_input.write_csv(file_name, include_header=True, quote_style='always')
