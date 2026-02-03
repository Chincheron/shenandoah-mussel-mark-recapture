import chincheron_util.file_util as file_util
from config.paths import DATA_RAW, DATA_INTERIM, DATA_PIPELINE
import polars as pl
from pathlib import Path
import src.util as util

qc_folder = DATA_INTERIM / Path('QC_check')
file_util.make_directory(qc_folder)
data_file = DATA_RAW / "Bentonville Data MR 2024.xlsx"
### 01. load summary data
df_summary = pl.read_excel(data_file, sheet_name = "Summary")

## Pare down irrelevant rows/columns

#Data was separated with a summary row for each species. 
# Filter out and combine data
# Cardium was summarized in two separate groups (black glitter and all others)
# Cardium was combined for all further analyses
df_summary = df_summary.filter(pl.col("Facility").is_not_null()) # summary rows were all null for Facility field

# Sheet contains various summary statistics to right of data
# remove these
no_col_to_keep = 14 # keep first 14 columns (the data)
col_to_remove = df_summary.columns[14:] # list of column names to remove
df_summary = df_summary.drop(col_to_remove) # remove columns

#check unique values for each field
qc_summary_unique_file = 'summary_unique_values.xlsx'
util.qc_unique_values(df_summary, qc_folder, qc_summary_unique_file)

#check for exact duplicates
df_summary_dup = util.check_exact_duplicates(df_summary)

#filter out mussels that are not individually identifiable
df_summary = util.remove_summary_rows(df_summary)

# confirm no further data issues/ record removal
qc_summary_unique_confirm_file = 'summary_unique_values_confirm.xlsx'
util.qc_unique_values(df_summary, qc_folder, qc_summary_unique_confirm_file)
#confirm exact duplicates handled
df_summary_dup = util.check_exact_duplicates(df_summary)

# summary data includes a number of releases from FMCC on 10/17/24, shortly before the last occasion
# We are excluding these for analysis
#import page
#filter column to list
release_2024 = DATA_RAW / 'FMCC Tagged Mussels 2020-2025.xlsx'
sheet_name = '2024'
df_release = pl.read_excel(release_2024, sheet_name = sheet_name)
#filter nulls
df_release = df_release.filter(pl.col("Tagged Mussels September 2024").is_not_null()) # summary rows were all null for Facility field
#select tag numbers
df_release = df_release.select(pl.col('__UNNAMED__2'))
df_release = df_release.to_series(0)
df_release = df_release.to_list()
len(df_release)
df_summary = df_summary.filter(~pl.col('Tag 1 #').is_in(df_release))
# NOTE abandon current approach. Just need to pull release data for all mussels
# or perhaps abandon current summary and just pull directlyf rom release data?


### 02. Load each occasion's raw data
df_1 = pl.read_excel(data_file, sheet_name = "Mark Recapture #1", read_options={"header_row": 8})
df_2 = pl.read_excel(data_file, sheet_name = "Mark Recapture #2", read_options={"header_row": 9})
df_3 = pl.read_excel(data_file, sheet_name = "Mark Recapture #3", read_options={"header_row": 9})
df_4 = pl.read_excel(data_file, sheet_name = "Mark Recapture #4", read_options={"header_row": 8})

### 03.Get all occasions into same data schema

#There is no status column in MR1. Add and rearrange to same order
df_1 = df_1.with_columns(pl.lit(None).cast(pl.String).alias('Status'))

#Status column in MR4 is unnamed. Rename to match other MRs
df_4 = df_4.rename({"Column1": "Status"})

## ensure all columns are ordered the same

#list of dataframes
df_list = [df_1, df_2, df_3, df_4]
#list of columns
cols = ['Species',
        'Tag Type',
        'Tag Color',
        'Tag Number',
        'Tag Number 2',
        'Length',
        'Status',
        'Other Tag Attribute'
        ]
        
#reorder
df_list = [df.select(cols) for df in df_list]

df_1, df_2, df_3, df_4 = df_list

# write resulting data sets to separate csv files for confirming that all QC issues found by Ellie are handled appropriately 
ellie_folder = Path("Ellie_QC_check")
file_util.make_directory(DATA_INTERIM / ellie_folder)
qc_folder = DATA_INTERIM / ellie_folder

df_summary.write_csv(qc_folder / "Summary.csv")
df_1.write_csv(qc_folder / "Occasion_1.csv")
df_2.write_csv(qc_folder / "Occasion_2.csv")
df_3.write_csv(qc_folder / "Occasion_3.csv")
df_4.write_csv(qc_folder / "Occasion_4.csv")

# write to pipeline
df_summary.write_csv(DATA_PIPELINE / '01_Summary.csv')