fn_diabetes_algorithm <- function(data) {
  data <- data %>%
    mutate(
    ## --- Step 0: Temporary helper variables ---
      tmp_birth_year_num = as.numeric(format(as.Date(birth_date, format = "%Y-%m-%d"), "%Y")),
      tmp_first_diabetes_diag_year = as.integer(format(tmp_first_diabetes_diag_date, "%Y")), # includes many diagnosis possibilities: t2dm_date, t1dm_date, otherdm_date, gestationaldm_date, tmp_elig_date_poccdm, tmp_elig_date_diabetes_medication, tmp_nonmetform_drugs_dmd_date
      tmp_age_1st_diag = tmp_first_diabetes_diag_year - tmp_birth_year_num,
      tmp_age_1st_diag = replace(tmp_age_1st_diag, which(tmp_age_1st_diag < 0), NA),
      tmp_age_under_35_30_1st_diag = case_when(!is.na(tmp_age_1st_diag)
                                               & ((tmp_age_1st_diag < 35 & (ethnicity_cat %in% c("1", "2", "5")))
                                                  | (tmp_age_1st_diag < 30)) ~ "Yes",
                                               TRUE ~ "No"), # prevents any NA: Those with DM but not fulfilling the condition OR those without DM at all -> "No"
      tmp_hba1c_date_step7 = case_when(!is.na(tmp_max_hba1c_mmol_mol_num) & tmp_max_hba1c_mmol_mol_num >= 47.5 ~ tmp_max_hba1c_date,
                                       TRUE ~ as.Date(NA)),
      tmp_over5_pocc_step7 = case_when(!is.na(tmp_poccdm_ctv3_count_num) & tmp_poccdm_ctv3_count_num >= 5 ~ tmp_poccdm_date,
                                       TRUE ~ as.Date(NA))) %>%

    ## --- Step 1: Any gestational diabetes code?
    mutate(step_1 = ifelse(!is.na(gestationaldm_date), "Yes", "No")
           ) %>%

    ## --- Step 1a: Any T1/T2 diagnostic codes besides gestational diabetes present? Denominator: Those with step 1 == Yes
    mutate(step_1a = case_when(step_1 == "Yes" & (!is.na(t1dm_date) | !is.na(t2dm_date)) ~ "Yes",
                              step_1 == "Yes" ~ "No", # everyone else with Yes to step 1 - but first condition not true
                              TRUE ~ NA_character_) # NA will only be fulfilled for people not part of denominator
           ) %>%

    ## --- Step 2: Any non-metformin oral antidiabetic drug prescription? Denominator: Step 1 == No or Step 1a == Yes
    mutate(step_2 = case_when((step_1 == "No" | step_1a == "Yes") & !is.na(tmp_nonmetform_drugs_dmd_date) ~ "Yes",
                              step_1 == "No" | step_1a == "Yes" ~ "No",
                              TRUE ~ NA_character_) # NA will only be fulfilled for people not part of denominator
           ) %>%

    ## --- Step 3: Any type 1 DM diagnostic code in the absence of any type 2 DM diagnostic code? Denominator: Step 2 == No
    mutate(step_3 = case_when(step_2 == "No" & !is.na(t1dm_date) & is.na(t2dm_date) ~ "Yes",
                              step_2 == "No" ~ "No",
                              TRUE ~ NA_character_) # NA will only be fulfilled for people not part of denominator
           ) %>%

    ## --- Step 4: Any type 2 DM diagnostic code in the absence of any type 1 DM diagnostic code? Denominator: Step 3 == No
    mutate(step_4 = case_when(step_3 == "No" & !is.na(t2dm_date) & is.na(t1dm_date) ~ "Yes",
                              step_3 == "No" ~ "No",
                              TRUE ~ NA_character_) # NA will only be fulfilled for people not part of denominator
           ) %>%

    ## --- Step 5. Aged <35yrs (or <30 yrs for SAs and AFCS) at first diagnostic code? Denominator: Step 4 == No
    mutate(step_5 = case_when(step_4 == "No" & tmp_age_under_35_30_1st_diag == "Yes" ~ "Yes", # tmp_age_under_35_30_1st_diag includes many diagnostic codes, see Step 0 above (incl. gestational DM, but excluded in Step 1)
                              step_4 == "No" & tmp_age_under_35_30_1st_diag == "No" ~ "No", # tmp_age_under_35_30_1st_diag cannot be NA (see above)
                              TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 6. Both, type 1 DM diagnostic codes and type 2 DM diagnostic codes present? Denominator: Step 5 == No
    mutate(step_6 = case_when(step_5 == "No" & !is.na(t1dm_date) & !is.na(t2dm_date) ~ "Yes",
                              step_5 == "No" & (is.na(t1dm_date) | is.na(t2dm_date)) ~ "No",
                              TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 6a. In primary care, only type 1 DM diagnostic codes reported? Denominator: Step 6 == Yes
    mutate(step_6a = case_when(step_6 == "Yes" & !is.na(tmp_t1dm_ctv3_date) & is.na(tmp_t2dm_ctv3_date) ~ "Yes",
                               step_6 == "Yes" ~ "No",
                               TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 6b. In primary care, only type 2 DM diagnostic codes reported? Denominator: Step 6a == No
    mutate(step_6b = case_when(step_6a == "No" & is.na(tmp_t1dm_ctv3_date) & !is.na(tmp_t2dm_ctv3_date) ~ "Yes",
                               step_6a == "No" ~ "No",
                               TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 6c. Number of type 1 DM diagnostic codes > number of type 2 DM diagnostic codes? Denominator: Step 6b == No
    mutate(step_6c = case_when(step_6b == "No" & tmp_t1dm_count_num > tmp_t2dm_count_num ~ "Yes", # count variables cannot be NA, see ehrQL documentation for count_for_patient(): "Note this will be 0 rather than NULL if the patient has no rows at all in the frame." https://docs.opensafely.org/ehrql/reference/language/#PatientFrame.count_for_patient
                               step_6b == "No" ~ "No",
                               TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 6d. Number of type 2 DM diagnostic codes > number of type 1 DM diagnostic codes? Denominator: Step 6c == No
    mutate(step_6d = case_when(step_6c == "No" & tmp_t2dm_count_num > tmp_t1dm_count_num ~ "Yes", # count variables cannot be NA, see ehrQL documentation for count_for_patient(): "Note this will be 0 rather than NULL if the patient has no rows at all in the frame." https://docs.opensafely.org/ehrql/reference/language/#PatientFrame.count_for_patient
                               step_6c == "No" ~ "No",
                               TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
    ) %>%

    ## --- Step 6e. Type 2 DM diagnostic code is more recent than type 1 DM diagnostic code? Denominator: Step 6d == No
    mutate(step_6e = case_when(step_6d == "No" & t2dm_date > t1dm_date ~ "Yes",
                               step_6d == "No" & t2dm_date <= t1dm_date ~ "No", # I think the second part of this condition can be removed, since all that end up here have a t2dm_date and t1dm_date (step 6)? Currently Type 1 overrules Type 2 in case they have exactly the same date (extrem edge case), which I think it reasonable. If we remove the second part, the same will apply by default.
                               TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator
    ) %>%

    ## --- Step 7. Diabetes medication or >5 DM process of care codes or HbA1c >= 6.5 (47.5 mmol/mol)? Denominator: Step 6 == No
    mutate(step_7 = case_when(step_6 == "No"
                              & ((!is.na(tmp_diabetes_medication_date)) |
                                   (tmp_max_hba1c_mmol_mol_num >= 47.5) |
                                   (tmp_poccdm_ctv3_count_num >= 5)) ~ "Yes",
                              step_6 == "No" ~ "No", # this includes people with any missings in t1dm_date or t2dm_date or tmp_diabetes_medication_date or tmp_max_hba1c_mmol_mol_num or HbA1c too low or not enough procedure codes (i.e. no evidence for DM (medication, hba1c, procedure codes)) => step_7 == "No" => Diabetes unlikely
                              TRUE ~ NA_character_) # NA will only be fulfilled if not part of denominator.
    ) %>%


    ## --- Final Diabetes Classification ---
    mutate(
      cat_diabetes = case_when(

        # DM unlikely conditions
        (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
           step_5 == "No" & step_6 == "No" & step_7 == "No") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "No" & step_7 == "No") ~ "DM unlikely",

        # DM other conditions
        (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
           step_5 == "No" & step_6 == "No" & step_7 == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "No" & step_7 == "Yes") ~ "DM_other",

        # T2DM conditions
        (step_1 == "No" & step_2 == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "No" & step_6d == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "No" & step_6d == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "No" & step_6d == "No" & step_6e == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
             step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "No" & step_6d == "No" & step_6e == "Yes") ~ "T2DM",

        # T1DM conditions
        (step_1 == "No" & step_2 == "No" & step_3 == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "No" & step_6 == "Yes" & step_6a == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "No" & step_6 == "Yes" & step_6a == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "Yes") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "Yes") |
          (step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "No" & step_6d == "No" & step_6e == "No") |
          (step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" & step_4 == "No" & step_5 == "No" & step_6 == "Yes" & step_6a == "No" & step_6b == "No" & step_6c == "No" & step_6d == "No" & step_6e == "No") ~ "T1DM",

        # Gestational Diabetes (GDM)
        step_1 == "Yes" & step_1a == "No" ~ "GDM",

        # Default case (for any other conditions)
        TRUE ~ NA_character_
      )
    ) %>%
    mutate(across(cat_diabetes, ~replace_na(., "DM unlikely"))) %>%


    ## --- Final Clean-Up ---
    # Define the incident diabetes date variables by diabetes category
    # Uses diabetes category from algorithm above and date of first diabetes related code

    # remove original diabetes variables to avoid duplication
    dplyr::select(- t1dm_date, - t2dm_date, - otherdm_date, - gestationaldm_date) %>%
    # GESTATIONAL
    mutate(gestationaldm_date = as_date(case_when(cat_diabetes == "GDM" ~ tmp_first_diabetes_diag_date)),
           # T2DM
           t2dm_date = as_date(case_when(cat_diabetes == "T2DM" ~ tmp_first_diabetes_diag_date)),
           # T1DM
           t1dm_date = as_date(case_when(cat_diabetes == "T1DM" ~ tmp_first_diabetes_diag_date)),
           # OTHER
           otherdm_date = as_date(case_when(cat_diabetes == "DM_other" ~ pmin(tmp_hba1c_date_step7, tmp_over5_pocc_step7, na.rm = TRUE)))
           ) %>%
    # drop unnecessary helper variables
    dplyr::select(-contains("tmp"), -contains("step")) # we may want to put this step into data_process_RA instead to allow to keep the temporary variables in their datasets in the output (to be specified as an argument in the reusable action). Currently, not implemented, to be discussed.

  return(data)
}
