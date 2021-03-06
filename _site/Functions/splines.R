splines.overall = function(data, outcome, point){
  
  data = data %>%
    mutate(SL1 = ifelse(Week <= point, Week-point, 0),
           SL2 = ifelse(Week > point, Week-point, 0))
  
  reg.formula = as.formula(paste0(deparse(substitute(outcome)),
                                  " ~ SL1 + SL2 + (1|CaregiverID)")) 
  model = lmer(reg.formula, data)
  
  mod.summary = broom::tidy(model) 
  mod.summary = mod.summary %>%
    mutate(pvalue = pt(abs(statistic), 
                       df = nrow(data)-nrow(mod.summary), 
                       lower.tail = F)*2) %>%
    filter(!grepl("^sd_", term)) %>%
    select(-group) %>%
    kable(., digits = 2) %>%
    kable_styling()
  
  predicted = data.frame(Week = 1:10,
                         CaregiverID = 0000) %>%
    mutate(SL1 = ifelse(Week <= point, Week-point, 0),
           SL2 = ifelse(Week > point, Week-point, 0))
  
  predicted$fit = predict(model, 
                          newdata = predicted, 
                          allow.new.levels = T)
  
  plot = data %>%
    filter(!is.na({{outcome}})) %>%
    group_by(Week) %>%
    summarize(m = mean({{outcome}}),
              sd = sd({{outcome}}),
              n = n(),
              se = sd/sqrt(n),
              moe = 1.96*se) %>%
    ggplot(aes(x = Week, y = m)) +
    geom_point(color = "darkgrey") +
    geom_line(aes(x = Week, y = fit), data = predicted, inherit.aes = F) +
    scale_x_continuous(breaks = c(1:10))+
    scale_y_continuous(str_to_title(deparse(substitute(outcome))))+
    theme_pubclean()
  
  return.list = list(model = model,
                     summary = mod.summary,
                     pdata = predicted,
                     plot = plot)
  return(return.list)
}

splines.groups = function(data, outcome, group, point){
  
  group.name = deparse(substitute(group))
  
  color.pal = c("red", "darkgrey")
  
  data = data %>%
    filter(!is.na({{group}})) %>%
    mutate(SL1 = ifelse(Week <= point, Week-point, 0),
           SL2 = ifelse(Week > point, Week-point, 0))
  
  reg.formula = as.formula(paste0(deparse(substitute(outcome)),
                                  " ~ SL1*",
                                  deparse(substitute(group)),
                                  "+ SL2*",
                                  deparse(substitute(group)),
                                  "+ (1|CaregiverID)")) 
  model = lmer(reg.formula, data)
  
  mod.summary = broom::tidy(model) 
  mod.summary = mod.summary %>%
    mutate(pvalue = pt(abs(statistic), 
                       df = nrow(data)-nrow(mod.summary), 
                       lower.tail = F)*2) %>%
    filter(grepl(group.name,term)) %>%
    select(-group) %>%
    kable(., digits = 2) %>%
    kable_styling()
  
  predicted = data %>% 
    group_by(Week, {{group}}) %>% 
    summarize(n=n()) %>%
    mutate(CaregiverID = 0000,
           SL1 = ifelse(Week <= point, Week-point, 0),
           SL2 = ifelse(Week > point, Week-point, 0))

  predicted$fit = predict(model, 
                          newdata = predicted, 
                          allow.new.levels = T)
  
  plot = data %>%
    filter(!is.na({{outcome}})) %>%
    group_by(Week, {{group}}) %>%
    summarize(m = mean({{outcome}}),
              sd = sd({{outcome}}),
              n = n(),
              se = sd/sqrt(n),
              moe = 1.96*se) %>%
    ggplot(aes(x = Week, y = m, color = as.factor({{group}}))) +
    geom_point(alpha = .5) +
    geom_line(aes(x = Week, y = fit, color = as.factor({{group}})), 
                  data = predicted, 
                  inherit.aes = F) +
    scale_color_manual(str_to_title(deparse(substitute(group))),
                                   values = color.pal, 
                                   labels = c("Group", "Everyone else")) +            
    scale_x_continuous(breaks = c(1:10))+
    scale_y_continuous(str_to_title(deparse(substitute(outcome))))+
    theme_pubclean()
  
  return.list = list(model = model,
                     summary = mod.summary,
                     pdata = predicted,
                     plot = plot)
  return(return.list)
}

group.diff = function(data, outcome, group, week){
  data = data %>%
    filter(Week == week) %>%
    filter(!is.na({{group}}) & !is.na({{outcome}})) %>%
    rename(outcome = {{outcome}}) %>%
    rename(group = {{group}})
  
  ttest = t.test(outcome~group, data = data)
  
  output = broom::tidy(ttest)[1:8]
  cohens = effsize::cohen.d.formula(outcome~group, data = data)
  names(output) = c("Cohen's D", "Everyone Else", "Group", "t-statistic", "p-value", "df", "Conf.Low", "Conf.High", "Cohen's D")
  output$`Cohen's D` = -1*cohens$estimate
  output = kable(output, digits = c(2,2,2,2,3,2,2,2), 
                 caption = paste0("Differences in ", deparse(substitute(outcome)), " at Week ", week)) %>% kable_styling()
  return(output)
  
}
