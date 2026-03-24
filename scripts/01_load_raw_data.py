'''
Script: 01_load_raw_data.py

Purpose: Load raw summary and mark-recapture data for initial cleaning and standardization.

Inputs:
- Bentonville Data MR 2024.xlsx (summary data of 2023 release cohorts and sampling data for each 
        mark-recapture occasion in 2024)
- FMCC Tagged Mussels 2020-2025.xlsx (FMCC release data from multiple years)

Outputs:
- Pipeline:
   - Cleaned summary dataset
   - Standardized MR occasion datasets
- Various QC files

'''
# =============================================================================
# 1. Setup 
# =============================================================================

# -----------------------------------------------------------------------------
# Imports and Constants
# -----------------------------------------------------------------------------

import chincheron_util.file_util as file_util
from config.paths import DATA_RAW, DATA_INTERIM, DATA_PIPELINE
import polars as pl
from pathlib import Path
import src.util as util


# -----------------------------------------------------------------------------
# Paths and import/export directories
# -----------------------------------------------------------------------------

# set directories 
SCRIPT_NAME = '01_load_raw_data'
qc_folder = DATA_INTERIM / SCRIPT_NAME / Path('QC')
qc_folder_final_data = qc_folder / Path('final_qc')
pipeline_folder = DATA_PIPELINE / SCRIPT_NAME


# make directories
file_util.make_directory(qc_folder)
file_util.make_directory(qc_folder_final_data)
file_util.make_directory(pipeline_folder)

# =============================================================================
# 2. Load and clean summary data
# =============================================================================

# -----------------------------------------------------------------------------
# Load summary data
# -----------------------------------------------------------------------------

summary_file_path = DATA_RAW / "Bentonville Data MR 2024.xlsx"
df_summary = pl.read_excel(summary_file_path, sheet_name = "Summary")

# -----------------------------------------------------------------------------
# Remove irrelevant rows/columns
# -----------------------------------------------------------------------------

# Data was separated with a blank summary row for each species. 
# Removed summary rows (identified by Null facility field)
df_summary = df_summary.filter(pl.col("Facility").is_not_null()) 

# Sheet contains various summary statistics to right of data
# removed these
no_col_to_keep = 14 # keep first 14 columns (the data)
col_to_remove = df_summary.columns[14:] # list of column names to remove
df_summary = df_summary.drop(col_to_remove) # remove columns

# Cleanup
del(no_col_to_keep, col_to_remove)

# -----------------------------------------------------------------------------
# Initial QC check of summary data
# -----------------------------------------------------------------------------

# check unique values for each field and save to excel for review
qc_summary_uniques_file_name = 'summary_unique_values.xlsx'
util.qc_unique_values(df_summary, qc_folder, qc_summary_uniques_file_name)

# check for exact duplicates and save to csv for review
df_summary_dup = util.check_exact_duplicates(df_summary)
summary_dup_file_path = qc_folder / Path('summary_exact_duplicates.csv')
df_summary_dup.write_csv(summary_dup_file_path)

#filter out mussels that are not individually identifiable
df_summary = util.remove_non_unique_mussel_rows(df_summary)

# confirm no further data issues with unique values
qc_summary_uniques_confirm_file_name = 'summary_unique_values_confirm.xlsx'
util.qc_unique_values(df_summary, qc_folder, qc_summary_uniques_confirm_file_name)
#confirm exact duplicates handled
df_summary_dup_confirm = util.check_exact_duplicates(df_summary)
summary_dup_file_path_confirm = qc_folder / Path('summary_exact_duplicates_confirm.csv')
df_summary_dup_confirm.write_csv(summary_dup_file_path_confirm)

#cleanup workspace
del(df_summary_dup, df_summary_dup_confirm, qc_summary_uniques_confirm_file_name, qc_summary_uniques_file_name, summary_dup_file_path, summary_dup_file_path_confirm)

