import chincheron_util.file_util as file_util
from config.paths import DATA_RAW, RESULTS_TABLES, RESULTS_TEMP, DATA_INTERIM
import polars as pl
from pathlib import Path

data_file = DATA_RAW / "Bentonville Data MR 2024.xlsx"
### 01. load summary data
df_summary = pl.read_excel(data_file, sheet_name = "Summary")

## Pare down irrelevant rows/columns

#Data was separated with a summary row for each species. 
# Filter out and combine data
# Cardium was summarized in two separate groups (black glitter and all others)
# Cardium was combined for all further analyses
df_summary = df_summary.filter(pl.col("Facility").is_not_null()) # summary rows were all null for Facility field

#check species found
df_summary["Species"].unique().to_list()

# Sheet contains various summary statistics to right of data
# remove these
no_col_to_keep = 14 # keep first 14 columns (the data)
col_to_remove = df_summary.columns[14:] # list of column names to remove
df_summary = df_summary.drop(col_to_remove) # remove columns

### 02. Load each occasion's raw data
df_1 = pl.read_excel(data_file, sheet_name = "Mark Recapture #1", read_options={"header_row": 8})
df_2 = pl.read_excel(data_file, sheet_name = "Mark Recapture #2", read_options={"header_row": 9})
df_3 = pl.read_excel(data_file, sheet_name = "Mark Recapture #3", read_options={"header_row": 9})
df_4 = pl.read_excel(data_file, sheet_name = "Mark Recapture #4", read_options={"header_row": 8})


# write resulting data sets to separate csv files for confirming that all QC issues found by Ellie are handled appropriately 
ellie_folder = Path("Ellie_QC_check")
file_util.make_directory(DATA_INTERIM / ellie_folder)
qc_folder = DATA_INTERIM / ellie_folder

df_summary.write_csv(qc_folder / "Summary.csv")
df_1.write_csv(qc_folder / "Occasion_1.csv")
df_2.write_csv(qc_folder / "Occasion_2.csv")
df_3.write_csv(qc_folder / "Occasion_3.csv")
df_4.write_csv(qc_folder / "Occasion_4.csv")