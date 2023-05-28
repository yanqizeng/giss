library(classInt)
library(dplyr)
library(geojsonio)
library(ggplot2)
library(janitor)
library(maptools)
library(pacman)
library(OpenStreetMap)
library(plotly)
library(RColorBrewer)
library(RSQLite)
library(rgeos)
library(rgdal)
library(sp)
library(sf)
library(shiny)
library(shinyjs)
library(tmap)
library(tmaptools)
library(tidyverse)
# 安装某些包 install.packages("xxx")



# 读取储存在R Project文件夹里的csv数据（方法1）
# wstData是赋予数据在R里的代称，可随意更换
wstData<- read_csv(here::here("prac2_Data",
                   "Report_Card_Assessment_Data_2018-19.csv"), 
                         na = "NULL")

# 或者下载文件后读取shp
wstshape <- st_read(here::here("prac2_data",
                         "Washington_Counties",
                         "Washington_Counties_with_Natural_Shoreline___washsh_area.shp"))



# 检查程序是否成功读取，①更换“wstData" 
# name_to= 是shp列表
# values_to= 是csv列表
# ② csv和shp相连接的列的名称更替到name value
# 注意连接列的内容的大小写，两个都对应才行
Datatypelist <- wstData %>% 
  summarise_all(class) %>%
  pivot_longer(everything(), 
               names_to="All_variables", 
               values_to="Variable_class")

Datatypelist


# 查看列标题，更换“wstData" 即可，想查看前几列head()里填几
wstData%>%
  colnames()%>%
  head(30)


# 选择wstData列表里，计算所需的列(清洗数据)
# 列的名称，由于clean_names() %>%，删除所有大写字母并在有空格的地方使用下划线
# 改变例如 TestSubject => test_subject
# 改变例如 Count of Students... => count_of_students...

county_only <- wstData %>%
  clean_names() %>%
  select(county, organization_level, test_subject, count_met_standard, 
         count_of_students_expected_to_test, grade_level)%>%

  # 进一步挑选计算所需的行
  # the != means don't select this, but select everything else
  # i could also filter on where 
  filter(county != "Multiple")%>%
  filter(organization_level == "School")%>%
  filter(test_subject == "Science")%>%
  filter(grade_level=="All Grades")%>%
  # 按county成组
  group_by(county)%>%
  
  # 我们需要移除NAs - 注意，我们可以使用这个函数，也可以在下面的摘要中使用实参 na.rm=T 是同样的
  na.omit()%>%
  # na.rm = T 表示从数据中删除缺失的值
  # 还可以使用 na.omit 或 filter greater than 0
  
  
  # 开始按题目计算
  # ①summarise汇总，符合标准的县总数，参加考试的县总数
  # ②mutate变化，每个县的符合标准的概率
  summarise(total_county_met_standard=sum(count_met_standard), 
            total_county_to_test=sum(count_of_students_expected_to_test))%>%
  mutate(percent_met_per_county=(total_county_met_standard/total_county_to_test)*100)


# 州的平均值：每个县的符合标准的概率，加起来总和的平均
# 即，在R里简写为mean(percent_met_per_county)
state_average <- county_only%>%
  summarise(state_average= mean(percent_met_per_county))%>%
  pull()


# 做一个列来比较每个县的值和州的平均值(是否低于/达到/高于)
# 还有一些文本(below,above,equal)来说明它是高于还是低于…
county_only_above_below_state <- county_only %>%
  mutate(difference_to_state=(percent_met_per_county-state_average))%>%
  mutate(across(difference_to_state , round, 0))%>%
  mutate(above_below = case_when(difference_to_state<0 ~ "below",
                                 difference_to_state>0 ~ "above",
                                 difference_to_state==0 ~ "equal"
  ))


# 把计算的结果加入到空间数据（地图shp)
joined_data <- wstshape %>% 
  clean_names() %>%
  left_join(., 
            county_only_above_below_state,
            by = c("countylabe" = "county"))



# 地图设置教程http://t.zoukankan.com/cqy-wt1124-p-15105460.html
# alpha透明度, compass指南针, scale比例，legend图例
# style数据划分不同颜色，palette配色方案

tm_shape(joined_data) + 
  tm_polygons("above_below", 
              # style="pretty",
              palette="Blues",
              midpoint=NA,
              #title="Number of years",
              alpha = 0.5) + 
  tm_compass(position = c("left", "bottom"),type = "arrow",text.size = 0.5) + 
  tm_scale_bar(position = c("left", "bottom"),text.size = 0.3) +
  tm_layout(title = "Counties above or below state avearge for science in all grades",
            title.position = c("left","top"),title.size =1,
            legend.position = c("right", "bottom"),
            legend.title.size = 0.6,legend.text.size = 0.3)




