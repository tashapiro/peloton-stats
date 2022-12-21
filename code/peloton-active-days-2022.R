library(tidyverse)
library(ggtext)
library(glue)


#create calendar of dates
dates = seq(as.Date('2022-01-01'),as.Date('2022-12-31'), by = '1 day')

df_cal <-data.frame(
  date = dates,
  month_num = format(dates, "%m"),
  month_abb = format(dates,'%b'),
  day_num = as.integer(format(dates,"%d"))
)

#get peloton data
df_peloton = read.csv("https://raw.githubusercontent.com/tashapiro/peloton-stats/main/data/peloton_data.csv")

active_days = df_peloton|>
  mutate(start_time = as.POSIXct(start_time)-(60*60*5),
         date = as.Date(start_time))|>
  filter(format(date,'%Y')==2022)|>
  distinct(date)|>
  arrange(date)|>
  mutate(month_abb = format(date, "%b"))|>
  group_by(month_abb)|>
  mutate(counter = row_number(),
         status = "Active")

df_plot = df_cal|>
  left_join(active_days|>select(-date), by=c("month_abb"="month_abb","day_num"="counter"))|>
  mutate(status = replace_na(status,"Not Active"))

df_plot$month_abb<-factor(df_plot$month_abb, levels=month.abb[1:12])

#number of total active days
day_count = length(active_days$date)

#pal aesthetics for plot
pal = "#DF1C2F"
pal_pen = "black"


#store font awesome in variable to use with glue, family with spaces requires quotes
fb = '"Font Awesome 6 Brands"'

#text variables to use with ggtext
title = glue("<span style='font-size:30pt;'>**<span style='color:{pal};'>{day_count}</span> Active Days**</span>")
subtitle = "<span style='color:#595F62;font-size:11pt;'>Personal summary of active days using <span>**Peloton**</span> in 2022. Active days represent days with at least one class taken. Data for redsourpatchkid as of Dec 20, 2022.</span>"
caption = paste0("<span style='font-family:Roboto;'>Source: {pelotonR}</span><br>",
                 glue("<span style='font-family:{fb};'>&#xf4f6;</span>"),
                 "<span style='font-family:Roboto;color:white;'>.</span>",
                 "<span style='font-family:Roboto;'>fosstodon.org/@tanya_shapiro</span>",
                 "<span style='font-family:Roboto;color:white;'>....</span>",
                glue("<span style='font-family:{fb};'>&#xf099;</span>"),
                 "<span style='font-family:Roboto;color:white;'>.</span>",
                 "<span style='font-family:Roboto;'>@tanya_shapiro</span>",
                 "<span style='font-family:Roboto;color:white;'>....</span>",
               glue("<span style='font-family:{fb};'>&#xf09b;</span>"),
                 "<span style='font-family:Roboto;color:white;'>.</span>",
                 "<span style='font-family:Roboto;'>tashapiro</span>"
)

ggplot()+
  geom_text(data=df_plot|>distinct(month_abb),
            mapping=aes(x=-1.5, y=reorder(month_abb,desc(month_abb)), label=month_abb),
            hjust=0)+
  geom_point(data=df_plot|>filter(status=="Not Active"),
             mapping=aes(y=month_abb, x=day_num),
             stroke=0.8,
             color="#7A878C", size=4, shape=21)+
  geom_point(data=df_plot|>filter(status=="Active"),
             mapping=aes(y=month_abb, x=day_num),
             stroke = 0.8,
             color="#DF1C2F",
             size=4)+
  annotate(geom="text", y=12.45, x=31.5, color=pal_pen, hjust=1, label='"New Year, new me" energy', family="Caveat")+
  annotate(geom="text", y=10.45, x=31.5, color=pal_pen, hjust=1, label='Wedding season, bad hotel gyms...', family="Caveat")+
  annotate(geom="text", y=7.45, x=30.5, color=pal_pen, hjust=1, label='Recovering from COVID', family="Caveat")+
  annotate(geom="text", y=2.45, x=30.5, color=pal_pen, hjust=1, label='Sick again (flu) + Thanksgiving travel', family="Caveat")+
  scale_x_continuous(expand=c(0,0), limits=c(-1.5,32))+
  labs(title=title,
       subtitle = subtitle,
       caption =caption)+
  theme(text=element_text(family="Roboto"), 
        plot.title = element_textbox_simple(),
        plot.subtitle = element_textbox_simple(margin=margin(t=6, b=5)),
        plot.caption = element_textbox_simple(color="#595F62"),
        axis.title=element_blank(),
        axis.ticks = element_blank(),
        axis.text=element_blank(),
        panel.background = element_blank(),
        plot.margin = margin(l=20, r=20, t=15,b=10),
        legend.position = "top")

ggsave("peloton-active-days.png", bg="white", height=6, width=6)
