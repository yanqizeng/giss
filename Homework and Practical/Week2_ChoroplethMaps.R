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



# 制作等值线图（choropleth maps）
# Choropleth maps是根据某些现象对区域进行着色的专题地图

# 可以直接从 internetz 读取空间数据
EW <- st_read("https://opendata.arcgis.com/datasets/8edafbe3276d4b56aec60991cbddda50_2.geojson")

# 或者下载文件后读取shp
#EW <- st_read(here::here("prac2_data",
#                         "Local_Authority_Districts_(December_2015)_Boundaries",
#                         "Local_Authority_Districts_(December_2015)_Boundaries.shp"))


# 读取数据集
LondonData <- read_csv("https://data.london.gov.uk/download/ward-profiles-and-atlas/772d2d64-e8c6-46cb-86f9-e52b4c7851bc/ward-profiles-excel-version.csv",
                       locale = locale(encoding = "latin1"),
                       na = "n/a")


# 拉出来London基础地图
LondonMap<- EW %>%
  filter(str_detect(lad15cd, "^E09"))
LondonMap


# 使用plot函数绘制
qtm(LondonMap)

# 被数据填充后显示不同颜色的交互地图
#qtm()
#qtm(LondonMap,fill = "lad15nm")


# 清理数据名称（使用janitor的clean_names函数对列名称做了一定的清洗，里面的空格将会变成下划线，而且大写字母会转化为小写字母）
# 属性数据连接到边界
LondonData <- clean_names(LondonData)

# EW是从网站直接读取的数据 
BoroughDataMap <- EW %>%
  clean_names()%>%
  # . 的意思是直接使用加载的数据
  filter(str_detect(lad15cd, "^E09"))%>%
  merge(.,
        LondonData, 
        by.x="lad15cd", 
        by.y="new_code",
        no.dups = TRUE)%>%
  distinct(.,lad15cd,
           .keep_all = TRUE)


# left_join替代merge
# 更容易控制 数据和底图连接 的工作方式
BoroughDataMap2 <- EW %>% 
  clean_names() %>%
  filter(str_detect(lad15cd, "^E09"))%>%
  left_join(., 
            LondonData,
            by = c("lad15cd" = "new_code"))


# 简单的映射（形成基本Map）
qtm(BoroughDataMap, 
    fill = "rate_of_job_seekers_allowance_jsa_claimants_2015")


# 从OSM中提取底图
tmaplondon <- BoroughDataMap %>%
  st_bbox(.) %>% 
  tmaptools::read_osm(., type = "osm", zoom = NULL)


# 增加底图、改变原始Map样式，增加元素
# alpha透明度, compass指南针, scale比例，legend图例
# style数据划分不同颜色，palette配色方案

tmap_mode("plot")

tm_shape(tmaplondon)+
  tm_rgb()+
  tm_shape(BoroughDataMap) + 
  tm_polygons("rate_of_job_seekers_allowance_jsa_claimants_2015", 
              style="jenks",
              palette="YlOrBr",
              midpoint=NA,
              title="Rate per 1,000 people",
              alpha = 0.5) + 
  tm_compass(position = c("left", "bottom"),type = "arrow") + 
  tm_scale_bar(position = c("left", "bottom")) +
  tm_layout(title = "Job seekers' Allowance Claimants", legend.position = c("right", "bottom"))


# 调取R的调色板，可进行自主配色😊
#palette_explorer()
# 或者 tmaptools::palette_explorer()


# 将之前计算出的数据（Life_expectancy4）映射到该图
Life_expectancy4map <- EW %>%
  inner_join(., 
             Life_expectancy4,
             by = c("lad15cd" = "new_code"))%>%
  distinct(.,lad15cd, 
           .keep_all = TRUE)


# 更加细化制作地图
# 和码100的原理相同
tmap_mode("plot")

tm_shape(tmaplondon)+
  tm_rgb()+
  tm_shape(Life_expectancy4map) + 
  tm_polygons("UKdiff", 
              style="pretty",
              palette="Blues",
              midpoint=NA,
              title="Number of years",
              alpha = 0.5) + 
  tm_compass(position = c("left", "bottom"),type = "arrow",text.size = 0.5) + 
  tm_scale_bar(position = c("left", "bottom"),text.size = 0.3) +
  tm_layout(title = "Difference in life expectancy", title.size =2,
            legend.position = c("right", "bottom"),
            legend.title.size = 0.6,legend.text.size = 0.3)
