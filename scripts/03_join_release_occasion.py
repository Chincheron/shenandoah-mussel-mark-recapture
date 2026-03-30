'''
Script: 03_join_release_occasion.py

Purpose: Join occasion data and release data together for final conversion into 
    MARK format; includes additional QC
 
Inputs:
- 02_combined_occasions.csv 
- 01_Summary.csv

Outputs:
- Pipeline:
    - 03_cleaned_data.csv (Joined summary and occasion data)
- Various QC files
'''
# =============================================================================
# 1. Setup 
# =============================================================================

# -----------------------------------------------------------------------------
# Imports and Constants
# -----------------------------------------------------------------------------

# --- Import standard libraries ---
import sys
from pathlib import Path
import polars as pl
from pyprojroot import here

# Find Root of project folder for custom imports
ROOT = here()
# Insert root on PATH search so custom module is imported correctly
sys.path.insert(0, str(ROOT))

# --- Import custom libraries ---
import chincheron_util.file_util as file_util
from config.paths import DATA_INTERIM, DATA_PIPELINE
import src.util as util


# -----------------------------------------------------------------------------
# Paths and import/export directories
# -----------------------------------------------------------------------------

# Set directories
SCRIPT_NAME = '03_join_release_occasion'
occasion_source_folder = DATA_PIPELINE / '02_occasion_cleanup'
release_source_folder = DATA_PIPELINE / '01_load_raw_data'
qc_folder = DATA_INTERIM / SCRIPT_NAME / 'QC'
qc_folder_final_data = qc_folder / 'final_qc'
pipeline_folder = DATA_PIPELINE / SCRIPT_NAME

# Make directories
file_util.make_directory(qc_folder)
file_util.make_directory(pipeline_folder)
file_util.make_directory(qc_folder_final_data)

# =============================================================================
# 2. Load occasion data
# =============================================================================

occasion_file = occasion_source_folder / '02_combined_occasions.csv'
release_source_folder = DATA_PIPELINE / '01_load_raw_data'
columns_to_load = [
 'Species',
 'Tag Color',
 'Hallprint_tag_no_1',
 'Hallprint_tag_no_2',
 'PIT_tag_no',
 'Length',
 'Status',
 'Other Tag Attribute',
 'sampling_occasion'   
]
occasion_df = pl.read_csv(occasion_file, columns=columns_to_load)

# -----------------------------------------------------------------------------
# Filter and transform occasion data
# -----------------------------------------------------------------------------

# --- Exclude non-uniquely tagged mussels ---  

# Include only valid tag colors OR PIT tag no. 
tag_color_list = ['Yellow', 'Green', 'Red', 'Orange']
occasion_df = occasion_df.filter(
    ((pl.col('Tag Color').is_in(tag_color_list)) |
    (pl.col('PIT_tag_no').is_not_null())
    )
)
# Two PIT tags were detected, but mussels were not found. Exclude these.
occasion_df = occasion_df.filter(
    ~(pl.col('Tag Color') == 'NO MUSSEL')
)
# Exclude invalid tag numbers (also excludes null values for tag 1 column)
invalid_tag_number = ['SQUARE', 'NO TAG', 'GLUE DOT']
occasion_df = occasion_df.filter(
    ~(pl.col('Hallprint_tag_no_1').is_in(invalid_tag_number))
)

# --- Collapse into single line for each mussel ---
# Convert single occasion column into dummy variable columns
occasion_df = occasion_df.to_dummies(columns='sampling_occasion')
# Identify occasions where status is DEAD  
# Flag corresponding occasion dummy column as 'D' rather than '1' for later filtering
occasion_df = util.encounter_to_AD(occasion_df)
#grouping columns
group_col = [
    'Tag Color',
    'Hallprint_tag_no_1',
    'Hallprint_tag_no_2',
    'PIT_tag_no'
]
# Group by tags, resulting in a single line per mussel
occasion_group_df = (
    occasion_df
    .group_by(group_col)
    .agg(pl.col('Species').first(),
    pl.col('Length').max().alias('max_length'), #TODO some are missing when converted to sample_length in final export (e.g., E310)
    pl.col('Status').last().alias('last_status'),
    pl.col(f'sampling_occasion_2').max(),
    pl.col(f'sampling_occasion_1').max(),
    pl.col(f'sampling_occasion_3').max(),
    pl.col(f'sampling_occasion_4').max()
    )
)

