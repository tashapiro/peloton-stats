library(tidyverse)
library(reactablefmtr)
library(sysfonts)
library(showtext)
library(htmltools)
library(htmlwidgets)

#use this url to append instructor images later in reactable
base_image_url<-'https://raw.githubusercontent.com/tashapiro/peloton-stats/main/images/instructors-cropped/'

#import data
df<-read.csv("https://raw.githubusercontent.com/tashapiro/peloton-stats/main/data/peloton_data.csv")
df$month<-format(as.Date(df$start_time),'%Y-%m')

#BIG TABLE, group data by instructor ----
summary<-df|>
  group_by(image_path = paste0(base_image_url,str_replace_all(instructor," ","_"),".png"),
           instructor)|>
  filter(start_year==2022 & !fitness_discipline %in% c("meditation","stretching"))|>
  summarise(workouts=n(),
            minutes = sum(ride_duration)/60,
            difficulty = round(weighted.mean(avg_difficulty,w=ride_duration),2))|>
  arrange(-workouts, -minutes)|>
  ungroup()|>
  mutate(rank=row_number())|>
  select(rank, image_path, instructor, workouts, minutes, difficulty)

#data for monthly trendlines by instructor
months<-df|>
  filter(!is.na(instructor) & start_year==2022 & !fitness_discipline %in% c("meditation","stretching"))|>
  group_by(instructor,month)|>
  summarise(workouts=n())|>
  complete(month=c("2022-01","2022-02","2022-03","2022-04","2022-05","2022-06","2022-07"))|>
  mutate(workouts=replace_na(workouts,0))|>
  group_by(instructor)|>
  summarise(workout_data = list(workouts), .groups = "drop")

#get to modal (or fitness discipline) by instructor
top_modal<-df|>
  filter(!is.na(instructor) & start_year==2022 & !fitness_discipline %in% c("meditation","stretching"))|>
  group_by(instructor, discipline=str_to_title(str_replace_all(fitness_discipline,"_"," ")))|>
  summarise(workouts=n(),
            time = sum(ride_duration))|>
  arrange(instructor, -time)|>
  group_by(instructor)|>
  slice_max(order_by=time, n=1)|>
  slice_max(order_by=workouts, n=1)

#combine summary by instructor, top modal, and monthly trend to create primary dataset for reactable
data<-summary|>
  filter(!is.na(instructor))|>
  left_join(months, by="instructor")|>
  left_join(top_modal|>select(instructor, discipline), by="instructor")|>
  select(rank, instructor, image_path, discipline, workouts, difficulty, workout_data, minutes)

#SUBTABLE DATA, group data by fitness discipline ----

#create summary by instructor AND modal
by_modal<-df|>
  filter(!is.na(instructor) & start_year==2022 & !fitness_discipline %in% c("meditation","stretching"))|>
  group_by(instructor, discipline=str_to_title(str_replace_all(fitness_discipline,"_"," ")))|>
  summarise(workouts=n(),
            difficulty = round(weighted.mean(avg_difficulty,w=ride_duration),2),
            minutes = sum(ride_duration)/60)|>
  arrange(instructor, -minutes)

#create dataset for trend by modal & instructor
modal_months<-df|>
  filter(!is.na(instructor) & start_year==2022 & !fitness_discipline %in% c("meditation","stretching"))|>
  group_by(instructor,discipline=str_to_title(str_replace_all(fitness_discipline,"_"," ")), month)|>
  summarise(workouts=n())|>
  complete(month=c("2022-01","2022-02","2022-03","2022-04","2022-05","2022-06","2022-07"))|>
  mutate(workouts=replace_na(workouts,0))|>
  group_by(instructor,discipline)|>
  summarise(workout_data = list(workouts), .groups = "drop")

#combine datasets together to produce sub-data used for nested reactable
subdata<-by_modal|>
  filter(!is.na(instructor))|>
  left_join(modal_months, by=c("instructor"="instructor","discipline"="discipline"))|>
  mutate(rank="",image_path="")|>
  select(rank, instructor, image_path, discipline, workouts, difficulty, workout_data, minutes)

#color palette for difficulty scale
pal_strive<-c('#50C4AA', '#B6C95C', '#FACB3E', '#FC800F', '#FF4759')

