################################################################################
## This script does the following:
# 1. Import/extract feather dataset from OpenSAFELY: 21 variables needed from OpenSAFELY
# 2. Basic type formatting of variables -> fn_extract_data.R()
# 3. Process the ethnicity covariate and apply the diabetes algorithm -> fn_diabetes_algorithm.R()
# 4. Save the output: data_processed containing only 8 variables
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library('arrow')
library('readr')
library('here')
library('lubridate')
library('dplyr')
library('tidyr')

## Import custom user functions
source(here::here("analysis", "functions", "fn_extract_data.R"))
source(here::here("analysis", "functions", "fn_case_when.R"))
source(here::here("analysis", "functions", "fn_diabetes_algorithm.R"))

################################################################################
# 1 Import data
################################################################################
input_filename <- "dataset.arrow"

################################################################################
# 2 Reformat the imported data
################################################################################
data_extracted <- fn_extract_data(input_filename)

################################################################################
# 3 Process the data and apply diabetes algorithm
################################################################################
data_extracted <- data_extracted %>%
  mutate(
    ethnicity_cat = fn_case_when(
      ethnicity_cat == "1" ~ "White",
      ethnicity_cat == "4" ~ "Black",
      ethnicity_cat == "3" ~ "South Asian",
      ethnicity_cat == "2" ~ "Mixed",
      ethnicity_cat == "5" ~ "Other",
      ethnicity_cat == "0" ~ "Unknown",
      TRUE ~ NA_character_) # if ethnicity is NA, it remains NA -> will not influence diabetes algo, except that for step 5 only age will be used for these cases
    )
# apply diabetes algorithm and delete all helper variables (tmp & step) at the end
data_processed <- fn_diabetes_algorithm(data_extracted)

## CAVE: it drops all variables that contains("tmp") or contains("step") !!

################################################################################
# 4 Save output
################################################################################
# the data
write_rds(data_processed, here::here("output", "data_processed.rds"))