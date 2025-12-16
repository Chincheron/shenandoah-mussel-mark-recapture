import chincheron_util.file_util as file_util
from config.paths import DATA_RAW, RESULTS_TABLES, RESULTS_TEMP, DATA_INTERIM, ROOT, DATA_PIPELINE
import polars as pl
from pathlib import Path
import src.util as util
import csv
import pandas as pd

#set folder locations
occasion_source_file = DATA_PIPELINE / '02_combined_occasions.csv'
summary_source_file = DATA_PIPELINE / '01_Summary.csv'
qc_output_folder_name = DATA_INTERIM / 'QC_03'
qc_output_path = DATA_INTERIM / qc_output_folder_name
output_path = DATA_PIPELINE
file_util.make_directory(qc_output_path)

# Load occasion data
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
occasion_df = pl.read_csv(occasion_source_file, columns=columns_to_load)

## collapse into single line for each mussel
#TODO multiple results per occasion must be handled before this step

#convert single occasion column into dummy variable columns
occasion_df = occasion_df.to_dummies(columns='sampling_occasion')

#grouping columns
group_col = [
    'Tag Color',
    'Hallprint_tag_no_1',
    'Hallprint_tag_no_2',
    'PIT_tag_no'
]
#count of unique mussels
unique_count = occasion_df.group_by(group_col).len().sort('len')

#confirm only one species per group

# group by tags
occasion_group_df = (
    occasion_df
    .group_by(group_col)
    .agg(pl.col('Species').first(),
    pl.col('Length').max().alias('max_length'),
    pl.col(f'sampling_occasion_1').first(),
    pl.col(f'sampling_occasion_2').first(),
    pl.col(f'sampling_occasion_3').first(),
    pl.col(f'sampling_occasion_4').first()
    )
)

#load cleaned summary data
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
 'A or D' 
]
summary_df = pl.read_csv(summary_source_file, columns=columns_to_load)

#join occasion to summary
#TODO account for tag numbers being in different olumns (e.g., F267 in tag # 1 column for MR but tag#2 col for rrelease data)
#second tag number not included becasue summary file using PIT tag for tag number 2 and some 2nd tags are missing compared to later encounters
left_join_col = [
    'Tag color', 'Tag 1 #', 'PIT Tag ID'
]
right_join_col =[
    'Tag Color', 'Hallprint_tag_no_1', 'PIT_tag_no'
]
join_df = summary_df.join(
    occasion_group_df, 
    left_on=left_join_col, 
    right_on=right_join_col,
    how='left'
)

#Various QC to be done here (compare tag number/color mismatch, different encounter histories, etc.)
#make sure all from right table are joining 


#occasion - Create unique ID column for each mussel
join_df = join_df.with_row_index(name='ID', offset=1)

#no nulls for encounter hisotyr (eihter 1 or 0)

#clean up columns

#export for mark-recapture analysis preparation
join_df.write_csv(output_path / '03_cleaned_data.csv')
