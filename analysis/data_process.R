################################################################################
## This script does the following:
# 1. Defines the input arguments for the reusable action
# 2. Loads the input data (.csv file)
# 3. Maps the input variables to the reusable action arguments
# 4. Checks if all variables needed for the reusable action are present in the data
# 5. Defines the core dataset with only the variables needed for the algorithm to work
# 6. Double-checks the format of the core variables and runs a few checks
# 7. Re-formats the core variables
# 8. Runs the diabetes algorithm and reduces the 21 input core variables to 8 output variables
# 9. Merges the 8 output variables back to the initial dataset by replacing the 21 input core variables
# 10 Save output dataset (data_processed.rds)
################################################################################

print("diabetes-algo version: v0.0.1")

################################################################################
# Import libraries and functions
################################################################################
print("Import libraries")
library('arrow')
library('readr')
library('here')
library('lubridate')
library('dplyr')
library('tidyr')

print("Import diabetes algo function")
source(here::here("analysis", "functions", "fn_diabetes_algorithm.R"))

################################################################################
# Define flag style arguments using the optparse package
################################################################################
library('optparse')
option_list <- list(
  make_option("--df_input", type = "character", default = "input.csv",
              help = "Input dataset. csv file. Assumed to be within the directory 'output' [default %default]",
              metavar = "filename.csv"),
  make_option("--remove_helper", type = "logical", default = TRUE,
              help = "Logical, indicating whether all helper variables (_tmp and step_) are removed [default %default]",
              metavar = "TRUE/FALSE"),
  make_option("--birth_date", type = "character", default = "birth_date",
              help = "Birth date [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--ethnicity_cat", type = "character", default = "ethnicity_cat",
              help = "Ethnicity, in 6 categories, coded as follows: White, Mixed, South Asian, Black, Other, Unknown. [default %default]",
              metavar = "ethnicity_varname"),
  make_option("--t1dm_date", type = "character", default = "t1dm_date",
              help = "First type 1 DM diagnosis date, from both primary (e.g. https://www.opencodelists.org/codelist/user/hjforbes/type-1-diabetes/674fbd7a/) and secondary (e.g. https://www.opencodelists.org/codelist/opensafely/type-1-diabetes-secondary-care/2020-09-27/) care [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_t1dm_ctv3_date", type = "character", default = "tmp_t1dm_ctv3_date",
              help = "First type 1 DM diagnosis date, from primary care only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_t1dm_count_num", type = "character", default = "tmp_t1dm_count_num",
              help = "Count of all recorded Type 1 DM diagnosis codes, from both primary and secondary care [default %default]",
              metavar = "t1dm_count_varname"),
  make_option("--t2dm_date", type = "character", default = "t2dm_date",
              help = "First type 2 DM diagnosis date, from both primary (e.g. https://www.opencodelists.org/codelist/user/hjforbes/type-2-diabetes/3530d710/) and secondary (e.g. https://www.opencodelists.org/codelist/user/r_denholm/type-2-diabetes-secondary-care-bristol/0b7f6cd4/) care [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_t2dm_ctv3_date", type = "character", default = "tmp_t2dm_ctv3_date",
              help = "First type 2 DM diagnosis date, from primary care only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_t2dm_count_num", type = "character", default = "tmp_t2dm_count_num",
              help = "Count of all recorded Type 2 DM diagnosis codes, from both primary and secondary care [default %default]",
              metavar = "t2dm_count_varname"),
  make_option("--otherdm_date", type = "character", default = "otherdm_date",
              help = "First other/unspecified DM diagnosis date, from primary care (e.g. https://www.opencodelists.org/codelist/user/hjforbes/other-or-nonspecific-diabetes/0311f0a6/) only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_otherdm_count_num", type = "character", default = "tmp_otherdm_count_num",
              help = "Count of all recorded other/unspecified DM diagnosis codes, from primary care only [default %default]",
              metavar = "otherdm_count_varname"),
  make_option("--gestationaldm_date", type = "character", default = "gestationaldm_date",
              help = "First gestational DM diagnosis date, from both primary (e.g. https://www.opencodelists.org/codelist/user/hjforbes/gestational-diabetes/1ed423d1/) and secondary (e.g. https://www.opencodelists.org/codelist/user/alainamstutz/gestational-diabetes-icd10-bristol/474e7a09/) care [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_poccdm_date", type = "character", default = "tmp_poccdm_date",
              help = "First Non-diagnostic DM code date, from primary care (e.g. https://www.opencodelists.org/codelist/user/hjforbes/nondiagnostic-diabetes-codes/50f30a3b/) only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_poccdm_ctv3_count_num", type = "character", default = "tmp_poccdm_ctv3_count_num",
              help = "Count of all recorded Non-diagnostic DM codes, from primary care only [default %default]",
              metavar = "non_diag_dm_code_count_varname"),
  make_option("--tmp_max_hba1c_mmol_mol_num", type = "character", default = "tmp_max_hba1c_mmol_mol_num",
              help = "Maximum HbA1c value recorded in query period, in mmol/mol (use https://www.opencodelists.org/codelist/opensafely/glycated-haemoglobin-hba1c-tests-numerical-value/5134e926/) from primary care only [default %default]",
              metavar = "max_hba1c_varname"),
  make_option("--tmp_max_hba1c_date", type = "character", default = "tmp_max_hba1c_date",
              help = "First maximum HbA1c value date, from primary care only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_insulin_dmd_date", type = "character", default = "tmp_insulin_dmd_date",
              help = "First insulin drug date variable, from primary care (e.g. https://www.opencodelists.org/codelist/opensafely/insulin-medication/2020-04-26/) only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_antidiabetic_drugs_dmd_date", type = "character", default = "tmp_antidiabetic_drugs_dmd_date",
              help = "First antidiabetic drug (any, except insulin) date, from primary care (e.g. https://www.opencodelists.org/codelist/opensafely/antidiabetic-drugs/2020-07-16/) only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_nonmetform_drugs_dmd_date", type = "character", default = "tmp_nonmetform_drugs_dmd_date",
              help = "First antidiabetic drug (any, except insulin and metformin) date, from primary care (e.g. https://www.opencodelists.org/codelist/user/r_denholm/non-metformin-antidiabetic-drugs_bristol/7207eb58/) only [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_diabetes_medication_date", type = "character", default = "tmp_diabetes_medication_date",
              help = "First antidiabetic drug date, i.e. minimum of tmp_insulin_dmd_date and tmp_antidiabetic_drugs_dmd_date [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--tmp_first_diabetes_diag_date", type = "character", default = "tmp_first_diabetes_diag_date",
              help = "First diabetes diagnosis date variable, i.e. minimum of t1dm_date, t2dm_date, otherdm_date, gestationaldm_date, tmp_poccdm_date, tmp_nonmetform_drugs_dmd_date, and tmp_diabetes_medication_date [default %default]",
              metavar = "YYYY-MM-DD"),
  make_option("--df_output", type = "character", default = "data_processed.rds",
              help = "Output dataset. rds file. This is assumed to be added to the directory 'output' [default %default]",
              metavar = "filename.rds")
)
opt_parser <- OptionParser(usage = "diabetes-algo:[version] [options]", option_list = option_list)
opt <- parse_args(opt_parser)

