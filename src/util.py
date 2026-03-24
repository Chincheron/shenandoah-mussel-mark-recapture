import polars as pl
import src.util as util
import pandas as pd

def standardize_PIT(x):
    position = x.find('.')
    if position != 3:
        prefix_string = x[position-3:position]
        before_prefix = x[0:position-3]
        period_string = x[position:]
        final_string = prefix_string + period_string + before_prefix
        return final_string
    else:
        return(x)

def clean_original_columns(df):
    # Standardize species names
    column_name = 'Species'
    mapping = {
        'E. fisheriana': 'Elliptio fisheriana',
        'A. varicosa': 'Alasmidonta varicosa',
        'L. cardium': 'Lampsilis cardium',
        'L. Cardium': 'Lampsilis cardium',
        'E. complanata': 'Elliptio complanata',
        'Ellipto complanata': 'Elliptio complanata'
    }
    df = df.with_columns(pl.col(column_name).replace(mapping))

    # Standardize Tag Type names
    column_name = 'Tag Type'
    mapping = {
        'Untagged': 'No tag',
        'Pit tag': 'PIT'
    }
    df = df.with_columns(pl.col(column_name).replace(mapping))

    # Standardize Tag Color names
    column_name = 'Tag Color'
    mapping = {
        'GREEN': 'Green',
        'green': 'Green',
        'G': 'Green',
        'Untagged': 'No tag',
        None: 'No tag'
    }
    df = df.with_columns(pl.col(column_name).replace(mapping))

    # Standardize Status names
    column_name = 'Status'
    mapping = {
        'DEAD': 'Dead',
        'ALIVE': 'Alive'
    }
    df = df.with_columns(pl.col(column_name).replace(mapping))

    #for checking that uniques are properly removed 
    # uniques = df[column_name].unique().to_list()
    # print(uniques)

    # Fix PIT tag issue - standardize to Bi-hex display such that there are 3 digits before the period (3D9.1A4FAAB2F3) 
    # Some PIT tag numbers are out of order # (e.g., 3D9.1A4FAAB2F3 on MR1 and B2F33D9.1A4FAA on subsequent occasions)
    column_name = 'Tag Number 2'
    df = df.with_columns(
        pl.when(pl.col('Tag Type').str.contains('PIT'))
        .then(pl.col(column_name)
        .map_elements(standardize_PIT)
        )
        .otherwise(pl.col(column_name))
    )    
    return df

def add_tag_columns(df):
    # Separate hallprint/Pit tag into distinct columns

    #create Hallprint tag 1 column
    df = df.with_columns(
        pl.when(pl.col('Tag Type').str.contains('(?i)hall'))
        .then(pl.col('Tag Number'))
        .otherwise(pl.lit(None))
        .alias('Hallprint_tag_no_1')
        )

    #create Hallprint tag 2 column
    df = df.with_columns(
        pl.when(pl.col('Tag Type').str.contains('(?i)hall'))
        .then(pl.col('Tag Number 2'))
        .otherwise(pl.lit(None))
        .alias('Hallprint_tag_no_2')
        )

    #create Pit Tag column
    df = df.with_columns(
        pl.when(pl.col('Tag Type').str.contains('(?i)Pit')) # ('(?i)' is included to ignore capitalization (inline flag for regex))
        .then(pl.col('Tag Number 2'))
        .otherwise(pl.lit(None))
        .alias('PIT_tag_no')
        )

    #Set Hallprint tag column when there is a PIT tag
    df = df.with_columns(
        pl.when(pl.col('Tag Type').str.contains('(?i)Pit'))
        .then(pl.col('Tag Number'))
        .otherwise(pl.col('Hallprint_tag_no_1'))
        .alias('Hallprint_tag_no_1')
        )

    # #standardize spelling of tag type
    # df = df.with_columns(
    #     pl.when(pl.col('Tag Type').str.contains('(?i)Pit'))
    #     .then(pl.lit('PIT'))
    #     .when(pl.col('Tag Type').str.contains('(?i)hall'))
    #     .then(pl.lit('Hallprint'))
    #     .otherwise(pl.col('Tag Type'))
    #     .alias('Tag_type_standard')
    # )    

    return(df)

