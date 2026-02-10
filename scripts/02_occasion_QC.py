import chincheron_util.file_util as file_util
from config.paths import DATA_INTERIM, DATA_PIPELINE
import polars as pl
from pathlib import Path
import src.util as util

###

#Overall purpose is to do first pass to ID QC issues for each occasion to be fixed in next step

### 
#set folder locations
source_folder = 'Ellie_QC_check'
output_folder_name = Path('QC_check')
output_path = DATA_INTERIM / output_folder_name
file_util.make_directory(output_path)

# Load data
mr_1_file = DATA_INTERIM / source_folder / 'Occasion_1.csv'
mr_2_file = DATA_INTERIM / source_folder / 'Occasion_2.csv'
mr_3_file = DATA_INTERIM / source_folder / 'Occasion_3.csv'
mr_4_file = DATA_INTERIM / source_folder / 'Occasion_4.csv'

mr1 = pl.read_csv(mr_1_file)
mr2 = pl.read_csv(mr_2_file)
mr3 = pl.read_csv(mr_3_file)
mr4 = pl.read_csv(mr_4_file)

# combine occasions into one
#list of occasions to run
list = [mr1, mr2, mr3, mr4]
combined_df = pl.DataFrame()
for index, df in enumerate(list):
    df = df.with_columns(sampling_occasion=index+1
    )
    combined_df = pl.concat([combined_df, df])

## Generate file of unique values to determine first round of QC
qc_unique_values_file_name = 'unique_values.xlsx'
util.qc_unique_values(combined_df, output_path, qc_unique_values_file_name)

### Basic cleaning of original columns for each occasion 
# Based on unique values, standardize spellings and PIT tag numbers of original columns)
combined_df = util.clean_original_columns(combined_df)

#TODO - fix E602/E604 tag
### Minor corrections to data (see documentation and/or function for details)
combined_df = util.correct_original_values(combined_df)

combined_df.filter(pl.col('Tag Number') == 'R194')

combined_df.filter(pl.col('Tag Number') == 'E194')


### Fix issue with 15 PIT numbers only including last four digits for occasion 2
# This was causing these individuals to not match other occasions
combined_df = util.fix_PIT_values(combined_df)

### Fix issue with inconsistent orange/red tags
# All A. varicosa with 'Red' FXXX tags changed to 'Orange'
combined_df = util.fix_varicosa_color(combined_df)

# Confirm all values are standardized
qc_unique_values_confirm_file_name = 'unique_values_confirm.xlsx'
util.qc_unique_values(combined_df, output_path, qc_unique_values_confirm_file_name)

# make sure that tag numbers are in order
combined_df = util.order_tag_numbers(combined_df)

#fix unmatched records issues
combined_df = util.correct_unmatched_records(combined_df)

combined_df.filter(pl.col('Tag Number') == 'R528')

combined_df.filter(pl.col('Tag Number') == 'R459')

#Make tag numbers all cap
combined_df = combined_df.with_columns(
    pl.col('Tag Number').str.to_uppercase(),
    pl.col('Tag Number 2').str.to_uppercase()
)

### Create new columns for tag numbers split by type
combined_df = util.add_tag_columns(combined_df)

### Check for issues

## check for exact duplicates
df_mask = combined_df.is_duplicated()
df_dup = combined_df.filter(df_mask)
file_name = output_path / 'exact_duplicate_check.csv'
df_dup.write_csv(file_name)

#deal with exact duplicates
combined_df = util.handle_exact_duplicates(combined_df)
#various other exact duplicates (~10) but none are individually identified by tag (e.g., green square/etc.). Can safely ignore

#confirm exact duplicates dealt with
df_mask = combined_df.is_duplicated()
df_dup = combined_df.filter(df_mask)
file_name = output_path / 'exact_duplicate_check_confirm.csv'
df_dup.write_csv(file_name)

## check for tag duplicates on each occasion and deal with
df_mask = combined_df.select(['Tag Color', 'Tag Number', 'sampling_occasion']).is_duplicated()
df_dup = combined_df.filter(df_mask).filter(pl.col('Tag Number').is_not_null() & (pl.col('Tag Number') != 'Square')).sort('Tag Number')
file_name = output_path / 'individual_duplicate_check.csv'
df_dup.write_csv(file_name)

# Deal with tag duplicates
# TODO Some tag dupicates still remaining (e.g., E310, E742) crosscheck with Ellie QC files as final check
combined_df = util.handle_tag_duplicates(combined_df)

#confirm tag duplicates dealt with
df_mask = combined_df.select(['Tag Color', 'Tag Number', 'sampling_occasion']).is_duplicated()
df_dup = combined_df.filter(df_mask).filter(pl.col('Tag Number').is_not_null() & (pl.col('Tag Number') != 'Square')).sort('Tag Number')
file_name = output_path / 'individual_duplicate_check_confirm.csv'
df_dup.write_csv(file_name)

#TODO update tag that likely fell off with the second tag based on release data (and order appropriatley for joining)
## write combined data to file for manual review
file_name = output_path / 'combined_QC.csv'
combined_df.write_csv(file_name)

##write final data to file for further cleanup/analysis
file_name = DATA_PIPELINE / '02_combined_occasions.csv'
combined_df.write_csv(file_name)