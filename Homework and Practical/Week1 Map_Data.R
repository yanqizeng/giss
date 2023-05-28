# 加载安装的软件包
library(sf)
library(tmap)
library(tmaptools)
library(RSQLite)
library(tidyverse)


# read in the shapefile
shape <- st_read(
  "D:/CASA__/0005_GIS/hw_week01/London/statistical-gis-boundaries-london/ESRI/London_Borough_Excluding_MHW.shp")

# read in the csv
mycsv <- read_csv("D:/CASA__/0005_GIS/hw_week01/London/fly-tipping-borough_03.csv")

# 在R里查看导入的csv文件
mycsv

# merge csv and shapefile
# 在此处，by.x=“shp文件的地域编码列 名称”，by.y=“csv文件的地域编码列 名称”
shape <- shape%>%
  merge(.,
        mycsv,
        by.x="GSS_CODE", 
        by.y="Row label")

# 此步骤检查数据的列名，n=10的10可以更改，表示查看“前10行”的数据.此步骤有助于更改接下来的数据展示范围，也就是“2013-2014”
shape%>%
  head(., n=10)

# set tmap to plot
# 当 "plot" 变为 "view" 将会变成可交互的地图
tmap_mode("plot")

# have a look at the map
# 符号+ 之后更改图例 标题 
  qtm(shape, fill = "2013-14") + 
    tm_legend(legend.position = c("right", "bottom"),
              main.title = "London Data",
              main.title.position = "left")

# write to a .gpkg
shape %>%
  st_write(.,"D:/CASA__/0005_GIS/hw_week01/London/London13_14map.gpkg",
           "london_boroughs_fly_tipping",
           delete_layer=TRUE)


# connect to the .gpkg
con <- dbConnect(RSQLite::SQLite(),dbname="D:/CASA__/0005_GIS/hw_week01/London/London13_14map.gpkg")

# list what is in it
con %>%
  dbListTables()

# add the original .csv
con %>%
  dbWriteTable(.,
               "original_csv",
               mycsv,
               overwrite=TRUE)

# disconnect from it
con %>% 
  dbDisconnect()