#Create Reactable
table<-reactable(
  data,
  theme = reactableTheme(
    style=list(fontFamily="Roboto"),
    searchInputStyle = list(background="black"),
    pageButtonStyle = list(fontSize=14),
    backgroundColor="black",
    color="white",
    footerStyle = list(color="white", fontSize=11),
    borderColor="#3D3D3D",
    borderWidth=0.019
  ),
  defaultColDef = colDef(vAlign="center", align="center", headerVAlign="center"),
  columns = list(
    image_path = colDef(show=FALSE),
    instructor = colDef(name="NAME", align="left", vAlign="center", width=220, cell = function(value) {
      image <- img(src = paste0(base_image_url,str_replace_all(value," ","_"),".png"), style = "height: 33px;", alt = value)
      tagList(
        div(style = "display: inline-block;vertical-align:middle;width:50px", image),
        div(style = "display: inline-block;vertical-align:middle;", value)
      )
    }),
    discipline = colDef(name="TOP TYPE", maxWidth=130, align="left"),
    rank = colDef(name="", style=list(fontSize=13), maxWidth=50, align="right"),
    workouts= colDef(name="WORKOUTS", minWidth=120),
    minutes=colDef(name="TOTAL MINUTES", minWidth=160, 
                   cell=data_bars(data, 
                                  bar_height=8,
                                  text_size=11,
                                  text_color="white",
                                  text_position = "outside-end", 
                                  background = "transparent", 
                                  round_edges = TRUE, 
                                  fill_color=c("#FFBC51",'#FF3A3A'), 
                                  fill_gradient = TRUE)),
    difficulty = colDef(name="AVG DIFF", align="center", maxWidth=120, 
                        footer="Weighted avg by minutes",
                        cell=color_tiles(data, bias= 0.4, colors=pal_strive)),
    workout_data = colDef(name="TREND",  maxWidth=100,
                          footer="Monthly workouts",
                          cell=react_sparkline(data, labels=c("first","last"), 
                                               tooltip_size = "1.1em",
                                               tooltip_type=1,
                                               line_color = "white")
    )),
  #Sub-Table - nested reactable, when user clicks on instructor, details show aggregates by modal per instructor
    details = function(index){
      new = subdata[subdata$instructor == data$instructor[index],]
      reactable(data=new,
                defaultColDef = colDef(vAlign="center", align="center", headerVAlign="center"),
                theme = reactableTheme(
                  style=list(fontFamily="Roboto"),
                  searchInputStyle = list(background="black"),
                  pageButtonStyle = list(fontSize=14),
                  backgroundColor="black",
                  color="white",
                  footerStyle = list(color="white", fontSize=11),
                  borderColor="black",
                  borderWidth=0.019
                ),
                columns = list(
                  instructor=colDef(show=FALSE),
                  image_path = colDef(name="", width=265),
                  discipline = colDef(name="", maxWidth=130, align="left", footer="Breakout by Type", footerStyle=list(color='black')),
                  rank = colDef(name="", style=list(fontSize=13), maxWidth=50, align="right"),
                  workouts= colDef(name="", minWidth=120),
                  minutes=colDef(name="", minWidth=160, 
                                 cell=data_bars(new, 
                                                bar_height=8,
                                                text_size=11,
                                                text_color="white",
                                                text_position = "outside-end", 
                                                background = "transparent", 
                                                round_edges = TRUE, 
                                                fill_color=c("#FFBC51",'#FF3A3A'), 
                                                fill_gradient = TRUE)),
                  difficulty = colDef(name="", align="center", maxWidth=120, 
                                      cell=color_tiles(new, bias= 0.4, colors=pal_strive)),
                  workout_data = colDef(name="",  maxWidth=100,
                                        cell=react_sparkline(new, labels=c("first","last"), 
                        line_color = "white")
                ))
                )
    }
)%>%
  google_font(font_family="Roboto", font_weight = 300)



#use html widgest to prepend an dappend header and footer
html_object<-table|>
prependContent(
  tagList(
    div(style = "vertical-align:middle;text-align:center;background-color:black;color:white;padding-top:25px;padding-bottom:4px;font-size:24px;",
        "INSTRUCTOR LEADERBOARD 2022"),
    div(style = "vertical-align:middle;text-align:center;background-color:black;color:#BBBBBB;padding-top:5px;padding-bottom:20px;font-size:14px;",
        "Personal Peloton Summary for @redsourpatchkid")
  )
)|>
  appendContent(
    p("Data from pelotonR | Table @tanya_shapiro",
       style = paste0(
         "font-family:","Roboto; sans;",
         "font-size: 12px;" ,
         "text-align:right"))
  )


saveWidget(html_object, "peloton-2022.html", selfcontained = TRUE)
