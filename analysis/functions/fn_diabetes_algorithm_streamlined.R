fn_diabetes_algorithm_streamlined <- function(data) {
  data <- data %>%
    mutate(
    ## --- Step 0: Temporary helper variables ---
      tmp_birth_year_num = as.numeric(format(as.Date(birth_date, format = "%Y-%m-%d"), "%Y")),
      tmp_first_diabetes_diag_year = as.integer(format(tmp_first_diabetes_diag_date, "%Y")), # includes many diagnosis possibilities: t2dm_date, t1dm_date, otherdm_date, gestationaldm_date, tmp_elig_date_poccdm, tmp_elig_date_diabetes_medication, tmp_nonmetform_drugs_dmd_date
      tmp_age_1st_diag = tmp_first_diabetes_diag_year - tmp_birth_year_num,
      tmp_age_1st_diag = case_when(tmp_age_1st_diag < 0 ~ NA,
                                   TRUE ~ tmp_age_1st_diag),
      tmp_age_under_35_30_1st_diag = case_when(!is.na(tmp_age_1st_diag)
                                               & ((tmp_age_1st_diag < 35 & (ethnicity_cat %in% c("1", "2", "5")))
                                                  | (tmp_age_1st_diag < 30)) ~ "Yes",
                                               TRUE ~ "No"), # prevents any NA: Those with DM but not fulfilling the condition OR those without DM at all -> "No"
      tmp_hba1c_date_step7 = case_when(!is.na(tmp_max_hba1c_mmol_mol_num) & tmp_max_hba1c_mmol_mol_num >= 47.5 ~ tmp_max_hba1c_date,
                                       TRUE ~ NA_Date_),
      tmp_over5_pocc_step7 = case_when(!is.na(tmp_poccdm_ctv3_count_num) & tmp_poccdm_ctv3_count_num >= 5 ~ tmp_poccdm_date,
                                       TRUE ~ NA_Date_)) %>%

    ## --- Step 1: Any gestational diabetes code?
    mutate(step_1 = ifelse(!is.na(gestationaldm_date), "Yes", "No")) %>%

    ## --- Step 1a: Any T1/T2 diagnostic codes besides gestational diabetes present? Denominator: Those with step 1 == Yes
    mutate(step_1a = ifelse(step_1 == "Yes" & (!is.na(t1dm_date) | !is.na(t2dm_date)), "Yes",
                            ifelse(step_1 == "Yes", "No", NA)) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 2: Any non-metformin oral antidiabetic drug prescription? Denominator: Step 1 == No or Step 1a == Yes
    mutate(step_2 = ifelse((step_1 == "No" | step_1a == "Yes") & !is.na(tmp_nonmetform_drugs_dmd_date), "Yes",
                           ifelse((step_1 == "No" | step_1a == "Yes"), "No", NA)) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 3: Any type 1 DM diagnostic code in the absence of any type 2 DM diagnostic code? Denominator: Step 2 == No
    mutate(step_3 = ifelse(step_2 == "No" & !is.na(t1dm_date) & is.na(t2dm_date), "Yes",
                           ifelse(step_2 == "No", "No", NA)) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 4: Any type 2 DM diagnostic code in the absence of any type 1 DM diagnostic code? Denominator: Step 3 == No
    mutate(step_4 = ifelse(step_3 == "No" & !is.na(t2dm_date) & is.na(t1dm_date), "Yes",
                           ifelse(step_3 == "No", "No", NA)) # NA will only be fulfilled if not part of denominator
           ) %>%

    ## --- Step 5. Aged <35yrs (or <30 yrs for SAs and AFCS) at first diagnostic code? Denominator: Step 4 == No
    mutate(step_5 = case_when(step_4 == "No" & tmp_age_under_35_30_1st_diag == "Yes" ~ "Yes", # tmp_age_under_35_30_1st_diag includes many diagnostic codes, see Step 0 above (incl. gestational DM, but excluded in Step 1)
                              step_4 == "No" & tmp_age_under_35_30_1st_diag == "No" ~ "No",
                              TRUE ~ "No") # tmp_age_under_35_30_1st_diag cannot be NA (see above), but ensures step_5 is never NA, even for those not part of denominator - is this needed? Depends on below.
           ) %>%

    ## --- Step 6. Both, type 1 DM diagnostic codes and type 2 DM diagnostic codes present? Denominator: Step 5 == No
    mutate(step_6 = ifelse(step_5 == "No" &
                             !is.na(t1dm_date) &
                             !is.na(t2dm_date), "Yes", # step_6 == Yes does not contain any NA
                           ifelse(step_5 == "No" &
                                    (is.na(t1dm_date) |
                                       is.na(t2dm_date)), "No", NA))) %>% # NA will never be fulfilled

    mutate(step_6 = case_when(step_5 == "No" & !is.na(t1dm_date) & !is.na(t2dm_date) ~ "Yes",
                              step_5 == "No" & (is.na(t1dm_date) | is.na(t2dm_date)) ~ "No",
                              TRUE ~ "No") # Ensures step_6 is never NA, even for those not part of denominator - is this needed? Depends on below.
           ) %>%





    ## --- Step 4: Insulin Dependency Check ---
    mutate(
      step_4 = ifelse(
        step_3 == "No" & !is.na(insulin_date) & is.na(tmp_noninsulin_drugs_date), "Yes",
        ifelse(step_3 == "No", "No", NA)
      )
    ) %>%

    ## --- Step 5: HbA1c Check ---
    mutate(
      step_5 = ifelse(
        step_4 == "No" & !is.na(tmp_hba1c_date_step7), "Yes",
        ifelse(step_4 == "No", "No", NA)
      )
    ) %>%

    ## --- Step 6: Age & Ethnicity Check ---
    mutate(
      step_6 = ifelse(
        step_5 == "No" & tmp_age_under_35_30_1st_diag == "Yes", "Yes",
        ifelse(step_5 == "No", "No", NA)
      )
    ) %>%

    ## --- Step 7: Multiple Consultations Check ---
    mutate(
      step_7 = ifelse(
        step_6 == "No" & !is.na(tmp_over5_pocc_step7), "Yes",
        ifelse(step_6 == "No", "No", NA)
      )
    ) %>%

    ## --- Final Diabetes Classification ---
    mutate(
      cat_diabetes = case_when(
        step_1 == "No" & step_2 == "No" & step_3 == "No" & step_4 == "No" &
          step_5 == "No" & step_6 == "No" & step_7 == "No" ~ "DM unlikely",

        step_1 == "Yes" & step_1a == "Yes" & step_2 == "No" & step_3 == "No" &
          step_4 == "No" & step_5 == "No" & step_6 == "No" & step_7 == "No" ~ "DM_other",

        step_2 == "Yes" ~ "T2DM",
        step_3 == "Yes" ~ "T1DM",
        step_4 == "Yes" ~ "Insulin-dependent DM",
        step_5 == "Yes" ~ "HbA1c-detected DM",
        step_6 == "Yes" ~ "Young-age DM",
        step_7 == "Yes" ~ "Consultation-based DM",

        step_1 == "Yes" & step_1a == "No" ~ "GDM",
        TRUE ~ "None"
      )
    ) %>%

    ## --- Final Clean-Up ---
    mutate(
      cat_diabetes = replace_na(cat_diabetes, "None")
    ) %>%
    select(-contains("tmp"), -contains("step"))

  return(data)
}
