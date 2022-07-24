library(tidyverse)
library(ggbump)
library(ggimage)
library(ggtext)

#import data
df<-read.csv("https://raw.githubusercontent.com/tashapiro/peloton-stats/main/data/peloton_data.csv")

#create month-year
months<- unique(format(as.Date(df$start_time),'%Y-%m'))


grouped<-df|>
  filter(!fitness_discipline %in% c("meditation","stretching") & !is.na(ride_duration) & start_year!=2020)|>
  mutate(fitness_discipline = str_to_title(str_replace_all(fitness_discipline,"_"," ")),
         ride_distance = replace_na(ride_distance,0),
         counter = 1)|>
  mutate(month_year = format(as.Date(start_time),'%Y-%m'))|>
  group_by(fitness_discipline)|>
  complete(month_year = months)|>
  group_by(fitness_discipline,month_year)|>
  summarise(time_min = sum(ride_duration)/60,
            classes = sum(counter))|>
  mutate(time_min = replace_na(time_min,0),
         classes = replace_na(classes,0))|>
  group_by(fitness_discipline)|>
  mutate(cum_time = cumsum(time_min),
         cum_classes = cumsum(classes))|>
  group_by(month_year)|>
  arrange(month_year, -cum_time, -cum_classes)|>
  mutate(rank = rank(-cum_time, ties.method = "first"))

#get quarters only
data<-grouped|>
  mutate(month=as.integer(substr(month_year,6,9)))|>
  filter(month %in% c(1,3,6,9) & month_year!="2020-09")

#create dataset to calculate delta from start to end
delta<-data|>
  filter(month_year %in% c("2021-01","2022-06"))|>
  group_by(fitness_discipline)|>
  summarise(pos_y= last(rank),
            delta = last(cum_time)-first(cum_time),
            delta_rank = first(rank)- last(rank),
            delta_abs = abs(delta_rank),
            delta_hrs = delta/60)|>
  mutate(pos_x="2022-09",
         icon = case_when(delta_rank>0~paste0("+",delta_abs),delta_rank<0~paste0("-",delta_abs),TRUE~"0"))

#create caption for ggtext element_markdown
logo<-'https://raw.githubusercontent.com/tashapiro/peloton-stats/main/images/peloton-logo-white.png'
caption<-paste0('Source: ','<img src="',logo,'" width=7>',' Peloton Data @redsourpatchkid | Graph @tanya_shapiro')


#plot
ggplot(data, aes(month_year, rank, group = fitness_discipline)) +
  geom_bump(aes(smooth = 10, color = fitness_discipline, fill = fitness_discipline), size = 2, lineend = "round")+
  geom_point(data=data|>filter(month_year=="2021-01"), aes(color=fitness_discipline), size=13)+
  geom_text(data=data|>filter(month_year=="2021-01"), aes(label=round(cum_time/60,1)), size=3.5)+
  geom_point(data=data|>filter(month_year=="2022-06"), aes(color=fitness_discipline), size=13)+
  geom_text(data=data|>filter(month_year=='2021-01'), aes(label=fitness_discipline, y=rank+.425), color="white", size=3.5)+
  geom_text(data=data|>filter(month_year=='2022-06'), aes(label=fitness_discipline, y=rank+.425), color="white", size=3.5)+
  geom_point(data=data|>filter(month_year=="2022-06"), aes(color=fitness_discipline), size=5)+
  geom_text(data=data|>filter(month_year=="2022-06"), aes(label=round(cum_time/60,1)), size=3.5)+
  annotate(geom="text", color="white", label="Total Hours", x="2021-03", y=1.5, size=3)+
  geom_segment(inherit.aes=FALSE, color="white", mapping=aes(x=1.7, xend=1.1, y=1.45, yend=1.08), size=.2, arrow=arrow(length=unit(0.07,"inches")))+
  geom_segment(inherit.aes=FALSE, color="white", mapping=aes(x=1.7, xend=1.1, y=1.55, yend=1.92), size=.2, arrow=arrow(length=unit(0.07,"inches")))+
  annotate(geom="text", color="white", label="START", x="2021-01", y=0.5, size=4.5, fontface="bold")+
  annotate(geom="text", color="white", label="END", x="2022-06", y=0.5, size=4.5, fontface="bold")+
  annotate(geom="text", color="white", label="RANK Δ", x="2022-09", y=0.5, size=4.5, fontface="bold")+
  geom_text(delta, color="white", mapping=aes(pos_x,y=pos_y, label=icon), size=4)+
  scale_y_reverse(limits=c(7.5,0.5), breaks=c(0.5,1,2,3,4,5,6,7), labels=c("RANK",1,2,3,4,5,6,7))+
  scale_x_discrete(labels=c("2021-01","2021-03","2021-06","2021-09","2022-01","2022-03","2022-06",""))+
  scale_color_manual(values=c("#9D2CFF","#ff4671","#06d6a0","#ffcd16","white","#FF8F39","#27b0ff"))+
  annotate(geom="label", label="Bought \n Bike+", fill="#06d6a0" , label.size=NA,  color="black", x="2021-06", y=3, size=3)+
  labs(title="CHANGE IN WORKOUT HABITS",
       caption=caption,
       y="",x="", color="",
       subtitle="Rank position based on total cumulative hours accrued per workout type. \n Data from January 2021 through June 2022. Rankings adjusted per quarter.")+
  theme_minimal()+
  theme(legend.position="none",
        axis.text=element_text(color="white"),
        axis.text.y=element_text(size=13, face="bold", hjust=0.5),
        plot.title=element_markdown(hjust=0.5, face="bold", size=20),
        plot.subtitle=element_text(hjust=0.5, color="#DFDFDF"),
        text = element_text(color="white"),
        plot.caption=element_markdown(color="#DFDFDF"),
        plot.background = element_rect(color="#161616",fill="#161616"),
        plot.margin=margin(t=20,b=20,r=20,l=20),
        panel.grid = element_blank())

#save
ggsave("peloton-bump-chart.png", height=9, width=12)


