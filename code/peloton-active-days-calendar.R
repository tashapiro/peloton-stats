library(ggplot2)
library(lubridate)
library(tidyverse)

#read in Peloton Data (collected from pelotonR wrapper)
df<-read.csv("../data/peloton_data.csv")
df$end_date<-as.Date(strptime(df$end_time, "%Y-%m-%d %H:%M:%S"))

#function to produce calendar
get_calendar <- function(start_date, end_date) {
  n_days <- interval(start_date,end_date)/days(1)
  date<-start_date + days(0:n_days)
  month_name<-format(date,"%B")
  month_num<-format(date,"%m")
  year<-format(date,"%Y")
  day_num<-format(date,'%d')
  day<-wday(date, label=TRUE)
  week_num<-strftime(date, format = "%V")
  cal<-data.frame(date, year, month_name, month_num, day_num, day, week_num)
  cal[cal$week_num>=52 & cal$month_num=="01","week_num"]=00
  
  week_month<-cal%>% 
    group_by(year,month_name, week_num)%>%
    summarise()%>%
    mutate(week_month_num=row_number())
  
  cal<-merge(cal, week_month, by=c("month_name"="month_name","week_num"="week_num","year"="year"))
  cal$month_name<-factor(cal$month_name, levels=c("January","February","March","April","May","June","July","August","September","October","November","December"))
  cal$day<-factor(cal$day, levels=c("Mon","Tue","Wed","Thu","Fri","Sat","Sun"))
  
  return(cal)
  
}

#create date range
start_date <- as.Date('2021-01-01')
end_date <- as.Date('2021-12-31')

#create calendar
cal<-get_calendar(start_date,end_date)

#summarise workout information
workout_by_day<-df%>%
  group_by(end_date)%>%
  summarise(workouts=n(), 
            workout_min = sum(ride_duration)/60,
            class_type = paste(unique(fitness_discipline), collapse=","))%>%
  rename(date = end_date)%>%
  mutate(did_workout=1,
         cardio= case_when(grepl("running|cycling|bike_bootcamp|circuit",class_type)~1,TRUE~0),
         strength = case_when(grepl("strength|circuit|bike_bootcamp",class_type)~1,TRUE~0))%>%
  mutate(type = case_when(cardio==1 & strength==1~"Cardio & Strength",
                          cardio==1 & strength==0~"Cardio",
                          cardio==0 & strength==1~"Strength",
                          TRUE~"Other"))%>%
  arrange(date)

#create a factor out of class types
workout_by_day$type<-factor(workout_by_day$type, levels=c("Cardio & Strength","Cardio","Strength","Other"))

#merge workout info summary with calendar, left join to preserve all calendar days (all.x=TRUE)
cal_workout<-merge(cal,workout_by_day, by=c("date"="date"), all.x=TRUE)

#custom color paleette
pal<-c('#26547c', '#ef476f', '#FFBC1F', '#05C793')

#creating the plot
ggplot(cal_workout)+
  geom_tile(mapping=aes(x=day,y=week_month_num),fill=NA)+
  geom_text(mapping=aes(x=day, y=week_month_num, label=day_num), color="black", family="Gill Sans")+
  geom_point(data = cal_workout%>%filter(did_workout==1), mapping=aes(x=day,y=week_month_num, color=type), size=8)+
  geom_text(data = cal_workout%>%filter(did_workout==1), mapping=aes(x=day, y=week_month_num, label=day_num), color="white", family="Gill Sans")+
  scale_y_reverse()+
  scale_color_manual(values=pal,
                     guide = guide_legend(title.position  ="top", title.hjust = 0.5, title="Workout Type"))+
  coord_fixed()+
  labs(y="", x= "", 
       title='PELOTON ACTIVE DAYS 2021',
       subtitle="Cardio includes running, cycling, and bootcamps. Strength includes strength classes and bootcamps.",
       caption="Personal workout data from Peloton API | Chart by @tanya_shapiro")+
  facet_wrap(~month_name)+
  theme(
    text=element_text(family="Gill Sans"),
    legend.position="top",
    axis.text.y=element_blank(),
    axis.ticks = element_blank(),
    panel.background = element_blank(),
    plot.title=element_text(hjust=0.5, family="Gill Sans Bold", size=18),
    plot.subtitle=element_text(hjust=0.5, size=12),
    legend.key = element_blank(),
    legend.spacing.x = unit(0.5, 'cm'),
    plot.margin= unit(c(0.8,0,0.4,0), "cm"),
  )


  
  