# -----------------------------------------------------------------------------
# QC of loaded occasion data before joining with release
# -----------------------------------------------------------------------------

# Check for multiple instances of same tag 
df_mask = occasion_group_df.select(['Tag Color', 'Hallprint_tag_no_1']).is_duplicated()
df_dup = occasion_group_df.filter(df_mask).sort('Hallprint_tag_no_1')
file_name = qc_folder / 'individual_duplicate_check.csv'
df_dup.write_csv(file_name)

# Export final occasion data for manual review before joining with release data
file_name = qc_folder_final_data / 'occasion_grouped.csv'
occasion_group_df.write_csv(file_name)

# =============================================================================
# 3. Load release (summary) data
# =============================================================================

# -----------------------------------------------------------------------------
# Load cleaned release data
# -----------------------------------------------------------------------------

release_file = release_source_folder / '01_Summary.csv'
columns_to_load = [
 'Species',
 'Facility',
 'Tag 1 #',
 'Tag 2 #',
 'Tag color',
 'PIT Tag ID',
 'Measurement (mm)\r\nwhen released',
 'Measurement (mm)\r\nwhen last found',
 'Found in \r\npass 1',
 'Found in \r\npass 2',
 'Found in \r\npass 3',
 'Found in \r\npass 4',
 'Sum value',
 'A or D' 
]
release_df = pl.read_csv(release_file, columns=columns_to_load)

# -----------------------------------------------------------------------------
# Filter and transform release data
# -----------------------------------------------------------------------------

# Remove \r and \n values from headings to avoid potential issues later when writing to csv
release_df = release_df.rename(
    lambda c: c.replace('\r\n', ' ').strip()
)

# Rename columns to avoid issues with () later on
release_df = release_df.rename({'Measurement (mm) when released': 'release_length', 'Measurement (mm) when last found': 'sample_length'})

# =============================================================================
# 04. Join occasion data to release data
# =============================================================================

# Second tag number not included because summary file uses PIT tag for tag number 2 
# and some 2nd tags are missing compared to later encounters
left_join_col = [
    'Tag color', 'Tag 1 #'
]
right_join_col =[
    'Tag Color', 'Hallprint_tag_no_1'
]
join_df = release_df.join(
    occasion_group_df, 
    left_on=left_join_col, 
    right_on=right_join_col,
    how='left'
)

# Create unique ID column for each mussel
join_df = join_df.with_row_index(name='ID', offset=1)

# -----------------------------------------------------------------------------
# QC of joined data
# -----------------------------------------------------------------------------

# Find unmatched records from MR occasions (i.e., records that could not be joined to release data )
unmatched_occasion_df = occasion_group_df.join(
    release_df,
    left_on=right_join_col,
    right_on=left_join_col,
    how="anti"
)
#write to csv for review
file_name = qc_folder / 'unmatched_occasions_records.csv'
unmatched_occasion_df.write_csv(file_name)

# =============================================================================
# 05. Export joined release/occasion data
# =============================================================================

# -----------------------------------------------------------------------------
# Export for final QC check
# -----------------------------------------------------------------------------

file_name = qc_folder_final_data / 'qc_joined_data.csv'
join_df.write_csv(file_name)

# -----------------------------------------------------------------------------
# Export for Pipeline
# -----------------------------------------------------------------------------

#export for mark-recapture analysis preparation
file_name = pipeline_folder / '03_cleaned_data.csv'
join_df.write_csv(file_name)