def get_unique_values(df):
    #  get unique values for each header
    headers = df.columns
    # generate dictionary of unique values for each column
    unique_dict = {}
    for header in headers:
        uniques = df[header].unique().to_list()
        unique_dict[header] = uniques
    return unique_dict

def write_unique_values(df, file_name):
    with pd.ExcelWriter(file_name, engine='openpyxl') as writer: # need to use pandas for easier writing to excel
        for key, values in df.items():
            sheet_name = str(key)[:31]
            df_key = pd.DataFrame({key:values})
            df_key.to_excel(writer, sheet_name=sheet_name, index=False)
    
def correct_original_values(df):
     # Correct mistyped tab number
    tag_1 = 'Tag Number'
    tag_2 = 'Tag Number 2'
    mapping_tag1 = {
        'A3439': 'A343',
        'F3392': 'F392', # based on matching PIT tag no with release data
        }
    mapping_tag2 = {
        'F2546': 'F246',
        'R5621': 'E621',
        'B31D': '3D9.1A4FAAB31D'
        }
    df = df.with_columns(pl.col(tag_1).replace(mapping_tag1))
    df = df.with_columns(pl.col(tag_2).replace(mapping_tag2))


    df = df.with_columns(
        pl.when((pl.col(tag_1) == 'B164') & (pl.col(tag_2) == 'B164'))
        .then(pl.lit('B163'))
        .otherwise(pl.col(tag_1))
        .alias(tag_1)
        )
    
    #Tag likely mistyped. Changed to values below based on release data and lengths at release/sampling
    df = df.with_columns(
        pl.when((pl.col(tag_1) == 'E507') & (pl.col(tag_2) == 'E508'))
        .then(pl.lit('E506'))
        .otherwise(pl.col(tag_1))
        .alias(tag_1)
    )

    #Tag likely mistyped. Changed to values below based on release data and lengths at release/sampling
    df = df.with_columns(
        pl.when((pl.col(tag_1) == 'E886') & (pl.col(tag_2) == 'E881'))
        .then(pl.lit('E887'))
        .otherwise(pl.col(tag_2))
        .alias(tag_2)
    )

    ##Several instances where PIT ID is wrong for some MR observations. Updated based on release data
    corrections = pl.DataFrame({
        tag_1: ['F176', 'F177', 'F386', 'F390', 'F391', 'F395', 'F403'],
        tag_2: ['3D9.1A4FAAB20D', '3D9.1A4FAAB2F2', '3D9.1A4FAAB2FE8', '3D9.1A4FAAF829', 
        '3D9.1A4FAAB3OC', None, '3D9.1A4FAAB300F'
        ],
        'tag_2_corrected': ['3D9.1A4FAAB30D', '3D9.1A4FAAB2FE', '3D9.1A4FAAB2E8', '3D9.1A4FAAB301',
        '3D9.1A4FAAB30C', '3D9.1A4FAAB306', '3D9.1A4FAAB30F'
        ]
    })
    # fix values with no nulls on lookup (can't join on null values)
    df = (
        df
        .join(corrections, on=[tag_1, tag_2], how='left')
        .with_columns(
            pl.coalesce(pl.col('tag_2_corrected'), pl.col(tag_2))
            .alias(tag_2)
        )
        .drop('tag_2_corrected')
    )
    #fix values with nulls
    df = df.with_columns(
    pl.when(
        (pl.col(tag_1) == 'F395') & pl.col(tag_2).is_null()
    )
    .then(pl.lit('3D9.1A4FAAB306'))
    .otherwise(pl.col(tag_2))
    .alias(tag_2)
    )


    return df

def fix_PIT_values(df):
    fix_list = [
        'B316',
        'B30C',
        'B30F',
        'B2D8',
        'B2EA',
        'B2F2',
        'B2D5',
        'B31C',
        'B313',
        'B2EE',
        'B2F3',
        'B2CF',
        'B325',
        'B323',
        'B2F0'
    ]
    prefix = '3D9.1A4FAA'
    new_list = [prefix + item for item in fix_list]
    
    # Correct values
    column_name = 'Tag Number 2'
    mapping = {old:new for old, new in zip(fix_list, new_list)}
    print(mapping)
    df = df.with_columns(pl.col(column_name).replace(mapping))
    return df

