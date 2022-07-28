library(highcharter)
library(tidyverse)

#import data
df <- read.csv("https://raw.githubusercontent.com/tashapiro/peloton-stats/main/data/peloton_data.csv")

#clean up fitness discipline name, e.g. "bike_bootcamp" becomes "Bike Bootcamp"
df<-df%>%mutate(fitness_discipline=str_to_title(str_replace_all(fitness_discipline,"_"," ")))

#create parent dataset, aggregate by fitness discipline
group<-df%>%
  group_by(fitness_discipline)%>%
  summarise(workouts=n(),
            workout_time = sum(ride_duration,na.rm=TRUE)/60)%>%
  mutate(drilldown=fitness_discipline)%>%
  arrange(-workout_time)

#image url for instructors, use this later for axis labels on drilldown (by instructor)
base_image_url<-'https://raw.githubusercontent.com/tashapiro/peloton-stats/main/images/instructors-cropped/'

#create drilldown dataset (ested lists by fitness discipline_
subgroups = list()
for(i in unique(df$fitness_discipline)){
  data=df%>%
    filter(!is.na(instructor) & fitness_discipline==i)%>%
    #create new group by field, image, use HTML tags to pass in the image url
    group_by(image = paste0('<span>',instructor,' ','<img src="',base_image_url,str_replace_all(instructor," ","_"),
                            '.png" style="width: 30px; vertical-align: middle"></span>'))%>%
    #important that datset contains "value" and "name" for mapping! 
    summarise(value= sum(ride_duration,na.rm=TRUE)/60)%>%
    rename(name=image)%>%
    arrange(-value)
  #append dataset to list as a list, set id to fitness_discipline name (parent id)
  sub = list(id=i, type="bar", name =i, data=list_parse2(data))
  #store to master list
  subgroups <- append(subgroups,list(sub))
}

highchart()%>%
  hc_xAxis(type = "category",
           #set useHTML to TRUE to render images for drilldown
           labels= list(useHTML=TRUE)) %>%
  hc_plotOptions(
    series = list(
      boderWidth = 0,
      dataLabels = list(enabled = TRUE)
    )
  )%>%
  hc_add_series(
    data = group,
    type = "bar",
    hcaes(name = fitness_discipline, y = workout_time),
    name = "Discipline"
  )%>%
  hc_drilldown(
    allowPointDrilldown = TRUE,
    series = subgroups
  )%>%
  hc_colors("#F76B00")%>%
  #create custom theme
  hc_add_theme(
    hc_theme(
      chart=list(backgroundColor = NULL,
                 style=list(fontFamily="sans-serif")),
      xAxis= list(
        labels=list(style=list(color="black"))
      ),
      yAxis = list(
        gridLineColor = "#F0F0F0"),
      drilldown=list(
        activeAxisLabelStyle=list(color="black"),
        activeDataLabelStyle=list(color="black")
      )
    )
  )
