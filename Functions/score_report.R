combine.cat = function(x, cols, id, newvar.name){
  subset = x[,c(id, cols)]
  names(subset) = c("id", paste0("X",1:length(cols)))
  subset = suppressWarnings(gather(subset, "key", "value", -id))
  subset = filter(subset, !is.na(value))
  subset$key = gsub("X", "", subset$key)
  subset = group_by(subset, id)
  subset = summarize(subset, newvar = paste(key, collapse = ","))
  names(subset) = c(id,newvar.name)
  x = suppressMessages(full_join(x, subset))
  return(x)
}

find_items = function(string, data2){
  items = names(data2)
  locations = which(grepl(string, items))
  final = items[locations]
  return(final)
}

contains_items = function(string, data2){
  items = names(data2)
  locations = which(grepl(string, items))
  output = length(locations) > 0
}

identify_state = function(ZC, zipcode.dataset = zipcode){
  if(!is.na(ZC)) {
    loc = which(zipcode.dataset$zip == ZC)
    state = zipcode.dataset$state[loc]
    if(length(loc) == 0) state = NA
  }
  if(is.na(ZC)) state = NA
  return(state)
}

select_first = function(x){
  x = x[!is.na(x) & !is.nan(x)]
  x[1]
}



source(here("Functions/state_abbr.R"))

