library(tidyverse)
library(gganimate)
library(ggimage)
library(sysfonts)
library(showtext)

#import data
df<-read.csv("peloton_data.csv")

#add font chivo
font_add_google("chivo", "Chivo")
showtext_auto()

#add a month_year field
df<-df%>%mutate(start_time = as.Date(start_time),month_year = format(start_time, '%Y-%m'))

#list of unique instructors and month_years
months<-unique(df$month_year)
instructors<-unique(df$instructor)

#aggregate by instructor & month, use complete to make sure data is uniform
grouped_df<-df%>%
  group_by(month_year,instructor)%>%
  summarise(workouts=n(),
            time = sum(ride_duration)/60)%>%
  complete(instructor = instructors)%>%
  mutate(workouts = ifelse(is.na(workouts), 0, workouts),
         time = ifelse(is.na(time), 0, time)
         )%>%
  arrange(month_year, instructor)%>%
  filter(!is.na(instructor))

#followed blog by Abdul Raja for guidance - - https://www.r-bloggers.com/2020/01/how-to-create-bar-race-animation-charts-in-r/
#add cumulative time for instructor over month, create ranking
grouped_rank<-grouped_df%>%
  group_by(instructor)%>%
  filter(instructor!='Robin Arzón')%>%
  mutate(cum_time = cumsum(time),
         image=paste0("https://github.com/tashapiro/peloton-stats/blob/main/images/instructors/",
                             gsub(' ','%20',instructor),".jpg?raw=true",sep=""))%>%
  group_by(month_year)%>%
  mutate(rank=rank(-cum_time),
         value_rel = cum_time/cum_time[rank==1])%>%
  group_by(instructor)%>%
  filter(rank<=8)%>%
  ungroup()


# plot with text ----
#divided cumulative time by 60 to show hours instead of minutes!
plot<-ggplot(grouped_rank, aes(rank, group=instructor))+
  geom_hline(yintercept=20, color="#DDE5E9")+
  geom_hline(yintercept=40, color="#DDE5E9")+
  geom_hline(yintercept=60, color="#DDE5E9")+
  geom_tile(aes(y=cum_time/60/2, height=cum_time/60, width=0.5), fill='#009EE7')+
  #  geom_text(aes(y=0, label=instructor), vjust=0.2, hjust=1.2, family="chivo", fontface="bold", size=3.5)+
  geom_text(aes(y=cum_time/60, label=round(cum_time/60,0)), hjust=-0.2, size=3.5, family="Chivo")+
  geom_hline(yintercept=0, color="#DDE5E9")+
  geom_image(aes(y=-200/60, x=rank, image=image), asp=1.5)+
  coord_flip(clip = "off", expand = FALSE)+
  scale_x_reverse(limits = c(8.5,0.5))+
  scale_y_continuous(limits=c(-500/60,max(grouped_rank$cum_time)/60+5), labels= scales::comma)+
  #dynamic title use {closest_state} to show the state (month_year) per frame
  labs(title = 'MY PELOTON INSTRUCTOR LEADERBOARD AS OF {closest_state}', 
       subtitle = "Personal cumulative workout time per Peloton instructor. Sept 2020 - Apr 2022.",
       y = "Cumulative Workout Time (Hours)",
       caption = "Data from Peloton API | @tanya_shapiro" )+
  theme_void()+
  theme(plot.margin=margin(l=20,r=20,20,20),
        text= element_text(family="Chivo"),
        plot.title=element_text(face="bold", family="Chivo", margin=margin(b=10)),
        plot.caption=element_text(size=10, margin=margin(t=5)),
        plot.subtitle=element_text(margin=margin(b=5)),
        axis.text.x=element_text(family="Chivo"),
        axis.title.x = element_text(family="Chivo", margin=margin(t=15)))


#add transition states to plot, state length 0 makes it continuous (no pause between states)
animated <- plot+
  transition_states(month_year, transition_length = 3, state_length = 0)


#render GIF graphic
animate(animated, 200, fps = 15,  width = 800, height = 600, 
        renderer = gifski_renderer("peloton-bar-race.gif"))

