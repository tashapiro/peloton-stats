library(tidyverse)
library(lubridate)
library(gt)
library(gtExtras)
library(pelotonR)
#link to install pelotonR in the comment below
#devtools::install_github("lgellis/pelotonR")

#different class types
class_types <- get_metadata_mapping_df('class_types')

#set up credentials to get personal data, enter username and password as string, replace with your own username & password
auth_response <-authenticate("username",'password')

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

#calculate duration of workouts, remove any NA times
my_workouts$duration<-(my_workouts$end_time - my_workouts$start_time)/60
my_workouts<-my_workouts%>%drop_na(duration)
my_workouts$start_year<-format(my_workouts$start_time, '%Y')

df<-my_workouts%>%
  select(created_at,end_time, start_year, device_type, fitness_discipline,id,metrics_type,start_time,
         status, timezone, title, total_work,workout_type,peloton.ride.difficulty_rating_avg,
         peloton.ride.distance, peloton.ride.difficulty_level, peloton.ride.duration, peloton.ride.instructor_id,
         name.y)%>%
  rename(instructor=name.y, 
         difficulty_level = peloton.ride.difficulty_level,
         ride_duration = peloton.ride.duration, 
         instructor_id = peloton.ride.instructor_id,
         ride_distance = peloton.ride.distance,
         avg_difficulty = peloton.ride.difficulty_rating_avg
  )


write.csv(df,"../data/peloton_data.csv", row.names=FALSE)