score_report = function(data = NULL, week = NULL, zipcode = zipcode, master = FALSE){
  
  items = names(data)
  if(!master){
    newdata = data.frame(CaregiverID = data$CaregiverID, Week = week)
    newdata$CaregiverID = as.character(newdata$CaregiverID)
    #fill in random caregiver IDs
    missing = which(newdata$CaregiverID == "")
    random_ID = paste0("X", week, "ID", sample(11111:99999, size = length(missing), replace = F))
    newdata$CaregiverID[missing] = random_ID
    names(data) = gsub("R3.R..", "", names(data))
  }
  
  if(master){
    newdata = data[,c("CaregiverID", "Week", "BaselineWeek")]
    newdata$Date = as.Date(data$StartDate)

  }
  
  
  
  if(contains_items("POLICY.001_[1-7]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.001\\_.{1}$", data),
                       id = "CaregiverID",
                       newvar.name = "POLICY.001_cat")
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.012\\_.{1}$", data),
                       id = "CaregiverID",
                       newvar.name = "POLICY.012_cat")
    newdata$POLICY.001_cat = data$POLICY.001_cat
    newdata$access_telehealth = ifelse(grepl("1", data$POLICY.001_cat) | 
                                         grepl("2", data$POLICY.001_cat) | 
                                         grepl("1", data$POLICY.012_cat) | 
                                         grepl("2", data$POLICY.012_cat), 
                                       1, 0)
    newdata$access_telehealth_self = ifelse(grepl("1", data$POLICY.001_cat) | 
                                         grepl("1", data$POLICY.012_cat), 
                                       1, 0)
    newdata$access_telehealth_child = ifelse(grepl("2", data$POLICY.001_cat) | 
                                              grepl("2", data$POLICY.012_cat), 
                                            1, 0)
    newdata$access_mentalhealth = ifelse(grepl("3", data$POLICY.001_cat) | grepl("3", data$POLICY.012_cat), 1, 0)
    newdata$access_parenting = ifelse(grepl("4", data$POLICY.001_cat) | grepl("4", data$POLICY.012_cat), 1, 0)
    newdata$access_fitness = ifelse(grepl("5", data$POLICY.001_cat) | grepl("5", data$POLICY.012_cat), 1, 0)
    newdata$access_education = ifelse(grepl("6", data$POLICY.001_cat) | grepl("6", data$POLICY.012_cat), 1, 0)
    newdata$access_social = ifelse(rowSums(data[,find_items("POLICY.001_[3-4]", data)], na.rm=T) > 0, 1, 0)
    newdata$access_online = ifelse(rowSums(data[,find_items("POLICY.001_[1-7]$", data)], na.rm=T) > 0, 1, 0)  
  }
  
  if(contains_items("POLICY.002_[1-7]$", data)){
    newdata$utility_telehealth = rowMeans(data[,find_items("POLICY.002_[1-2]$", data)], na.rm=T)
    newdata$utility_social = rowMeans(data[,find_items("POLICY.002_[3-4]$", data)], na.rm=T)
    newdata$utility_online = rowMeans(data[,find_items("POLICY.002_[1-7]$", data)], na.rm=T)
  }
  
  if(contains_items("POLICY.004\\.[a-k]$", data)){
    hours_familyCC_current = rowSums(data[,find_items("POLICY.004.[a-d]$", data)],na.rm=T)
    hours_nonfamilyCC_current = rowSums(data[,find_items("POLICY.004.[e-k]$", data)],na.rm=T)
    newdata$familyCC_current = hours_familyCC_current
    newdata$nonfamilyCC_current = hours_nonfamilyCC_current
    
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.004_.{1,2}$", data),
                       id = "CaregiverID",
                       newvar.name = "POLICY.004_cat")
    
    newdata$cc_parent = ifelse(grepl("1$",data$POLICY.004_cat) | grepl("1,",data$POLICY.004_cat), 
                                       1, 0)
    newdata$cc_sibling = ifelse(grepl("2$",data$POLICY.004_cat) | grepl("2,",data$POLICY.004_cat), 
                                       1, 0)
    newdata$cc_grandparent = ifelse(grepl("3",data$POLICY.004_cat), 1, 0)
    newdata$cc_othRelative = ifelse(grepl("4",data$POLICY.004_cat), 1, 0)
    newdata$cc_familydaycare = ifelse(grepl("5",data$POLICY.004_cat), 1, 0)
    newdata$cc_childCareCenter = ifelse(grepl("7",data$POLICY.004_cat), 1, 0)
    newdata$cc_HeadStart = ifelse(grepl("8",data$POLICY.004_cat), 1, 0)
    newdata$cc_nursery = ifelse(grepl("9",data$POLICY.004_cat), 1, 0)
    newdata$cc_BefAfSchool = ifelse(grepl("10",data$POLICY.004_cat), 1, 0)
    newdata$cc_childSelfCare = ifelse(grepl("11",data$POLICY.004_cat), 1, 0)
  }
  
  if(contains_items("POLICY.003.[a-k]$", data)){
    hours_familyCC_pre = rowSums(data[,find_items("POLICY.003.[a-d]$", data)],na.rm=T)
    newdata$hours_familyCC_pre = hours_familyCC_pre
    
    hours_nonfamilyCC_pre = rowSums(data[,find_items("POLICY.003.[e-k]$", data)],na.rm=T)
    newdata$hours_nonfamilyCC_pre = hours_nonfamilyCC_pre
    
    hours_familyCC_current = rowSums(data[,find_items("POLICY.004.[a-d]$", data)],na.rm=T)
    newdata$hours_familyCC_current = hours_familyCC_current
    
    hours_nonfamilyCC_current = rowSums(data[,find_items("POLICY.004.[e-k]$", data)],na.rm=T)
    newdata$hours_nonfamilyCC_current = hours_nonfamilyCC_current
    
    change_familyCC = hours_familyCC_current-hours_familyCC_pre
    newdata$increase_familyCC = ifelse(change_familyCC > 0, 1, 0)
    newdata$decrease_familyCC = ifelse(change_familyCC < 0, 1, 0)
    
    change_nonfamilyCC = hours_nonfamilyCC_current-hours_nonfamilyCC_pre
    newdata$increase_nonfamilyCC = ifelse(change_nonfamilyCC > 0, 1, 0)
    newdata$decrease_nonfamilyCC = ifelse(change_nonfamilyCC < 0, 1, 0)
    
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.003_.{1,2}$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.003_cat")
    
    newdata$cc_parent_pre = ifelse(grepl("1$",data$POLICY.003_cat) | grepl("1,",data$POLICY.003_cat), 
                                       1, 0)
    newdata$cc_sibling_pre = ifelse(grepl("2$",data$POLICY.003_cat) | grepl("2,",data$POLICY.003_cat), 
                                        1, 0)
    newdata$cc_grandparent_pre = ifelse(grepl("3",data$POLICY.003_cat), 1, 0)
    newdata$cc_othRelative_pre = ifelse(grepl("4",data$POLICY.003_cat), 1, 0)
    newdata$cc_familydaycare_pre = ifelse(grepl("5",data$POLICY.003_cat), 1, 0)
    newdata$cc_childCareCenter_pre = ifelse(grepl("7",data$POLICY.003_cat), 1, 0)
    newdata$cc_HeadStart_pre = ifelse(grepl("8",data$POLICY.003_cat), 1, 0)
    newdata$cc_nursery_pre = ifelse(grepl("9",data$POLICY.003_cat), 1, 0)
    newdata$cc_BefAfSchool_pre = ifelse(grepl("10",data$POLICY.003_cat), 1, 0)
    newdata$cc_childSelfCare_pre = ifelse(grepl("11",data$POLICY.003_cat), 1, 0)
  }
  
  if(contains_items("POLICY.009", data)){
    newdata$cc2_nonparental_pre = ifelse(data$POLICY.009.a == 1, 1, 0)
    newdata$cc2_nonparental = ifelse(data$POLICY.009.b == 1, 1, 0)
  }
  if(contains_items("POLICY.010", data)){
    newdata$cc2_expected_change = case_when(
      data$POLICY.010 == 1 ~ 5,
      data$POLICY.010 == 2 ~ 1,
      data$POLICY.010 == 3 ~ 4,
      data$POLICY.010 == 4 ~ 2,
      data$POLICY.010 == 5 ~ 3,
      data$POLICY.010 == 6 ~ NA_real_)
  }

  
  if(contains_items("POLICY.015", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.015_", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.015_cat")
    data$POLICY.015_cat[data$POLICY.009.a != 1] = "0"
    newdata$cc2_centerbased_pre = ifelse(grepl("1",data$POLICY.015_cat), 1, 0)
    newdata$cc2_unpaid_pre = ifelse(grepl("2",data$POLICY.015_cat), 1, 0)
    newdata$cc2_paid_pre = ifelse(grepl("3",data$POLICY.015_cat), 1, 0)
    newdata$cc2_homebased_pre = ifelse(grepl("4",data$POLICY.015_cat), 1, 0)
    
    
  }
  
  if(contains_items("POLICY.016", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.016_", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.016_cat")
    data$POLICY.016_cat[data$POLICY.009.b != 1] = "0"
    newdata$cc2_centerbased = ifelse(grepl("1",data$POLICY.016_cat), 1, 0)
    newdata$cc2_unpaid = ifelse(grepl("2",data$POLICY.016_cat), 1, 0)
    newdata$cc2_paid = ifelse(grepl("3",data$POLICY.016_cat), 1, 0)
    newdata$cc2_homebased = ifelse(grepl("4",data$POLICY.016_cat), 1, 0)
  }
  
  if(contains_items("POLICY.006_[1-7]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.006_[1-7]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.006_cat")
    newdata$parent_edu_interrupt = ifelse(grepl("[1,3,5]",data$POLICY.006_cat), 1, 0)
  }
  
  if(contains_items("POLICY.008_[1-7]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.008_[1-7]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.008_cat")
    newdata$child_edu_interrupt = ifelse(grepl("[1,3,5]",data$POLICY.008_cat), 1, 0)
  }
  
  if(contains_items("POLICY.011_[1-4]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.011_[1-4]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.011_cat")
    data = data %>%
      mutate(
        POLICY.011_1 = 
          case_when(!is.na(POLICY.011_1) ~ 1,
                    !is.na(POLICY.011_cat) ~ 0,
                    TRUE ~ NA_real_),
        POLICY.011_2 = 
          case_when(!is.na(POLICY.011_2) ~ 1,
                    !is.na(POLICY.011_cat) ~ 0,
                    TRUE ~ NA_real_),
        POLICY.011_3 = 
          case_when(!is.na(POLICY.011_3) ~ 1,
                    !is.na(POLICY.011_cat) ~ 0,
                    TRUE ~ NA_real_),
        POLICY.011_4 = 
          case_when(!is.na(POLICY.011_4) ~ 1,
                    !is.na(POLICY.011_cat) ~ 0,
                    TRUE ~ NA_real_))
        
        newdata$plan_cc_samenow = data$POLICY.011_1
        newdata$plan_cc_differ = data$POLICY.011_2
        newdata$plan_cc_sameCOVID = data$POLICY.011_3
        newdata$plan_cc_dontknow = data$POLICY.011_4
        
  }
  
  if(contains_items("POLICY.018\\_[0-9]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.018\\_[0-9]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.018_cat")
    newdata$priorcc_center = ifelse(grepl("1", data$POLICY.018_cat), 1, 0)
    newdata$priorcc_relativemyhome = ifelse(grepl("2", data$POLICY.018_cat), 1, 0)
    newdata$priorcc_relativetheirhome = ifelse(grepl("3", data$POLICY.018_cat), 1, 0)
    newdata$priorcc_promyhome = ifelse(grepl("4", data$POLICY.018_cat), 1, 0)
    newdata$priorcc_theirhome = ifelse(grepl("5", data$POLICY.018_cat), 1, 0)
    newdata$priorcc_parents = ifelse(grepl("6", data$POLICY.018_cat), 1, 0)
    newdata$priorcc_none = ifelse(grepl("7", data$POLICY.018_cat), 1, 0)
  }
  
  if(contains_items("POLICY.020\\.a_[0-9]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.020\\.a_[0-9]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.020a_cat")
    newdata$expect_center = ifelse(grepl("1", data$POLICY.020a_cat), 1, 0)
    newdata$expect_relativemyhome = ifelse(grepl("2", data$POLICY.020a_cat), 1, 0)
    newdata$expect_relativetheirhome = ifelse(grepl("3", data$POLICY.020a_cat), 1, 0)
    newdata$expect_promyhome = ifelse(grepl("4", data$POLICY.020a_cat), 1, 0)
    newdata$expect_theirhome = ifelse(grepl("5", data$POLICY.020a_cat), 1, 0)
    newdata$expect_parents = ifelse(grepl("6", data$POLICY.020a_cat), 1, 0)
    newdata$expect_none = ifelse(grepl("7", data$POLICY.020a_cat), 1, 0)
  }
  
  if(contains_items("POLICY.020\\.b_[0-9]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.020\\.b_[0-9]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.020b_cat")
    newdata$expect_age_5_12 = ifelse(grepl("1", data$POLICY.020b_cat), 1, 0)
    newdata$expect_age_13_17 = ifelse(grepl("2", data$POLICY.020b_cat), 1, 0)
    newdata$expect_age_18_29 = ifelse(grepl("3", data$POLICY.020b_cat), 1, 0)
    newdata$expect_age_30_49 = ifelse(grepl("4", data$POLICY.020b_cat), 1, 0)
    newdata$expect_age_50_64 = ifelse(grepl("5", data$POLICY.020b_cat), 1, 0)
    newdata$expect_age_65up = ifelse(grepl("6", data$POLICY.020b_cat), 1, 0)
    newdata$expect_age_unsure = ifelse(grepl("7", data$POLICY.020b_cat), 1, 0)
  }
  
  if(contains_items("POLICY.020\\.c_[0-9]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.020\\.c_[0-9]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.020c_cat")
    newdata$expect_relation_sibling = ifelse(grepl("1", data$POLICY.020c_cat), 1, 0)
    newdata$expect_relation_aunt = ifelse(grepl("2", data$POLICY.020c_cat), 1, 0)
    newdata$expect_relation_grand = ifelse(grepl("3", data$POLICY.020c_cat), 1, 0)
    newdata$expect_relation_relative = ifelse(grepl("4", data$POLICY.020c_cat), 1, 0)
    newdata$expect_relation_friend = ifelse(grepl("5", data$POLICY.020c_cat), 1, 0)
    newdata$expect_relation_neighbor = ifelse(grepl("6", data$POLICY.020c_cat), 1, 0)
  }
  
  if(contains_items("POLICY.021", data)){
    newdata$same_cc = case_when(
      data$POLICY.021 == 1 ~ "Yes",
      data$POLICY.021 == 0 ~ "No",
      data$POLICY.021 == 2 ~ "Don't know")
  }
  if(contains_items("POLICY.022\\.a", data)){
    newdata$willing_same_cc = case_when(
      data$POLICY.022.a == 1 ~ "Yes",
      data$POLICY.022.a == 0 ~ "No",
      data$POLICY.022.a == 2 ~ "Don't know")
  }
  if(contains_items("POLICY.022\\.b_[0-9]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.022\\.b_[0-9]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.022b_cat")
    newdata$barrier_same_cc_cost = ifelse(grepl("1", data$POLICY.022b_cat), 1, 0)
    newdata$barrier_same_cc_safe = ifelse(grepl("2", data$POLICY.022b_cat), 1, 0)
    newdata$barrier_same_cc_need = ifelse(grepl("3", data$POLICY.022b_cat), 1, 0)
  }
  
  if(contains_items("POLICY.023_", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.023_", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.023_cat")
    newdata$comfort_return = case_when(
      grepl("1", data$POLICY.023_cat) ~ "1",
      grepl("2", data$POLICY.023_cat) ~ "2",
      grepl("3", data$POLICY.023_cat) ~ "3",
      grepl("4", data$POLICY.023_cat) ~ "4",
      TRUE ~ NA_character_
    )
  }
  
  if(contains_items("POLICY.024_[0-9]$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("POLICY.024_[0-9]$", data), 
                       id = "CaregiverID",
                       newvar.name = "POLICY.024_cat")
    newdata$know_cc_numchild = ifelse(grepl("1", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_numadult = ifelse(grepl("2", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_socialDis = ifelse(grepl("3", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_cleaning = ifelse(grepl("4", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_childHealth = ifelse(grepl("5", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_employeeHealth = ifelse(grepl("6", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_COVID = ifelse(grepl("7", data$POLICY.024_cat), 1, 0)
    newdata$know_cc_enroll = ifelse(grepl("8", data$POLICY.024_cat), 1, 0)
  }
  
  if(contains_items("POLICY.025", data)){
    newdata$lack_cc = case_when(
      data$POLICY.025 == 1 ~ "Yes",
      data$POLICY.025 == 0 ~ "No",
      data$POLICY.025 == 2 ~ "Don't know")
  }
  
  if(contains_items("HEALTH.005", data)){
    data = combine.cat(x = data, 
                       cols = find_items("HEALTH.005", data), 
                       id = "CaregiverID",
                       newvar.name = "HEALTH.005_cat")
    newdata$disability = ifelse(grepl("[1-4]", data$HEALTH.005_cat), 1, 0)
  }
  
  if(contains_items("HEALTH.001", data)){
    newdata$insurance = ifelse(data$HEALTH.001 == 1, 1, 0)
    #caregiver has insurance through private company
    newdata$HI_private = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_private = ifelse(data$HEALTH.001.a_1 == 1, 1, newdata$HI_private)
    newdata$HI_private[is.na(newdata$HI_private) & !is.na(data$HEALTH.001)] = 0
    #caregiver has insurance through medi-something
    newdata$HI_medi = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_medi = ifelse(data$HEALTH.001.a_2 == 1, 1, newdata$HI_medi)
    newdata$HI_medi = ifelse(data$HEALTH.001.a_3 == 1, 1, newdata$HI_medi)
    newdata$HI_medi = ifelse(data$HEALTH.001.a_2 == 4, 1, newdata$HI_medi)
    newdata$HI_medi[is.na(newdata$HI_medi) & !is.na(data$HEALTH.001)] = 0
    # children's health insurance program
    newdata$HI_CHIP = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_CHIP = ifelse(data$HEALTH.001.a_5 == 1, 1, newdata$HI_CHIP)
    newdata$HI_CHIP[is.na(newdata$HI_CHIP) & !is.na(data$HEALTH.001)] = 0
    #military related
    newdata$HI_military = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_military = ifelse(data$HEALTH.001.a_6 == 1, 1, newdata$HI_military)
    newdata$HI_military[is.na(newdata$HI_military) & !is.na(data$HEALTH.001)] = 0
    #indian health related
    newdata$HI_IHS = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_IHS = ifelse(data$HEALTH.001.a_7 == 1, 1, newdata$HI_IHS)
    newdata$HI_IHS[is.na(newdata$HI_IHS) & !is.na(data$HEALTH.001)] = 0
    #state related
    newdata$HI_state = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_state = ifelse(data$HEALTH.001.a_8 == 1, 1, newdata$HI_state)
    newdata$HI_state[is.na(newdata$HI_state) & !is.na(data$HEALTH.001)] = 0
    #other gov related
    newdata$HI_othergov = ifelse(is.na(data$HEALTH.001), NA, 0)
    newdata$HI_othergov = ifelse(data$HEALTH.001.a_9 == 1, 1, newdata$HI_othergov)
    newdata$HI_othergov[is.na(newdata$HI_othergov) & !is.na(data$HEALTH.001)] = 0
    }
  if(contains_items("HEALTH.002", data)){
    newdata$child_insurance = ifelse(data$HEALTH.002 == 1, 1, 0)
    #child has insurance through private company
    newdata$child_HI_private = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_private = ifelse(data$HEALTH.002.a_1 == 1, 1, newdata$child_HI_private)
    newdata$child_HI_private[is.na(newdata$child_HI_private) & !is.na(data$HEALTH.002)] = 0
    #child has insurance through medi-something
    newdata$child_HI_medi = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_medi = ifelse(data$HEALTH.002.a_2 == 1, 1, newdata$child_HI_medi)
    newdata$child_HI_medi = ifelse(data$HEALTH.002.a_3 == 1, 1, newdata$child_HI_medi)
    newdata$child_HI_medi = ifelse(data$HEALTH.002.a_2 == 4, 1, newdata$child_HI_medi)
    newdata$child_HI_medi[is.na(newdata$child_HI_medi) & !is.na(data$HEALTH.002)] = 0
    # cchild_HIldren's health insurance program
    newdata$child_HI_Cchild_HIP = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_Cchild_HIP = ifelse(data$HEALTH.002.a_5 == 1, 1, newdata$child_HI_Cchild_HIP)
    newdata$child_HI_Cchild_HIP[is.na(newdata$child_HI_Cchild_HIP) & !is.na(data$HEALTH.002)] = 0
    #military related
    newdata$child_HI_military = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_military = ifelse(data$HEALTH.002.a_6 == 1, 1, newdata$child_HI_military)
    newdata$child_HI_military[is.na(newdata$child_HI_military) & !is.na(data$HEALTH.002)] = 0
    #indian health related
    newdata$child_HI_IHS = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_IHS = ifelse(data$HEALTH.002.a_7 == 1, 1, newdata$child_HI_IHS)
    newdata$child_HI_IHS[is.na(newdata$child_HI_IHS) & !is.na(data$HEALTH.002)] = 0
    #state related
    newdata$child_HI_state = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_state = ifelse(data$HEALTH.002.a_8 == 1, 1, newdata$child_HI_state)
    newdata$child_HI_state[is.na(newdata$child_HI_state) & !is.na(data$HEALTH.002)] = 0
    #other gov related
    newdata$child_HI_othergov = ifelse(is.na(data$HEALTH.002), NA, 0)
    newdata$child_HI_othergov = ifelse(data$HEALTH.002.a_9 == 1, 1, newdata$child_HI_othergov)
    newdata$child_HI_othergov[is.na(newdata$child_HI_othergov) & !is.na(data$HEALTH.002)] = 0
    }
  
  
  
  if(contains_items("HEALTH.003", data)) {
    num_delay_healthcare = rowSums(data[,find_items("HEALTH.003.[a-f]$", data)],na.rm=T)
    newdata$delay_healthcare = ifelse(num_delay_healthcare > 0, 1, 0)
    newdata$hc_barrier_cost = ifelse(data$HEALTH.003.a > 0, 1, 0)
    newdata$hc_barrier_time = ifelse(data$HEALTH.003.b > 0, 1, 0)
    newdata$hc_barrier_childcare = ifelse(data$HEALTH.003.c > 0, 1, 0)
    newdata$hc_barrier_covid = ifelse(data$HEALTH.003.d > 0, 1, 0)
    newdata$hc_barrier_family = ifelse(data$HEALTH.003.e > 0, 1, 0)
    newdata$hc_barrier_other = ifelse(data$HEALTH.003.f > 0, 1, 0)
  }
  
  if(contains_items("HEALTH.004", data)) {
    missed_wellbaby = ifelse(data$HEALTH.004 == 1, 1, 0)
    newdata$missed_wellbaby = missed_wellbaby
    newdata$which_wellbaby_missed.1 = data$HEALTH.009.a
    newdata$which_wellbaby_missed.2 = data$HEALTH.010.a
    newdata$which_wellbaby_missed.3 = data$HEALTH.011.a
    newdata$which_wellbaby_missed.4 = data$HEALTH.012.a
    newdata$which_wellbaby_missed.5 = data$HEALTH.013.a
    
    newdata$miss_vaccine.1 = case_when(
      data$HEALTH.004 != 1 ~ 0,
      data$HEALTH.009.a == 1 ~ 1, 
      data$HEALTH.009.a == 0 ~ 0, 
      TRUE ~ NA_real_)

    newdata$miss_vaccine.2 = data$HEALTH.010.b
    newdata$miss_vaccine.3 = data$HEALTH.011.b
    newdata$miss_vaccine.4 = data$HEALTH.012.b
    newdata$miss_vaccine.5 = data$HEALTH.013.b

  }
  
  if(contains_items("HEALTH\\.014", data)){
    data = combine.cat(x = data, 
                       cols = find_items("HEALTH\\.014_[0-9]{1,2}$", data), 
                       id = "CaregiverID",
                       newvar.name = "HEALTH.014_cat")
    newdata$source_trump = ifelse(grepl("1", data$HEALTH.014_cat), 1, 0)
    newdata$source_uspublic = ifelse(grepl("2", data$HEALTH.014_cat), 1, 0)
    newdata$source_congress = ifelse(grepl("3", data$HEALTH.014_cat), 1, 0)
    newdata$source_gov = ifelse(grepl("4", data$HEALTH.014_cat), 1, 0)
    newdata$source_state = ifelse(grepl("5", data$HEALTH.014_cat), 1, 0)
    newdata$source_employ = ifelse(grepl("6", data$HEALTH.014_cat), 1, 0)
    newdata$source_nonemploy = ifelse(grepl("7", data$HEALTH.014_cat), 1, 0)
    newdata$source_child = ifelse(grepl("8", data$HEALTH.014_cat), 1, 0)
    newdata$source_nonchild = ifelse(grepl("9", data$HEALTH.014_cat), 1, 0)
    newdata$source_family = ifelse(grepl("10", data$HEALTH.014_cat), 1, 0)
    newdata$source_friends = ifelse(grepl("11", data$HEALTH.014_cat), 1, 0)
    newdata$source_other = ifelse(grepl("12", data$HEALTH.014_cat), 1, 0)

  }
  
  if(contains_items("COVID.001", data)){
    newdata$suspected_covid = ifelse(data$COVID.001 %in% c(1,2,3), 1, 0)
    newdata$diagnosed_covid = ifelse(data$COVID.001 %in% c(2,3), 1, 0)
  }
  
  if(contains_items("COVID.002", data)){
    newdata$hospital = ifelse(data$COVID.002 %in% c(1,2), 1, 0)
    newdata$hospital_covid  = ifelse(data$COVID.002 == 2, 1, 0)
  }
  
  if(contains_items("GAD2.002", data)){
    anxiety_current = rowMeans(data[,find_items("GAD2.002.[a-b]$", data)], na.rm=T)
    newdata$anxiety_current_some = ifelse(anxiety_current > 0, 1, 0)
    newdata$anxiety_current_lots = ifelse(anxiety_current > 1, 1, 0)
    newdata$anxiety = anxiety_current
  }
  if(contains_items("GAD2.001", data)){
    anxiety_pre = rowMeans(data[,find_items("GAD2.001.[a-b]$", data)], na.rm=T)
    anxiety_change = anxiety_current = anxiety_pre
    newdata$anxiety_pre_some = ifelse(anxiety_pre > 0, 1, 0)
    newdata$anxiety_pre_lots = ifelse(anxiety_pre > 1, 1, 0)
    newdata$anxiety_increase = ifelse(anxiety_change > 0, 1, 0)
    newdata$anxiety_pre = anxiety_pre
  }
  
  if(contains_items("PHQ.002", data)){
    depress_current = rowMeans(data[,find_items("PHQ.002.[a-b]$", data)], na.rm=T)
    newdata$depress_current_some = ifelse(depress_current > 0, 1, 0)
    newdata$depress_current_lots = ifelse(depress_current > 1, 1, 0)
    newdata$depress = depress_current
  }
  
  if(contains_items("PHQ.001", data)){
    depress_pre = rowMeans(data[,find_items("PHQ.001.[a-b]$", data)], na.rm=T)
    newdata$depress_pre_some = ifelse(depress_pre > 0, 1, 0)
    newdata$depress_pre_lots = ifelse(depress_pre > 1, 1, 0)
    depress_change = depress_current - depress_pre
    newdata$depress_pre = depress_pre
    newdata$depress_increase  = ifelse(depress_change > 0, 1, 0)
    newdata$depress_pre = depress_pre
  }
  
  if(contains_items("STRESS.002", data)){
    newdata$stress_current_some = ifelse(data$STRESS.002 > 0, 1, 0)
    newdata$stress_current_lots = ifelse(data$STRESS.002 > 2, 1, 0)
    newdata$stress = data$STRESS.002
  }
  if(contains_items("STRESS.001", data)){
    stress_change = data$STRESS.002 - data$STRESS.001
    newdata$stress_pre_some = ifelse(data$STRESS.001 > 0, 1, 0)
    newdata$stress_pre_lots = ifelse(data$STRESS.001 > 2, 1, 0)
    newdata$stress_increase  = ifelse(stress_change > 0, 1, 0)
    newdata$stress_pre = data$STRESS.001
  }
  
  
  if(contains_items("PSIIV.001.a", data)){
    newdata$handle_pre = ifelse(data$PSIIV.001.a > 3, 1, 0)
    handle_change = data$PSIIV.001.b - data$PSIIV.001.a
    newdata$handle_decrease = ifelse(handle_change < 0, 1, 0)
  }
  
  if(contains_items("PSIIV.001.b", data)){
    newdata$handle_current = ifelse(data$PSIIV.001.b > 3, 1, 0)
  }
  
  if(contains_items("PSIIV.002", data)){
    newdata$support_pre = ifelse(data$PSIIV.002 %in% c(1,2), 1, 0)
    support_change = data$PSIIV.003 - data$PSIIV.002
    newdata$support_decrease = ifelse(support_change < 0, 1, 0)
  }
  
  if(contains_items("PSIIV.003", data)){
    newdata$support_pre = ifelse(data$PSIIV.003 %in% c(1,2), 1, 0)
  }
  
  if(contains_items("LONE.001.b", data)){
    newdata$lonely_current_some = ifelse(data$LONE.001.b > 1, 1, 0)
    newdata$lonely_current_lots = ifelse(data$LONE.001.b > 2, 1, 0)
    newdata$lonely = data$LONE.001.b
  }
  if(contains_items("LONE.001.a", data)){
    newdata$lonely_pre_some = ifelse(data$LONE.001.a > 1, 1, 0)
    newdata$lonely_pre_lots = ifelse(data$LONE.001.a > 2, 1, 0)
    newdata$lonely_pre = data$LONE.001.a
    
    lone_change = data$LONE.001.b - data$LONE.001.a
    newdata$lone_increase = ifelse(lone_change > 0, 1, 0)
  }
  
  
  if(contains_items("JOB.001_[1,2,3]_TEXT", data)){
    income_weeklybased = suppressWarnings(as.numeric(data$JOB.001_1_TEXT)*52)
    income_monthlybased = suppressWarnings(as.numeric(data$JOB.001_2_TEXT)*12)
    income_yearlybased = suppressWarnings(as.numeric(data$JOB.001_3_TEXT))
    income.mat = cbind(income_weeklybased, income_monthlybased, income_yearlybased)
    inc.missing = apply(income.mat, 1, function(x) length(which(is.na(x))))
    income = rowSums(income.mat, na.rm=T)
    income[which(inc.missing == 3)] = NA
    newdata$income = income
    income = income/1000
    newdata$income.cat = cut(income, breaks =  quantile(income, probs = c(0, .25, .5, .75, 1), na.rm=T))
    newdata$lowincome = ifelse(newdata$income < 40000, 1, 0)
  }
  
  
  if(contains_items("JOB.005", data)){
    data = combine.cat(x = data, 
                       cols = find_items("JOB.005", data), 
                       id = "CaregiverID",
                       newvar.name = "Job.005_cat")
    newdata$free_food = ifelse(grepl("1", data$Job.005_cat), 1, 0)
  }
  
  
  if(contains_items("JOB.007", data)){
    data = combine.cat(x = data, 
                       cols = find_items("JOB.007", data), 
                       id = "CaregiverID",
                       newvar.name = "Job.007_cat")
    free_lunch_current = ifelse(grepl("2",data$Job.007_cat), 1, 0)
    newdata$free_lunch_current = free_lunch_current}
  
  if(contains_items("JOB.006", data)){
    data = combine.cat(x = data, 
                       cols = find_items("JOB.006", data), 
                       id = "CaregiverID",
                       newvar.name = "Job.006_cat")
    free_lunch_pre = ifelse(grepl("2",data$Job.006_cat), 1, 0)
    
    newdata$free_lunch_pre = free_lunch_pre
    
    newdata$lost_free_lunch = case_when(free_lunch_pre == 0 ~ 0,
                                        free_lunch_pre == 1 & free_lunch_current == 1 ~ 0,
                                        free_lunch_pre == 1 & free_lunch_current == 0 ~ 1,
                                        TRUE ~ NA_real_)
    newdata$gained_free_lunch = case_when(free_lunch_pre == 1 ~ 0,
                                          free_lunch_pre == 0 & free_lunch_current == 1 ~ 1,
                                          free_lunch_pre == 0 & free_lunch_current == 0 ~ 0,
                                          TRUE ~ NA_real_)
  }
  if(contains_items("JOB.009", data)){
    data = combine.cat(x = data, 
                       cols = find_items("JOB.009", data), 
                       id = "CaregiverID",
                       newvar.name = "Job.009_cat")
    newdata$unemployed = ifelse(grepl("5", data$Job.009_cat), 1, 0)
    }
  
  if(contains_items("JOB.011", data)) newdata$employment_decreased = ifelse(data$JOB.011 == 2, NA, data$JOB.011)
  
  if(contains_items("JOB.013", data)) newdata$sick_leave = ifelse(data$JOB.013 == 2, NA, data$JOB.013)
  
  if(contains_items("JOB.014", data)){
    losejob_sickleave = ifelse(data$JOB.014 == 5, NA, data$JOB.014)
    newdata$losejob_sickleave = ifelse(losejob_sickleave > 2, 1, 0)
  } 
  
  
  if(contains_items("JOB.015", data)) newdata$unemployment = ifelse(data$JOB.015 == 1, 1, 0)
  
  if(contains_items("EHQ.001", data)){
    newdata$income_change = data$EHQ.001
    newdata$income_decreaed = ifelse(data$EHQ.001 == 1, 1, 0)
    }
  
  if(contains_items("EHQ.002", data)){
    newdata$financial_prob  = ifelse(data$EHQ.002 == 0, 0, 1)
    newdata$major_financial  = ifelse(data$EHQ.002 %in% c(0,1), 0, 1)
  }
  
  if(contains_items("FSTR.001", data))newdata$difficulty_basics  = ifelse(data$FSTR.001 %in% c(3,2), 1, 0)
  if(contains_items("FSTR.002", data)){
    data = combine.cat(x = data, 
                       cols = find_items("FSTR.002_.{1}$", data), 
                       id = "CaregiverID",
                       newvar.name = "FSTR.002_cat")
    newdata$diff_pay_food = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("1", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_house = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("2", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_utilities = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("3", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_healthcare = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("4", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_social = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("5", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_emotional = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("6", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_childcare = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("7", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
    newdata$diff_pay_other = case_when(
      data$FSTR.001 == 0 ~ 0, 
      grepl("8", data$FSTR.002_cat) ~ 1,
      TRUE ~ NA_real_)
  }
  if(contains_items("CBCL.002.a", data)){
    newdata$fussy_current_some = ifelse(data$CBCL.002.a > 0, 1, 0)
    newdata$fussy_current_lots = ifelse(data$CBCL.002.a > 1, 1, 0)
    newdata$fussy = data$CBCL.002.a 
  }
  if(contains_items("CBCL.001.a", data)){
    newdata$fussy_pre = data$CBCL.001.a
    newdata$fussy_pre_some = ifelse(data$CBCL.001.a > 0, 1, 0)
    newdata$fussy_pre_lots = ifelse(data$CBCL.001.a > 1, 1, 0)
    fussy_difference = data$CBCL.002.a-data$CBCL.001.a
    newdata$fussy_more = ifelse(fussy_difference > 0, 1, 0)
  }
  
  if(contains_items("CBCL.002.b", data)){
    newdata$fear_current_some = ifelse(data$CBCL.002.b > 0, 1, 0)
    newdata$fear_current_lots = ifelse(data$CBCL.002.b > 1, 1, 0)
    newdata$fear = data$CBCL.002.b
  }
  if(contains_items("CBCL.002.a", data)){
    newdata$fear_pre = data$CBCL.002.a
    newdata$fear_pre_some = ifelse(data$CBCL.002.a > 0, 1, 0)
    newdata$fear_pre_lots = ifelse(data$CBCL.002.a > 1, 1, 0)
    fear_difference = data$CBCL.002.a-data$CBCL.002.a
    newdata$fear_more = ifelse(fear_difference > 0, 1, 0)
  }
  
  
  if(contains_items("HEALTH.005", data)){
    data = combine.cat(x = data, 
                       cols = find_items("HEALTH.005_[0-9]{1}$", data), 
                       id = "CaregiverID",
                       newvar.name = "HEALTH.005_cat")
    newdata$disability = ifelse(grepl("[1-4]", data$HEALTH.005_cat), 1, 0)
  }
  
  if(contains_items("JOB.010", data)){
    data = combine.cat(x = data, 
                       cols = find_items("JOB.010_.{1,2}$", data),
                       id = "CaregiverID",
                       newvar.name = "JOB.010_cat")
    data$JOB.010_cat = gsub("10", "0", data$JOB.010_cat)
    newdata$working_pre = ifelse(grepl("[1,2,6]", data$JOB.010_cat), 1, 0)
  }
  
  if(contains_items("JOB.008", data)){
    data = combine.cat(x = data, 
                       cols = find_items("JOB.008_.{1,2}$", data),
                       id = "CaregiverID",
                       newvar.name = "JOB.008_cat")
    data$JOB.008_cat = gsub("10", "0", data$JOB.008_cat)
    newdata$working_current = ifelse(grepl("[1,2,6]", data$JOB.008_cat), 1, 0)
  }
  
  
  if(contains_items("JOB.012", data)) newdata$essential = ifelse(data$JOB.012 == 1, 1, 0)
  
  if(contains_items("FamCon", data)){
    #scrub 6s
    FamCon_items = find_items("FamCon", data)
    FamCon_items = FamCon_items[FamCon_items != "FamCon.015"]
    data = psych::scrub(data, where = FamCon_items, isvalue = 6)
    # total conflict
    total_conflict_items = c(find_items("FamCon.00.", data), find_items("FamCon.010", data))
    newdata$conflict_total = rowMeans(data[,str_subset(total_conflict_items, "a$")], na.rm=T)
    newdata$conflict_total_pre = rowMeans(data[,str_subset(total_conflict_items, "b$")], na.rm=T)
    # parent conflict
    parent_conflict_items = find_items("FamCon.00[1,5]", data)
    newdata$conflict_parent = rowMeans(data[,str_subset(parent_conflict_items, "a$")], na.rm=T)
    newdata$conflict_parent_pre = rowMeans(data[,str_subset(parent_conflict_items, "b$")], na.rm=T)
    # child conflict
    child_conflict_items = c(find_items("FamCon.00[^145]", data), find_items("FamCon.010", data))
    newdata$conflict_child = rowMeans(data[,str_subset(child_conflict_items, "a$")], na.rm=T)
    newdata$conflict_child_pre = rowMeans(data[,str_subset(child_conflict_items, "b$")], na.rm=T)
    #cohesivness
    cohesive_items = find_items("FamCon.01[1-4]", data)
    newdata$cohesive = rowMeans(data[,str_subset(cohesive_items, "a$")], na.rm=T)
    newdata$cohesive_pre = rowMeans(data[,str_subset(cohesive_items, "b$")], na.rm=T)
    
    newdata$conflictSource = data$FamCon.015
  }  
  
  if(contains_items("DEMO.002", data)){
    data = data %>%
      mutate(single = case_when(
        DEMO.002 %in% c(3,4,5,7,8) ~ 1,
        DEMO.011 %in% c(2,4) ~ 1, 
        !is.na(DEMO.002) ~ 0,
        !is.na(DEMO.011) ~ 0,
        TRUE ~ NA_real_))
    newdata$single = data$single}
  
  if(contains_items("DEMO.003", data)){
      newdata$num_children = case_when(
      data$DEMO.003 == 1 ~ "1 Child",
      data$DEMO.003 == 2 ~ "2 Children",
      data$DEMO.003 == 3 ~ "3 Children",
      data$DEMO.003 >= 4 ~ "4+ Children")
      newdata$num_children_raw = data$DEMO.003
      newdata$household_size = data$DEMO.005
  }
  
  if(contains_items("DEMO.011", data)){
    newdata$living_arrange = data$DEMO.011
  }
  
  if(contains_items("DEMO.006", data)){
    newdata$gender = case_when(
      data$DEMO.006 == 0 ~ "Male",
      data$DEMO.006 == 1 ~ "Female",
      data$DEMO.006 %in% c(3, 4, 5, 6) ~ "Other",
      TRUE ~ NA_character_
      )
  }
  
  if(contains_items("DEMO.007_.{1}$", data)){
    data = combine.cat(x = data, 
                       cols = find_items("DEMO.007_.{1}$", data), 
                       id = "CaregiverID",
                       newvar.name = "DEMO.007_cat")
    newdata$minority = ifelse(grepl("[^5]", data$DEMO.007_cat), 1, 0)
    newdata$black = ifelse(grepl("3", data$DEMO.007_cat), 1, 0)
    newdata$native = ifelse(grepl("1", data$DEMO.007_cat), 1, 0)
    newdata$asian = ifelse(grepl("2", data$DEMO.007_cat), 1, 0)
    newdata$hawaii = ifelse(grepl("4", data$DEMO.007_cat), 1, 0)
    newdata$white = ifelse(grepl("5", data$DEMO.007_cat), 1, 0)
    newdata$other_race = ifelse(grepl("6", data$DEMO.007_cat), 1, 0)
    newdata$race_cat = case_when(
      data$DEMO.007_cat == "1" ~ "American Indian/Alaska Native",
      data$DEMO.007_cat == "2" ~ "Asian",
      data$DEMO.007_cat == "3" ~ "Black/African American",
      data$DEMO.007_cat == "4" ~ "Native Hawaiian/Pacific Islander",
      data$DEMO.007_cat == "5" ~ "White/Caucasian",
      data$DEMO.007_cat == "6" ~ "Other race",
      !is.na(data$DEMO.007_cat) ~ "Multiple races",
      TRUE ~ NA_character_)
    }
  
  if(contains_items("DEMO.008", data)){
    data = data %>%
      mutate(latinx = case_when(
        DEMO.008 == 1 ~ 1,
        DEMO.008 == 0 ~ 0,
        DEMO.008.2 == 0 ~ 0,
        DEMO.008.2 == 1 ~ 1,
        DEMO.008.2 == 2 ~ 1,
        TRUE ~ NA_real_
      ))
    
    newdata$latinx = data$latinx
    }
  
  if(contains_items("DEMO.001", data)){
    state = unlist(sapply(data$DEMO.001, identify_state))
    newdata$zip = data$DEMO.001
    newdata = mutate(newdata, zip = ifelse(zip == "", NA, zip))
    newdata$state = state
    data$state = state_abr(data$DEMO.001.a)
    newdata$state[is.na(newdata$state)] = data$state[is.na(newdata$state)]
    newdata$region = case_when(
      state %in% c("ME", "NH", "VT", "MA", "RI", "CT",
                   "NY", "NJ", "PA") ~ "Northeast",
      state %in% c("OH", "MI", "IL", "IN", "WI", "MN", "IA",
                   "MO", "ND", "SD", "NE", "KS") ~ "Midwest",
      state %in% c("DC","DE", "MD", "VA", "WV", "KY", "NC", "SC",
                   "TN", "GA", "FL", "AL", "MS", "AR", "LA",
                   "TX", "OK") ~ "South",
      state %in% c("MT", "ID", "WY", "CO", "NM", "AZ",
                   "UT", "NV", "CA", "OR", "WA", "AK",
                   "HI") ~ "West")
  }
  
  newdata$poverty = data$FPL.150
  newdata$poverty100 = data$FPL.100
  newdata$poverty125 = data$FPL.125
  newdata$poverty150 = data$FPL.150
  newdata$poverty200 = data$FPL.200
  
  return(newdata)
}
