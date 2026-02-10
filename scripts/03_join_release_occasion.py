import chincheron_util.file_util as file_util
from config.paths import DATA_INTERIM, DATA_PIPELINE
import polars as pl
import src.util as util

### Purpose: join occasion data and release data together for final conversion into MARK format; includes additional QC


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

## exclude non-individually identifiable mussels 
#include only Mussels with valid tag colors OR PIT tag no. 
tag_color_list = ['Yellow', 'Green', 'Red', 'Orange']
occasion_df = occasion_df.filter(
    ((pl.col('Tag Color').is_in(tag_color_list)) |
    (pl.col('PIT_tag_no').is_not_null())
    )
)

# Two PIT tags were detected, but mussels were not found. Exlude these
occasion_df = occasion_df.filter(
    ~(pl.col('Tag Color') == 'NO MUSSEL')
)

#Exclude invalid tag numbers (also excludes null values for tag 1 column)
invalid_tag_number = ['SQUARE', 'NO TAG', 'GLUE DOT']
occasion_df = occasion_df.filter(
    ~(pl.col('Hallprint_tag_no_1').is_in(invalid_tag_number))
)

## collapse into single line for each mussel
#TODO multiple results per occasion must be handled before this step

#convert single occasion column into dummy variable columns
occasion_df = occasion_df.to_dummies(columns='sampling_occasion')

#Change encounter history to A/D
occasion_df = util.encounter_to_AD(occasion_df)

#grouping columns
group_col = [
    'Tag Color',
    'Hallprint_tag_no_1',
    'Hallprint_tag_no_2',
    'PIT_tag_no'
]
#count of unique mussels
#TODO this count (597) does not match count from raw summary (~533 with encounter history) confrim why
unique_count = occasion_df.group_by(group_col).len().sort('len')

#confirm only one species per group
#TODO calculate separate 'Average' length column and decide which to use later
# group by tags
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
#check - should have 586 records after combining (2/10/26)


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
 'Sum value',
 'A or D' 
]
summary_df = pl.read_csv(summary_source_file, columns=columns_to_load)

#remove \r and \n values from headings to avoid issues later when writing to csv
summary_df = summary_df.rename(
    lambda c: c.replace('\r\n', ' ').strip()
)

summary_df = summary_df.rename({'Measurement (mm) when released': 'release_length', 'Measurement (mm) when last found': 'sample_length'})

#join occasion to summary
#second tag number not included becasue summary file using PIT tag for tag number 2 and some 2nd tags are missing compared to later encounters
left_join_col = [
    'Tag color', 'Tag 1 #'#, 'PIT Tag ID'
]
right_join_col =[
    'Tag Color', 'Hallprint_tag_no_1'#, 'PIT_tag_no'
]

#somewhere here need to cross compare tag1/2 to tag 2/1 (for records where occasion data is missing a second tag and is in wrong column)
#where to place in order and how to fit in with unmatched?



#QC - find unmatched records from MR occasions (i.e., records that could not be joined to release data )

unmatched_occasion_df = occasion_group_df.join(
    summary_df,
    left_on=right_join_col,
    right_on=left_join_col,
    how="anti"
)
#write to csv for review
file_name = qc_output_path / 'unmatched_occasions_records.csv'
#TODO - finish manually reviewing and updating correction script in util for each mussel
unmatched_occasion_df.write_csv(file_name)

#actual join of raw summary and processed occasion data
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
#TODO - handle sampled lengths smaller than release

#export for mark-recapture analysis preparation
join_df.write_csv(output_path / '03_cleaned_data.csv')