def fix_varicosa_color(df):
    update_column = 'Tag Color'
    df = df.with_columns(
        pl.when(
            (pl.col('Species') == 'Alasmidonta varicosa') 
            & (pl.col('Tag Color') == 'Red')
            & pl.col('Tag Number').str.starts_with('F'))
        .then(pl.col(update_column).replace('Red', 'Orange'))
        .otherwise(pl.col(update_column))
        )
    return df

def handle_tag_duplicates(df):
    ## remove the row where length is least likely to be correct compared to release length
    tag_list = [
    'B225',
    'B249',
    'E442',
    'E820',
    'F186',
    'F187',
    'F231',
    'F249',
    'F268',
    'F377',
    'F440',
    'F450',
    'F502',
    'F512'  
    ]
    #lengths to remove
    length_list =[
        58.6,
        71.9,
        70,
        61,
        54.3,
        46.3,
        56.4,
        57.7,
        43.1,
        50,
        49.9,
        48,
        40.8,
        43.1
    ]
    #dictionary of paired values to remove
    delete_df = pl.DataFrame({'Tag Number': tag_list, 'Length': length_list})
    #filter out rows where paired values match
    df = df.join(
        delete_df,
        on=['Tag Number', 'Length'],
        how='anti'
    )

    ## deal with remaining duplicates where lengths were identical or very close
    tag_list = [
    'E754',
    'E848',
    'E885',
    'F319',
    'F504',
    'F512'  
    ]
    occasion_list = [
        4, 1, 4, 1, 4, 1
    ]
    #dictionary of paired values to remove
    pairs_df = pl.DataFrame({'Tag Number': tag_list, 'sampling_occasion': occasion_list})
    #pull rows to be averaged
    to_average = df.join(
        pairs_df,
        on=['Tag Number', 'sampling_occasion'],
        how='inner'
    )
    # average
    averaged_rows =(
        to_average
        .group_by(['Tag Number', 'sampling_occasion'])
        .agg(
            pl.first('Species'),
            pl.first('Tag Type'),
            pl.first('Tag Color'),
            pl.first('Tag Number 2'),
            pl.col('Length').mean(),
            pl.first('Status'),
            pl.first('Other Tag Attribute'),
            pl.first('Hallprint_tag_no_1'),
            pl.first('Hallprint_tag_no_2'),
            pl.first('PIT_tag_no')
        )
    )
    #order rows for rejoining
    columns_to_load = [
    'Species',
    'Tag Type',
    'Tag Color',
    'Tag Number',
    'Tag Number 2',
    'Length',
    'Status',
    'Other Tag Attribute',
    'sampling_occasion',
    'Hallprint_tag_no_1',
    'Hallprint_tag_no_2',
    'PIT_tag_no',
    ]
    averaged_rows = averaged_rows.select(columns_to_load)
     #filter out rows where paired values match
    df_removed = df.join(
        pairs_df,
        on=['Tag Number', 'sampling_occasion'],
        how='anti'
    )
    #append average
    df_final = pl.concat(
        [df_removed, averaged_rows],
        how='vertical'
    )   
    

    return df_final

def handle_exact_duplicates(df):
    tag_list = [
    'F504',
    'E885'
    ]
    #lengths to remove
    length_list =[
        46.2,
        64.7
    ]
    #dictionary of paired values to remove
    delete_df = pl.DataFrame({'Tag Number': tag_list, 'Length': length_list})
    #filter out unique rows where paired values match
    df_dup = df.join(
        delete_df,
        on=['Tag Number', 'Length'],
    )
    #filter out rows where paired values match
    df = df.join(
        delete_df,
        on=['Tag Number', 'Length'],
        how='anti'
    )
    #keep first unique
    df_keep = df_dup.unique(keep='first')
    #add one row back
    df_final = pl.concat(
    [df, df_keep],
    how='vertical'
    )   
    return df_final

def order_tag_numbers(df):
    tag_1 = 'Tag Number'
    tag_2 = 'Tag Number 2'
    no1 = 'tag_1_no'
    no2 = 'tag_2_no'

    df = df.with_columns(
        pl.col(tag_1).str.tail(-1).alias(no1),
        pl.col(tag_2).str.tail(-1).alias(no2) 
    )
    
    df = df.with_columns(
        (pl.when((pl.col(tag_2).is_null()))
        .then(pl.col(tag_1))
        .when((pl.col(no1) < pl.col(no2)))
        .then(pl.col(tag_1))
        .otherwise(pl.col(tag_2))
        .alias(tag_1)
        ),
        (pl.when((pl.col(tag_2).is_null()))
        .then(pl.col(tag_2))
        .when((pl.col(no1) < pl.col(no2)) & (pl.col(tag_2).is_not_null()))
        .then(pl.col(tag_2))
        .otherwise(pl.col(tag_1))
        .alias(tag_2)
        )
    ).drop(no1, no2)
    return df

