library(reactablefmtr)
library(tidyverse)
library(showtext)
library(sysfonts)
library(htmlwidgets)
library(htmltools)
library(lubridate)
library(reactable)
#devtools::install_github("glin/reactable") use this version for reactable, new edition not on CRAN yet

#import data, cast time as date
df<-read.csv("peloton_data.csv")
df$start_time<-as.Date(df$start_time)

#import fonts for table
font_add_google("Roboto", "Roboto")
showtext_auto()

#dataset with top fitness discipline by instructor
top_modal<-df%>%
  filter(start_year==2022 & !fitness_discipline %in% c("stretching","meditation"))%>%
  group_by(instructor, fitness_discipline)%>%
  summarise(workouts=n(), time = sum(ride_duration)/60)%>%
  arrange(instructor, -workouts, -time)%>%
  slice_max(workouts, n=1, with_ties=FALSE)%>%
  rename(top_workouts=workouts)%>%
  select(-time)

#get number of workouts per month by instructor
monthly_workouts<-df %>%
  filter(start_year==2022 & !fitness_discipline %in% c("stretching","meditation"))%>%
  mutate(month_num = format(start_time,"%m")) %>%
  group_by(instructor,month_num)%>%
  summarise(workouts=n())%>%
  complete(month_num=c('01','02','03','04'))%>%
  mutate(workouts = ifelse(is.na(workouts), 0, workouts))%>%
  group_by(instructor)%>%
  summarise(workout_data = list(workouts), .groups = "drop")

#create instructor summary df
instructors<-df%>%
  filter(start_year==2022 & !fitness_discipline %in% c("stretching","meditation"))%>%
  group_by(instructor)%>%
  summarise(workouts=n(),
            workout_time=sum(ride_duration)/60,
            avg_workout_time = round((sum(ride_duration)/60)/n(),0),
            avg_difficulty = round(mean(avg_difficulty),2)
  )%>%
  left_join(top_modal, by="instructor")%>%
  left_join(monthly_workouts, by="instructor")%>%
  mutate(image=paste0("https://github.com/tashapiro/peloton-stats/blob/main/images/instructors/",
                      gsub(' ','%20',instructor),".jpg?raw=true",sep=""),
         fitness_discipline= str_to_title(str_replace_all(fitness_discipline,"_"," ")),
         perc_max_workouts = top_workouts/workouts
         )%>%
  arrange(-workouts)

instructors$perc_time<-instructors$workout_time/sum(instructors$workout_time)


orpal<-c('#ffffcc','#ffeda0','#fed976','#feb24c','#fd8d3c','#fc4e2a','#e31a1c','#b10026')

pal<-c('#ffeda0', '#feb24c', '#fc4e2a','#b10026')

#rearrange data
instructors<-instructors%>%select(image, instructor, fitness_discipline, avg_difficulty, workout_time, avg_workout_time,
                                  workouts, workout_data, perc_max_workouts)

#create dummy dataset to increase difficulty meter to 9 pts (setting max for our icons)
dummy<-data.frame(
  image="https://github.com/tashapiro/peloton-stats/blob/main/images/instructors/Jess%20Sims.jpg?raw=true",
  instructor="fake",
  fitness_discipline = "Cycling",
  avg_difficulty=9,
  workout_time=0,
  avg_workout_time=0,
  workouts=0,
  workout_data=0,
  perc_max_workouts=0.1)

#append dummy back to instructor df
instructors<-rbind(instructors,dummy)

#create table
table<-reactable(instructors%>%filter(instructor!="fake"), #exclude dummy data in filter
          theme = reactableTheme(
            style = list(fontFamily="Roboto")
          ),
          defaultSorted = "workout_time",
          defaultSortOrder = "desc",
          columnGroups = list(
            colGroup(name = "WORKOUTS", columns = c("workouts", "workout_data")),
            colGroup(name = "CLASS TIME", columns = c("avg_workout_time", "workout_time"))
            ),
          columns=list(
            perc_max_workouts=colDef(show=FALSE),
            image = colDef(name="",cell = embed_img(height=50,width=50)),
            fitness_discipline=colDef(name="TOP CLASS TYPE", vAlign="center",
                                      footer = "Bar represents % of total workouts.",
                                      cell = data_bars(instructors, 
                                                       fill_by="perc_max_workouts",
                                                       fill_color='#30A9D5',
                                                       tooltip=FALSE,
                                                       round_edges = TRUE, 
                                                       text_position = "above")),
            instructor = colDef(name="INSTRUCTOR", vAlign="center"),
            avg_workout_time = colDef(name="AVERAGE", align="center", vAlign="center",
                                      cell = icon_sets(instructors, 
                                                       icon_size = 20,
                                                       number_fmt = scales::label_number(suffix=" min"),
                                                       icon_position = "right",
                                                       icons = "stopwatch", colors=RColorBrewer::brewer.pal(4, 'Oranges'))),
            workout_time = colDef(name="TOTAL", 
                                  align="center", vAlign="center",
                                  cell = icon_sets(instructors, 
                                                   icon_size = 20,
                                                   number_fmt = scales::label_number(suffix=" min"),
                                                   icon_position = "right",
                                                   icons = "stopwatch", colors=RColorBrewer::brewer.pal(4, 'Oranges'))),
            avg_difficulty = colDef(name="AVG DIFFICULTY", vAlign="center",
                                    cell = icon_assign(instructors, 
                                                       icon="fire",
                                                       align_icons = "center",
                                                       fill_color ='#fc4e2a',seq_by=0.9, show_values="above"),
                                    align="center"),
            workouts=colDef(name="TOTAL", vAlign="center",
                            cell=color_tiles(instructors,
                                             colors = RColorBrewer::brewer.pal(5, 'Oranges')),
                            align="center"),
            workout_data = colDef(
              name="MONTHLY",
              align="center", vAlign="center",
              cell = react_sparkline(
                instructors,
                highlight_points = highlight_points(first = "grey", last = "grey"),
                labels = c("first", "last")
            )
            )
            )
)





#add title and subtitle with htmlwidgets & htmltools
table_html<-htmlwidgets::prependContent(
  table,
  tags$h1("PELOTON INSTRUCTOR LEADERBOARD 2022", class="title",
          style=paste0(
            "font-family:","Roboto; sans; !important;", 
            "font-size: 24px;" ,
            "margin-left: 20px;"
          )),
  tags$p("Personal Workout Summary for redsourpatchkid. Excludes stretching & meditation.",
         class="subtitle",
          style=paste0(
            "font-family: Roboto; sans; !important;",
            "font-size: 16px;",
            "margin-left: 20px;",
            "margin-top: -10px;",
            "margin-bottom: -1px;"
          )
))

table_html

#add caption with htmlwidgets& htmltools
table_html2<-htmlwidgets::appendContent(
  table_html,
  htmltools::tags$p("Data from Peloton API | Table @tanya_shapiro",
                    style = paste0(
                      "font-family:","Roboto; sans;",
                      "font-size: 14px;" ,
                      "text-align:right")))



table_html2

saveWidget(table_html2, "peloton_leaderboard.html", selfcontained = TRUE)

