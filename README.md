# Overview

In 2023, the Freshwater Mollusk Conservation Center and Harrison Lake jointly released ~3,500 hatchery-raised mussel at the Bentonville site (38.84376, -78.33875) in the Shenandoah River. Of these, ~1,600 were uniquely tagged such that the individual mussel could be later identified. The site was resampled four times in 2024 from June to October using a combination of snorkeling and passing a PIT tag reader over the area. 

This project contains the mark-recapture analysis (POPAN) used to estimate abundance and survival of the 2023 release cohort and various associated documentation, including the associated methods, results, and discussion.  

# Setup/Dependencies

## Prerequisites:

Both Python and R should be installed and on PATH

## Setup steps

1) Copy project folder by either:
    1) git clone https://github.com/Chincheron/shenandoah-mussel-mark-recapture <local folder location>
    2) Downloading from github manually:
        1) From home page of project, click green 'Code' button on upper right
        2) Select 'Download ZIP'
        3) Extract to desired location on local computer
2) Navigate to project folder and run 'setup.bat'. This will run the 'setup.ps1' script that:
    1) Checks whether R and Python are installed and on PATH
    2) Installs uv (package manager for python environment) if not installed and syncs python packages 
    3) Installs renv (package manager for R environment) if not installed and syncs R packages 



# Folder Description

## config

Various files describing global paths, constants, and figure settings

## data

Location of raw data and various processed data. Only raw data is tracked in git. All other data is generated from scripts

## doc

Location of more detailed documentation files and draft reports/publications

## results

Location of results generated from scripts. Includes data from final versions of analyses (as objects), figures/tables for report and publications, and final publications

## scripts

Location of scripts that are used to run all analyses and generate results

## src

Location of various custom utility files with helper functions for main scripts