def qc_unique_values(df, write_path, file_name):
    unique_df = util.get_unique_values(df)
    file_name = write_path / file_name
    util.write_unique_values(unique_df, file_name)

def remove_non_unique_mussel_rows(df):
    #Remove mussels that are not individually identifiable
    df = df.remove(pl.col('Tag 1 #') == 'No #') # 91 records
    df = df.remove(pl.col('Tag 1 #') == 'Untagged') # 30 records
    df = df.remove(pl.col('Tag color') == 'Black Glue') # 156 records
    
    return df

def check_exact_duplicates(df):
    df.filter(df.is_duplicated())
    df_dup = df.filter(df.is_duplicated())
    
    return df_dup

def encounter_to_AD(df):
    update_column = 'sampling_occasion_1'
    status_column = 'Status'
    df = df.with_columns(
        pl.when(
            (pl.col(status_column) == 'Dead') 
            & pl.col(update_column) == 1
        )
        .then(pl.lit('D'))
        .otherwise(pl.col(update_column))
        .alias(update_column)
    )

    update_column = 'sampling_occasion_2'
    status_column = 'Status'
    df = df.with_columns(
        pl.when(
            (pl.col(status_column) == 'Dead') 
            & pl.col(update_column) == 1
        )
        .then(pl.lit('D'))
        .otherwise(pl.col(update_column))
        .alias(update_column)
    )

    update_column = 'sampling_occasion_3'
    status_column = 'Status'
    df = df.with_columns(
        pl.when(
            (pl.col(status_column) == 'Dead') 
            & pl.col(update_column) == 1
        )
        .then(pl.lit('D'))
        .otherwise(pl.col(update_column))
        .alias(update_column)
    )

    update_column = 'sampling_occasion_4'
    status_column = 'Status'
    df = df.with_columns(
        pl.when(
            (pl.col(status_column) == 'Dead') 
            & pl.col(update_column) == 1
        )
        .then(pl.lit('D'))
        .otherwise(pl.col(update_column))
        .alias(update_column)
    )
    return df

def correct_unmatched_records(df):
# Corrections to issues found during unmatched records check 
    tag_1 = 'Tag Number'
    tag_2 = 'Tag Number 2'
    tag_color = 'Tag Color'
    corrections = pl.DataFrame({
        tag_1: ['R194', 'R528', 'R459', 'R746', 'R452', 'F469', 'E909', 'F246', 'F310', 'R536',
        'E201', 'E139', 'E663'],
        tag_2: ['E195', 'E529', 'E548', 'E747', 'E453', None, None, None, None, 'R537',
        None, 'E140', None
        ],
        'tag_1_corrected': [
            'E194', 'E528', 'E458', 'E746', 'E452', 'F468', 'E906', 'F245', 'F309', 'E536',
            'E200', 'B139', 'E662'
        ],
         'tag_2_corrected': [
            None, None, 'E459', None, None, 'F469', 'E909', 'F246', 'F310', 'E537', 'E201',
            'B140', 'E663'
         ]
    })
    # fix values with no nulls on lookup (can't join on null values)
    no_nulls_df = corrections.filter(pl.col(tag_2).is_not_null())
    df = (
        df
        .join(no_nulls_df, on=[tag_1, tag_2], how='left')
        .with_columns([
            pl.coalesce(pl.col('tag_1_corrected'), pl.col(tag_1))
            .alias(tag_1),
            pl.coalesce(pl.col('tag_2_corrected'), pl.col(tag_2))
            .alias(tag_2),
        ])
        .drop('tag_1_corrected', 'tag_2_corrected')
    )
    #fix cases where tag2 is null
    nulls_included = (corrections.filter(pl.col(tag_2).is_null())
        .select([tag_1, 'tag_1_corrected', 'tag_2_corrected']))
    df = (
        df
        .join(
            nulls_included,
            on=tag_1,
            how='left',
            #suffix = '_null'
        )
        .with_columns([
        pl.when(pl.col(tag_2).is_null())
        .then(pl.coalesce(pl.col('tag_1_corrected'), pl.col(tag_1)))
            .otherwise(pl.col(tag_1))
            .alias(tag_1),
        pl.when(pl.col(tag_2).is_null())
        .then(pl.coalesce(pl.col('tag_2_corrected'), pl.col(tag_2)))
            .otherwise(pl.col(tag_2))
            .alias(tag_2)
        ])
        .drop(['tag_1_corrected', 'tag_2_corrected'])
    )         
    
    #Correct colors for two instances
    corrections_colors = pl.DataFrame({
        tag_color: ['Green', 'Green'],
        tag_1: ['F179', 'F401'],
        'tag_color_corrected': ['Orange', 'Orange']
    })
     # fix values with no nulls on lookup (can't join on null values)
    no_nulls_df = corrections_colors.filter(pl.col(tag_1).is_not_null())
    df = (
        df
        .join(no_nulls_df, on=[tag_color, tag_1], how='left')
        .with_columns([
            pl.coalesce(pl.col('tag_color_corrected'), pl.col(tag_color))
            .alias(tag_color)
        ])
        .drop('tag_color_corrected')
    )

    
    return df

