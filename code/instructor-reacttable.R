library(tidyverse)
library(lubridate)
library(gt)
library(gtExtras)
library(htmltools)
library(pelotonR)
#devtools::install_github("lgellis/pelotonR")
library(reactablefmtr)
#remotes::install_github("kcuilla/reactablefmtr")

#different class types
class_types <- get_metadata_mapping_df('class_types')

#set up credentials to get personal data, enter username and password as string, replace with your own username & password
auth_response <-authenticate("password",'username')

#get list of workouts
workouts <-get_workouts_df() 
#get list of instructors
instructors<-get_instructors_df()

#append list of instructors by id to workiuts
my_workouts<-left_join(workouts,instructors, by=c("peloton.ride.instructor_id"="id"))
#convert epoch time to standard time
my_workouts$start_time<-as.POSIXct(my_workouts$created_at, origin="1970-01-01")
my_workouts$start_year<-format(my_workouts$start_time, '%Y')
my_workouts$end_time<-as.POSIXct(my_workouts$end_time, origin="1970-01-01")

my_workouts$instructor<-my_workouts$name.y
my_workouts$image<-paste0("https://github.com/tashapiro/peloton-stats/blob/main/images/instructors/",
                          gsub(' ','%20',my_workouts$instructor),".jpg?raw=true",sep="")

my_workouts$duration<-(my_workouts$end_time - my_workouts$start_time)/60
my_workouts<-my_workouts%>%drop_na(duration)
my_workouts$start_year<-format(my_workouts$start_time, '%Y')

#calculate duration of workouts, remove any NA times
my_workouts$duration<-(my_workouts$end_time - my_workouts$start_time)/60
my_workouts<-my_workouts%>%drop_na(duration)
my_workouts$start_year<-format(my_workouts$start_time, '%Y')

my_workouts %>%
  filter(start_year==2021)%>%
  mutate(month2 = format(start_time,"%Y-%m")) %>%
  group_by(month2)%>%summarise(workouts=n())

by_month<-my_workouts %>%
  filter(start_year==2021)%>%
  mutate(month_num = format(start_time,"%m"), month_name=format(start_time,'%b')) %>%
  group_by(month_num,month_name)%>%summarise(workouts=n(), minutes=sum(duration))

month_nums<-unique(by_month$month_num)

#get trend of workouts per month
monthly_workouts<-my_workouts %>%
  filter(start_year==2021)%>%
  mutate(month_num = format(start_time,"%m")) %>%
  group_by(instructor,month_num)%>%
  summarise(workouts=n(), minutes=sum(duration))%>%
  complete(month_num=month_nums)%>%
  mutate(workouts = ifelse(is.na(workouts), 0, workouts))%>%
  group_by(instructor)%>%
  summarise(workout_data = list(workouts), .groups = "drop")

#get top class type/discipline by instructor
top_discipline<-my_workouts%>%
  filter(start_year==2021)%>%
  group_by(instructor,fitness_discipline)%>%
  summarise(workout_time=as.numeric(round(sum(duration)/60,1)))%>%
  slice(which.max(workout_time))%>%
  rename("top_discipline"="fitness_discipline","top_time"="workout_time")


#creating the data 
data1<-my_workouts%>%
  group_by(instructor)%>%
  summarise(workouts=n(),
            avg_difficulty = round(mean(peloton.ride.difficulty_rating_avg),2)
  )%>%
  left_join(top_discipline, by=c("instructor"="instructor"))%>%
  left_join(monthly_workouts, by=c("instructor"="instructor"))%>%
  mutate(image=paste0("https://github.com/tashapiro/peloton-stats/blob/main/images/instructors/",
                      gsub(' ','%20',instructor),".jpg?raw=true",sep=""),
         top_discipline=str_to_title(gsub('_',' ',top_discipline)))%>%
  arrange(-workouts)


orpal<-c('#ffffcc','#ffeda0','#fed976','#feb24c','#fd8d3c','#fc4e2a','#e31a1c','#b10026')

table<-reactable(data1%>%select(image,instructor,top_discipline,workouts,avg_difficulty,workout_data),
          searchable=TRUE,
          theme = reactableTheme(
            # Vertically center cells
            cellStyle = list(display = "flex", flexDirection = "column", justifyContent = "center"),
            style = list(fontFamily="Brandon Grotesque, Gill Sans")
          ),
          columns = list(
            top_discipline = colDef( name="TOP CLASS TYPE"),
            image = colDef(name="",
                           cell = embed_img(height=50,width=50)),
            avg_difficulty = colDef(name="AVG DIFFICULTY",cell=color_tiles(data1,  colors = orpal), align="center"),
            instructor = colDef(name="INSTRUCTOR"),
            workouts = colDef(name="TOTAL CLASSES",
                              align="center",
                              cell = data_bars(data1,
                                               fill_color = '#3FA7D6', 
                                               text_position = "outside-end", 
                                               background = "transparent", 
                                               round_edges = TRUE)),
            workout_data = colDef(
              name="MONTHLY CLASSES",
              align="center",
              cell = react_sparkline(
                data1,
                height = 30,
                area_color = "#3FA7D6",
                statline = "mean",
                statline_color="grey",
                statline_label_color = "grey",
                highlight_points = highlight_points(max = "#3FA7D6"),
                show_area = TRUE)
              ))
          )

table_html<-htmlwidgets::prependContent(
  table,
  htmltools::tags$h1("MY PELOTON SQUAD 2021",
                     style=paste0(
                       "font-family:","Brandon Grotesque, Gill Sans;", 
                       "font-size: 28px;" ,
                       "margin-left: 20px;"
                     )),
  htmltools::tags$h2("Personal Workout Summary by Instructor",
                     style = paste0(
                       "font-family:", "Brandon Grotesque, Gill Sans;" ,
                       "font-size: 20px;" ,
                       "font-weight: normal;" ,
                       "margin-left: 20px;",
                       "margin-top: -20px;"
                     ))
)

table_html<-htmlwidgets::appendContent(
  table_html,
  htmltools::tags$p("Data from Peloton API",
                    style = paste0(
                      "font-family:", "Brandon Grotesque, Gill Sans;")))


save_reactable(table_html, "peloton_summary.html")
