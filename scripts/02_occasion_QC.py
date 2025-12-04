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

mr1 = pl.read_csv(mr_1_file)
mr2 = pl.read_csv(mr_2_file)
mr3 = pl.read_csv(mr_3_file)
mr4 = pl.read_csv(mr_4_file)

#load and basic cleaning of each occasion
# (separate Tag types into dedicated columns, standardize PIT tag numbers)
mr1 = util.load_mr_occasion(mr1)
mr2 = util.load_mr_occasion(mr2)
mr3 = util.load_mr_occasion(mr3)
mr4 = util.load_mr_occasion(mr4)

### combine occasions into one
#list of occasions to run
list = [mr1, mr2, mr3, mr4]

combined_df = pl.DataFrame()
for index, df in enumerate(list):
    df = df.with_columns(sampling_occasion=index+1
    )
    combined_df = pl.concat([combined_df, df], how="diagonal")

###

#check non hallprint/Pit tag
df_unknown_tag  = mr1.filter((pl.col('Tag_type_standard') != 'Hallprint') & (pl.col('Tag_type_standard') != 'PIT'))

#load each occasion and flag QC issues

