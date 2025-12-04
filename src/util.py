import polars as pl
import src.util as util

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


def load_mr_occasion(df):
    # Separate hallprint/Pit tag into distinct columns

    #test values of Tag Type
    tag_type_list = df['Tag Type'].unique().to_list()

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

    # There is an issue with some PIT tag numbers being out of order
    # (e.g., 3D9.1A4FAAB2F3 on MR1 and B2F33D9.1A4FAA on subsequent occasions)
    # Standardize Pit tag to Bi-hex display such that there are 3 digits before the period (3D9.1A4FAAB2F3)
    df = df.with_columns(
        pl.col('PIT_tag_no')
        .map_elements(util.standardize_PIT)
        .alias('PIT_tag_no')
    )    
    return(df, tag_type_list)