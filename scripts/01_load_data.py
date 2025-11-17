import chincheron_util.file_util as file_util
import pandas as pd
import polars as pl

root_folder = file_util.find_repository_root()

df = pl.read_excel(root_folder / "01_data/Bentonville Data MR 2024.xlsx", sheet_name = "Summary")

## Pare down irrelevant rows/columns

#filter out Summary rows

df = df.filter(pl.col("Facility").is_not_null())

#check species found
df["Species"].unique().to_list()

# Sheet contains various summary statistics to right of data
# remove these
no_col_to_keep = 14 # keep first 14 columns (the data)
col_to_remove = df.columns[14:] # list of column names to remove
df = df.drop(col_to_remove) # remove columns

df.write_csv("temp.csv")