# -----------------------------------------------------------------------------
# Additional cleanup of summary data
# -----------------------------------------------------------------------------

# summary data inadvertently includes a number of releases from FMCC on 10/17/24 at another site
# Excluded from further analysis

#get list of 2024 tags to exclude
release_2024_file_path = DATA_RAW / 'FMCC Tagged Mussels 2020-2025.xlsx'
sheet_name = '2024'
df_release = pl.read_excel(release_2024_file_path, sheet_name = sheet_name)
# Remove summary rows
df_release = df_release.filter(pl.col("Tagged Mussels September 2024").is_not_null()) # summary rows were all null for Facility field
# Select tag number columns
df_release = df_release.select(pl.col('__UNNAMED__2'))
df_release = df_release.to_series(0)
df_release = df_release.to_list()
# Remove 2024 tagged cohort from summary data
df_summary = df_summary.filter(~pl.col('Tag 1 #').is_in(df_release))

# Cleanup
del(df_release, release_2024_file_path, sheet_name)

# =============================================================================
# 3. Load and clean occasion data
# =============================================================================

# -----------------------------------------------------------------------------
# Load each occasion's raw data
# -----------------------------------------------------------------------------

mr_1 = pl.read_excel(summary_file_path, sheet_name = "Mark Recapture #1", read_options={"header_row": 8})
mr_2 = pl.read_excel(summary_file_path, sheet_name = "Mark Recapture #2", read_options={"header_row": 9})
mr_3 = pl.read_excel(summary_file_path, sheet_name = "Mark Recapture #3", read_options={"header_row": 9})
mr_4 = pl.read_excel(summary_file_path, sheet_name = "Mark Recapture #4", read_options={"header_row": 8})

# -----------------------------------------------------------------------------
# Convert all occasions into a common data schema
# -----------------------------------------------------------------------------

# There is no status column in MR1. Add and rearrange to same order
mr_1 = mr_1.with_columns(pl.lit(None).cast(pl.String).alias('Status'))

# Status column in MR4 is unnamed. Rename to match other MRs
mr_4 = mr_4.rename({"Column1": "Status"})

# --- Ensure columns for all occasions are in the same order ---
# List of dataframes
df_list = [mr_1, mr_2, mr_3, mr_4]
# List of columns
cols = ['Species',
        'Tag Type',
        'Tag Color',
        'Tag Number',
        'Tag Number 2',
        'Length',
        'Status',
        'Other Tag Attribute'
        ]
# Reorder columns 
df_list = [df.select(cols) for df in df_list]
# Convert list of ordered dataframes to individual dataframes
mr_1, mr_2, mr_3, mr_4 = df_list

#cleanup
del(df_list)

# =============================================================================
# 4.Export summary and occasion data
# =============================================================================

# -----------------------------------------------------------------------------
# Export for final QC check
# -----------------------------------------------------------------------------

# Save each occasion and summary to csv for confirming that all QC issues found by Ellie and elsewhere are handled appropriately 
df_summary.write_csv(qc_folder_final_data / "Summary.csv")
mr_1.write_csv(qc_folder_final_data / "Occasion_1.csv")
mr_2.write_csv(qc_folder_final_data / "Occasion_2.csv")
mr_3.write_csv(qc_folder_final_data / "Occasion_3.csv")
mr_4.write_csv(qc_folder_final_data / "Occasion_4.csv")

# -----------------------------------------------------------------------------
# Export for Pipeline
# -----------------------------------------------------------------------------

# Write to pipeline 
df_summary.write_csv(pipeline_folder / '01_Summary.csv')
mr_1.write_csv(pipeline_folder / "Occasion_1.csv")
mr_2.write_csv(pipeline_folder / "Occasion_2.csv")
mr_3.write_csv(pipeline_folder / "Occasion_3.csv")
mr_4.write_csv(pipeline_folder / "Occasion_4.csv")
