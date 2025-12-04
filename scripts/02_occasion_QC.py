import chincheron_util.file_util as file_util
from config.paths import DATA_RAW, RESULTS_TABLES, RESULTS_TEMP, DATA_INTERIM
import polars as pl
from pathlib import Path
import src.util as util

###

#Overall purpose is to do first pass to ID QC issues for each occasion to be fixed in next step

### 
# Load data
source_folder = 'Ellie_QC_check'

mr_1_file = DATA_INTERIM / source_folder / 'Occasion_1.csv'
mr_2_file = DATA_INTERIM / source_folder / 'Occasion_2.csv'
mr_3_file = DATA_INTERIM / source_folder / 'Occasion_3.csv'
mr_4_file = DATA_INTERIM / source_folder / 'Occasion_4.csv'

df_mr1 = pl.read_csv(mr_1_file)

### 
# Separate hallprint/Pit tag into distinct columns

#test values of Tag Type
df_mr1['Tag Type'].unique().to_list()

#create Hallprint tag 1 column
df_test = df_mr1.with_columns(
    pl.when(pl.col('Tag Type') == 'Hallprint')
    .then(pl.col('Tag Number'))
    .otherwise(pl.lit(None))
    .alias('Hallprint_tag_no_1')
    )

#create Hallprint tag 2 column
df_test = df_test.with_columns(
    pl.when(pl.col('Tag Type') == 'Hallprint')
    .then(pl.col('Tag Number 2'))
    .otherwise(pl.lit(None))
    .alias('Hallprint_tag_no_2')
    )

#create Pit Tag column
df_test = df_test.with_columns(
    pl.when(pl.col('Tag Type') == 'Pit tag')
    .then(pl.col('Tag Number 2'))
    .otherwise(pl.lit(None))
    .alias('PIT_tag_no')
    )

#Set Hallprint tag column when there is a PIT tag
df_test = df_test.with_columns(
    pl.when(pl.col('Tag Type') == 'Pit tag')
    .then(pl.col('Tag Number'))
    .otherwise(pl.col('Hallprint_tag_no_1'))
    .alias('Hallprint_tag_no_1')
    )

# There is an issue with some PIT tag numbers being out of order
# (e.g., 3D9.1A4FAAB2F3 on MR1 and B2F33D9.1A4FAA on subsequent occasions)
# Standardize Pit tag to Bi-hex display such that there are 3 digits before the period (3D9.1A4FAAB2F3)
df_test = df_test.with_columns(
    pl.col('PIT_tag_no')
    .map_elements(util.standardize_PIT)
    .alias('PIT_tag_no')
)    


#check non hallprint/Pit tag
df_unknown_tag  = df_test.filter((pl.col('Tag Type') == 'Untagged') | (pl.col('Tag Type') == 'Unknown'))

#load each occasion and flag QC issues