################################################################################
# Record input arguments
################################################################################
print("Record input arguments")
record_args <- data.frame(argument = names(opt),
                          value = unlist(opt),
                          stringsAsFactors = FALSE)
row.names(record_args) <- NULL

### Is this needed?
# print(record_args)
# write.csv(record_args,
#           file = paste0("output/args-", opt$df_output),
#           row.names = FALSE)

################################################################################
# Load data
################################################################################
print("Load data")
if (grepl(".csv",opt$df_input)) {
  data <- readr::read_csv(paste0("output/", opt$df_input))
}
if (grepl(".rds",opt$df_input)) {
  data <- readr::read_rds(paste0("output/", opt$df_input))
}
print(summary(data))

################################################################################
# Map user column names to standardized argument names, double-check, and extract core data
################################################################################
print("Map user variable names")
column_mapping <- list(
  birth_date = opt$birth_date,
  ethnicity_cat = opt$ethnicity_cat,
  tmp_t1dm_ctv3_date = opt$tmp_t1dm_ctv3_date,
  t1dm_date = opt$t1dm_date,
  tmp_t1dm_count_num = opt$tmp_t1dm_count_num,
  tmp_t2dm_ctv3_date = opt$tmp_t2dm_ctv3_date,
  t2dm_date = opt$t2dm_date,
  tmp_t2dm_count_num = opt$tmp_t2dm_count_num,
  otherdm_date = opt$otherdm_date,
  tmp_otherdm_count_num = opt$tmp_otherdm_count_num,
  gestationaldm_date = opt$gestationaldm_date,
  tmp_poccdm_date = opt$tmp_poccdm_date,
  tmp_poccdm_ctv3_count_num = opt$tmp_poccdm_ctv3_count_num,
  tmp_max_hba1c_mmol_mol_num = opt$tmp_max_hba1c_mmol_mol_num,
  tmp_max_hba1c_date = opt$tmp_max_hba1c_date,
  tmp_insulin_dmd_date = opt$tmp_insulin_dmd_date,
  tmp_antidiabetic_drugs_dmd_date = opt$tmp_antidiabetic_drugs_dmd_date,
  tmp_nonmetform_drugs_dmd_date = opt$tmp_nonmetform_drugs_dmd_date,
  tmp_diabetes_medication_date = opt$tmp_diabetes_medication_date,
  tmp_first_diabetes_diag_date = opt$tmp_first_diabetes_diag_date
)

