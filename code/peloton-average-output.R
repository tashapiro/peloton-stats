library(tidyverse)
library(ggimage)
library(utils)
library(sysfonts)
library(showtext)

#this graphic is inspired by Cédric Scherer - Evolution of a ggplot
#https://www.cedricscherer.com/2019/05/17/the-evolution-of-a-ggplot-ep.-1/

#set fonts
font_add_google("roboto", "roboto")
font_add_google("archivo black", "archivo black")
showtext_auto()

#import data
df<-read.csv("https://raw.githubusercontent.com/tashapiro/peloton-stats/main/data/peloton_data.csv")

#use this url to get images for instructors, images hosted on my github repo
base_image_url<-'https://raw.githubusercontent.com/tashapiro/peloton-stats/main/images/instructors-cropped/'

#reshape data
data<-df|>
  filter(fitness_discipline=="cycling" & !is.na(avg_output) & !is.na(instructor) & avg_output>60)|>
  group_by(instructor)|>
  mutate(total_rides = n(),
            avg_instructor = mean(avg_output))|>
  arrange(-total_rides)|>
  ungroup()|>
  select(instructor, ride_title = title.y, avg_output, avg_instructor, total_rides)|>
  separate(ride_title, into=c("minutes","ride_type"), sep=" min ")|>
  mutate(ride_type = str_replace(ride_type," Ride",""),
         group_type = case_when(!ride_type %in% c("Intervals & Arms", "HIIT", "HIIT & Hills", "Low Impact") ~ "Music", 
                                ride_type %in% c("HIIT", "HIIT & Hills") ~ "HIIT", TRUE ~ ride_type),
         instructor_image = paste0(base_image_url, str_replace_all(instructor," ","_"),".png"))|>
  filter(total_rides>10)

#create dataset for average of averages per instructor
avg_instructor<-data|>
  distinct(instructor, avg_output = avg_instructor)|>
  mutate(image = URLencode(paste0(base_image_url,str_replace(avg_instructor$instructor," ","_"),".png")))

#create factor to reorder instructors
data$instructor<-factor(data$instructor,levels=c("Tunde Oyeneyin","Robin Arzón","Emma Lovewell","Kendall Toole","Olivia Amato","Jess King"))

#create position for output labels per instructor
avg_instructor<-avg_instructor|>arrange(avg_output)
avg_instructor$pos <-1:nrow(avg_instructor)

#get max output for label
max<-data|>arrange(-avg_output)|>head(1)



data$group_type<-factor(data$group_type, levels=c("Low Impact","Intervals & Arms","HIIT","Music"))

ggplot()+
  geom_jitter(data=data, mapping=aes(x=avg_output, y=instructor, color=instructor, shape=group_type),
              size=4, alpha = 0.45, width = 0.04)+
  guides(color="none", 
         shape=guide_legend("", override.aes = list(color="black", alpha=1)))+
  #adjust scales
  scale_color_manual(values=c('#7916B6','#FCB42D','#FC2D2D','#47CE29','#48B8D0','#1CCEBF'))+
  scale_shape_manual(values=c(15, 17, 8, 19))+
  scale_x_continuous(limits=c(120,185))+
  #overall average line
  geom_vline(xintercept=mean(data$avg_output))+
  #lines connecting averages per instructor to overall average vline
  geom_segment(data=avg_instructor, mapping=aes(x=avg_output, xend=mean(data$avg_output), y=instructor, yend=instructor))+
  #add background image border using image, set color to black
  geom_image(data=avg_instructor, mapping=aes(y=instructor, x=avg_output, image=image),  color="black", size=0.053, asp=1.5)+
  #plot image per instructor
  geom_image(data=avg_instructor, mapping=aes(y=instructor, x=avg_output, image=image), size=0.05, asp=1.5)+
  #plot average outputs per instructor as label underneath
  geom_label(data=avg_instructor, mapping=aes(y=pos-.35, x=avg_output, label=round(avg_output,2)), size=3, fill="black", color="white")+
  #Overalll Average Notation
  annotate(geom="text", x=147, y=5.6, label=round(mean(data$avg_output),2), fontface="bold")+
  annotate(geom="text", x=147, y=5.45, label="Overall Average", size=3)+
  geom_segment(inherit.aes=FALSE, aes(x=150, xend=154.6, y=5.525, yend=5.525), color="black", arrow=arrow(length = unit(0.07, "inch")))+
  #Average Per Instructor Notation
  annotate(geom="text", x=141.5, y=3.18, label="Instructor \n Average", size=3, fontface="bold")+
  geom_curve(aes(x=143.5, xend =152, y=3.38, yend=4-.35), size=0.4, curvature=-0.15,  arrow=arrow(length = unit(0.07, "inch")))+
  geom_curve(aes(x=143.5, xend =151.5, y=2.98, yend=3-.35), size=0.4, curvature=0.15,  arrow=arrow(length = unit(0.07, "inch")))+
  annotate(geom="text", x=128, y=1.4, label="Intervals & Arms rides tend to have \n lower output due to breaks \n for arm weight sections", size=2.5)+
  #Max Label
  geom_text(data=max, mapping=aes(x=avg_output, y=instructor, label=paste0("Best Output:\n",avg_output)), size=2.5)+
  #titles
  labs(title="PEDAL TO THE METAL", 
       subtitle="Analysis of personal cycling class outputs. Each point represents average output per Peloton ride and instructor. \n Point shape indicates class type. Instructor aggregates represent average of averages.",
       caption="Source: pelotonR | LB: @redsourpatchkid | Graphic @tanya_shapiro",
       y="", x="Average Output")+
  theme_minimal()+
  theme(plot.title=element_text(face="bold", hjust=0.5, size=24, family="archivo black"),
        plot.subtitle=element_text(hjust=0.5, color="grey30", size=11),
        axis.title.x=element_text(face="bold"),
        panel.grid.minor = element_blank(),
        axis.text.y=element_text(face="bold", color="black", hjust=0, size=10),
        plot.margin = margin(t=20,b=20, l=20, r=20),
        legend.position = "top",
        plot.caption=element_text(color="grey30", vjust=-5),
        legend.title=element_text(face="bold", size=10))

#save image
ggsave("../peloton_output2.jpeg", height=9, width=12)