def correct_tag_duplicates(df):
# Corrections to issues found during individual_duplicate_check from script 03 
    tag_1 = 'Tag Number'
    tag_2 = 'Tag Number 2'
    corrections = pl.DataFrame({
        tag_1: [
            'E410', 'E506', 'E546', 'E582', 'E602', 'E742', 'E916', 'E970', 'E994', 'F243',
            'F283', 'F299', 'F309'
        ],
        tag_2: [
            'R411', 'E508', 'R547', 'R583', 'E604', 'R743', 'R917', None, 'R995', None,
            'F384', '3D9.1A4FAAB2D8', None
        ],
        'tag_1_corrected': [
            None, None, None, None, None, None, None, None, None, None,
            None, 'F399', None
        ],
         'tag_2_corrected': [
            'E411', 'E507', 'E547', 'E583', 'E603', 'E743', 'E917', 'E971', 'E995', 'F244',
            'F284', None, 'F310'
         ]
    })
    # fix values with no nulls on lookup (can't join on null values)
    no_nulls_df = corrections.filter(pl.col(tag_2).is_not_null())
    df = (
        df
        .join(no_nulls_df, on=[tag_1, tag_2], how='left')
        .with_columns([
            pl.coalesce(pl.col('tag_1_corrected'), pl.col(tag_1))
            .alias(tag_1),
            pl.coalesce(pl.col('tag_2_corrected'), pl.col(tag_2))
            .alias(tag_2),
        ])
        .drop('tag_1_corrected', 'tag_2_corrected')
    )
    #fix cases where tag2 is null
    nulls_included = (corrections.filter(pl.col(tag_2).is_null())
        .select([tag_1, 'tag_1_corrected', 'tag_2_corrected']))
    df = (
        df
        .join(
            nulls_included,
            on=tag_1,
            how='left',
            #suffix = '_null'
        )
        .with_columns([
        pl.when(pl.col(tag_2).is_null())
        .then(pl.coalesce(pl.col('tag_1_corrected'), pl.col(tag_1)))
            .otherwise(pl.col(tag_1))
            .alias(tag_1),
        pl.when(pl.col(tag_2).is_null())
        .then(pl.coalesce(pl.col('tag_2_corrected'), pl.col(tag_2)))
            .otherwise(pl.col(tag_2))
            .alias(tag_2)
        ])
        .drop(['tag_1_corrected', 'tag_2_corrected'])
    )         

    #two PIT tagged mussels were classified as Hallprint which caused them not to match when grouped later on
    tag_type = 'Tag Type'
    tag_list = ['3D9.1A4FAAB31D', '3D9.1A4FAAB306']
    df = df.with_columns(
        pl.when(
            (pl.col(tag_type) == 'Hallprint') 
            & (pl.col(tag_2).is_in(tag_list))
        )
        .then(pl.lit('PIT'))
        .otherwise(pl.col(tag_type))
        .alias(tag_type)
    )
    return df