print("Double-check if all required variables part of user data")
# whether all the columns specified by the user in their command-line arguments actually exist in their data
missing_columns <- setdiff(unlist(column_mapping), colnames(data))
if (length(missing_columns) > 0) {
  stop(paste("The following columns are missing in the data:", paste(missing_columns, collapse = ", ")))
}

print("Extract core data and patient_id")
core <- data[c("patient_id", unlist(column_mapping))]

################################################################################
# Double-check the imported core variables
################################################################################
print("Check the date variables")
date_columns <- names(core)[grepl("_date$", names(core))]
# Check for invalid date formats while allowing NA values
invalid_dates <- sapply(core[date_columns], function(col) {
  parsed_dates <- as.Date(col, format = "%Y-%m-%d")
  # Identify non-NA values that failed conversion
  invalid_values <- !is.na(col) & is.na(parsed_dates)
  any(invalid_values)  # TRUE if any invalid non-NA values are found
})
# Error message
if (any(invalid_dates)) {
  stop(paste(
    "The following date columns contain invalid date formats:",
    paste(names(invalid_dates)[invalid_dates], collapse = ", ")
  ))
}
print("validation passed: all date values are coded as dates in the format %Y-%m-%d")

print("Check the numeric variables")
numeric_columns <- names(core)[grepl("_num$", names(core))]
# Check for invalid numeric values while allowing NA
invalid_numerics <- sapply(core[numeric_columns], function(col) {
  # Check if non-NA values can be converted to numeric
  invalid_values <- !is.na(col) & is.na(suppressWarnings(as.numeric(col)))
  any(invalid_values)  # TRUE if any invalid non-NA values are found
})
# Error message
if (any(invalid_numerics)) {
  stop(paste(
    "The following numeric columns contain invalid numeric values:",
    paste(names(invalid_numerics)[invalid_numerics], collapse = ", ")
  ))
}
print("validation passed: all numeric values are coded as numeric")

print("Check the ethnicity variable")
valid_ethnicities <- c("White", "Mixed", "South Asian", "Black", "Unknown", "Other")
# Identify invalid values (including NA, since this should be coded as "Unknown")
invalid_ethnicity <- core$ethnicity_cat[is.na(core$ethnicity_cat) |
                                          !(core$ethnicity_cat %in% valid_ethnicities)]
# Error message
if (length(invalid_ethnicity) > 0) {
  stop(paste(
    "The 'ethnicity_cat' column contains invalid values:",
    paste(unique(invalid_ethnicity), collapse = ", "),
    "\nValid values are: White, Mixed, South Asian, Black, Unknown, Other. NA values are not allowed."
  ))
}
print("'ethnicity_cat' validation passed: all values are valid categories (NA not allowed).")

################################################################################
# Reformat the imported core variables
################################################################################
print("Reformat the imported core variables")
core <- core %>%
  mutate(across(all_of(date_columns),
                ~ floor_date(as.Date(., format = "%Y-%m-%d"), unit = "days")),
         across(contains('_num'), ~ as.numeric(.)),
         across(contains('_cat'), ~ as.factor(.))
  )

################################################################################
# Apply the diabetes algorithm
################################################################################
print("Apply the diabetes algorithm and delete all tmp & step variables")
core <- fn_diabetes_algorithm(core)

################################################################################
# Merge the core back to the user data
################################################################################
if (opt$remove_helper == TRUE) {
  print("Remove helper variables")
  core <- core %>%
    dplyr::select(-contains("tmp"), -contains("step"))
}

# Exclude first the core variables from users' input data since they are in both datasets (core and data)
non_core <- data[setdiff(names(data), c(unlist(column_mapping)))]
data_processed <- merge(non_core, core,
                        by = "patient_id",
                        all.x = TRUE)

################################################################################
# Save output
################################################################################
print("Save output")
write_rds(data_processed, paste0("output/", opt$df_output))
