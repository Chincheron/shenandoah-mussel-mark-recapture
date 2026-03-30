'''
Script: 02_occasion_cleanup.py

Purpose: QC and preparation of occasion data for further analysis

Inputs:
- Occasion_1.csv
- Occasion_2.csv
- Occasion_3.csv
- Occasion_4.csv

Outputs:
- Pipeline:
    - 02_combined_occasions.csv (Cleaned combined occasion data)
- Various QC files 
'''
# =============================================================================
# 1. Setup 
# =============================================================================

# -----------------------------------------------------------------------------
# Imports and Constants
# -----------------------------------------------------------------------------

# --- Import standard libraries ---
import polars as pl
import sys
from pathlib import Path
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
SCRIPT_NAME = '02_occasion_cleanup'
source_folder = DATA_PIPELINE / '01_load_raw_data'
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

# -----------------------------------------------------------------------------
# Load occasion data
# -----------------------------------------------------------------------------

mr_1_file = source_folder / 'Occasion_1.csv'
mr_2_file = source_folder / 'Occasion_2.csv'
mr_3_file = source_folder / 'Occasion_3.csv'
mr_4_file = source_folder / 'Occasion_4.csv'

mr1 = pl.read_csv(mr_1_file)
mr2 = pl.read_csv(mr_2_file)
mr3 = pl.read_csv(mr_3_file)
mr4 = pl.read_csv(mr_4_file)

# Combine occasions into one dataframe
list = [mr1, mr2, mr3, mr4]
combined_df = pl.DataFrame()
for index, df in enumerate(list):
    df = df.with_columns(sampling_occasion=index+1
    )
    combined_df = pl.concat([combined_df, df])

del(mr_1_file, mr_2_file, mr_3_file, mr_4_file, mr1, mr2, mr3, mr4, df, list, index)

# =============================================================================
# 3. QC and clean occasion data
# =============================================================================

# -----------------------------------------------------------------------------
# Generate file of unique values to determine first round of QC
# -----------------------------------------------------------------------------
qc_unique_values_file_name = 'unique_values.xlsx'
util.qc_unique_values(combined_df, qc_folder, qc_unique_values_file_name)

# -----------------------------------------------------------------------------
# Basic cleaning and data correction of original columns for each occasion
# -----------------------------------------------------------------------------

# Standardize spellings and category names
# Correct issue with some PIT tag numbers being in wrong format)
combined_df = util.clean_original_columns(combined_df)

# Minor corrections to data (see documentation and/or function for details)
combined_df = util.correct_original_values(combined_df)

# 15 PIT numbers from occasion 2 included only the last four digits of the full PIT #
# This was causing these individuals to not match other occasions
# Updated to match original release PIT #
combined_df = util.fix_PIT_values(combined_df)

# Some A. varicosa tags were marked as 'Red' when sampled after release.
# We determined that these should have been 'Orange' based on several factors (see documentation for details)
# All A. varicosa with 'Red' FXXX tags changed to 'Orange'
combined_df = util.fix_varicosa_color(combined_df)

# -----------------------------------------------------------------------------
# Confirm all values are standardized
# ----------------------------------------------------------------------------- 

qc_unique_values_confirm_file_name = 'unique_values_confirm.xlsx'
util.qc_unique_values(combined_df, qc_folder, qc_unique_values_confirm_file_name)

# -----------------------------------------------------------------------------
# Additional fixes to issues found when joining to summary data at a later step
# -----------------------------------------------------------------------------

# Some double-tagged mussels were recorded out of order compared to original release when 
#  one of the tags had been lost
# e.g., original tag 1/2 were E602/E603 but was tag 1 was recorded as E603 because the second tag
#   had fallen off when observed during MR sampling
# This was causing issues with matching mussels to summary data at later steps
# Corrected tag number order for these mussels
combined_df = util.order_tag_numbers(combined_df)
  
# When attempting to join records at later step, various typos were discovered
#   that prevented matching (e.g., E194 recorded as R194). 
# Updated these where possible based on comparison to release data 
combined_df = util.correct_unmatched_records(combined_df)

# Found various issues during script 03 when checking for individual duplicates
# e.g., PIT tags misclassified as Hallprint, null values, additional typos
combined_df = util.correct_tag_duplicates(combined_df)

# Make tag numbers all cap to prevent matching issues
combined_df = combined_df.with_columns(
    pl.col('Tag Number').str.to_uppercase(),
    pl.col('Tag Number 2').str.to_uppercase()
)

# Create new columns for tag numbers split by type (Hallprint Tag 1, hallprint Tag 2, and PIT tag)
combined_df = util.add_tag_columns(combined_df)

# -----------------------------------------------------------------------------
# Final check for issues
# -----------------------------------------------------------------------------

# --- check for exact duplicates ---
# Export exact duplicates for review
df_mask = combined_df.is_duplicated()
df_dup = combined_df.filter(df_mask)
file_name = qc_folder / 'exact_duplicate_check.csv'
df_dup.write_csv(file_name)

# Handle exact duplicates (Remove extra entries, leaving only one)
combined_df = util.handle_exact_duplicates(combined_df)
#various other exact duplicates (~10) but none are uniquely tagged (e.g., green square/etc.). Can safely ignore

# Confirm no more exact duplicates
df_mask = combined_df.is_duplicated()
df_dup = combined_df.filter(df_mask)
file_name = qc_folder / 'exact_duplicate_check_confirm.csv'
df_dup.write_csv(file_name)

# --- Check for tag duplicates on same occasion ---
# Export for review
df_mask = combined_df.select(['Tag Color', 'Tag Number', 'sampling_occasion']).is_duplicated()
df_dup = combined_df.filter(df_mask).filter(pl.col('Tag Number').is_not_null() & (pl.col('Tag Number') != 'Square')).sort('Tag Number')
file_name = qc_folder / 'individual_duplicate_check.csv'
df_dup.write_csv(file_name)

# Handle tag duplicates on same occasion 
combined_df = util.handle_tag_duplicates(combined_df)

# Confirm no more tag duplicates on same occasion 
df_mask = combined_df.select(['Tag Color', 'Tag Number', 'sampling_occasion']).is_duplicated()
df_dup = combined_df.filter(df_mask).filter(pl.col('Tag Number').is_not_null() & (pl.col('Tag Number') != 'Square')).sort('Tag Number')
file_name = qc_folder / 'individual_duplicate_check_confirm.csv'
df_dup.write_csv(file_name)

# =============================================================================
# 4. Export cleaned occasion data
# =============================================================================

# -----------------------------------------------------------------------------
# Export for final QC check
# -----------------------------------------------------------------------------

# Save combined data to file for manual review
file_name = qc_folder_final_data / 'qc_combined_occasions.csv'
combined_df.write_csv(file_name)

# -----------------------------------------------------------------------------
# Export for Pipeline
# -----------------------------------------------------------------------------

# Save combined data to pipeline
file_name = pipeline_folder / '02_combined_occasions.csv'
combined_df.write_csv(file_name)