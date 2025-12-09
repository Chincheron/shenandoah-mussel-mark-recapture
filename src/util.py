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
        'E. complanata': 'Elliptio complanata'
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
        pl.col(column_name)
        .map_elements(standardize_PIT)
    )    
    return df

def create_mr_columns(df):
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
    column_name = 'Tag Number 2'
    mapping = {
        'F2546': 'F246',
        }
    df = df.with_columns(pl.col(column_name).replace(mapping))
