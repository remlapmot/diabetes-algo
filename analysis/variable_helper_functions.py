#######################################################################################
# HELPER FUNCTIONS for the dataset_definition
#######################################################################################
from ehrql.tables.tpp import (
    apcs,
    clinical_events, 
    medications
)

#######################################################################################
### COUNT all prior events (including index_date)
#######################################################################################
## In PRIMARY CARE
# CTV3/Read
def count_matching_event_clinical_ctv3_before(codelist, index_date, where=True):
    return(
        clinical_events.where(where)
        .where(clinical_events.ctv3_code.is_in(codelist))
        .where(clinical_events.date.is_on_or_before(index_date))
        .count_for_patient()
    )

## In SECONDARY CARE (Hospital Episodes)
def count_matching_event_apc_before(codelist, index_date, where=True):
    return(
        apcs.where(where)
        .where(apcs.primary_diagnosis.is_in(codelist) | apcs.secondary_diagnosis.is_in(codelist))
        .where(apcs.admission_date.is_on_or_before(index_date))
        .count_for_patient()
    )

#######################################################################################
### ANY HISTORY of ... and give first ... (including index_date) 
#######################################################################################
## In PRIMARY CARE
# CTV3/Read
def first_matching_event_clinical_ctv3_before(codelist, index_date, where=True):
    return(
        clinical_events.where(where)
        .where(clinical_events.ctv3_code.is_in(codelist))
        .where(clinical_events.date.is_on_or_before(index_date))
        .sort_by(clinical_events.date)
        .first_for_patient()
    )
# Snomed
def first_matching_event_clinical_snomed_before(codelist, index_date, where=True):
    return(
        clinical_events.where(where)
        .where(clinical_events.snomedct_code.is_in(codelist))
        .where(clinical_events.date.is_on_or_before(index_date))
        .sort_by(clinical_events.date)
        .first_for_patient()
    )
# Medication
def first_matching_med_dmd_before(codelist, index_date, where=True):
    return(
        medications.where(where)
        .where(medications.dmd_code.is_in(codelist))
        .where(medications.date.is_on_or_before(index_date))
        .sort_by(medications.date)
        .first_for_patient()
    )

## In SECONDARY CARE (Hospital Episodes)
def first_matching_event_apc_before(codelist, index_date, where=True):
    return(
        apcs.where(where)
        .where(apcs.primary_diagnosis.is_in(codelist) | apcs.secondary_diagnosis.is_in(codelist))
        .where(apcs.admission_date.is_on_or_before(index_date))
        .sort_by(apcs.admission_date)
        .first_for_patient()
    )