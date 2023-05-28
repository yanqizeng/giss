library(sf)
library(here)
library(sp)
library(raster)
library(terra)
library(janitor)
library(tidyverse)
library(ggplot2)



# 读取China的.gpkg文件
st_layers(here("prac3_Data","gadm41_CHN.gpkg"))

# 提取未分割的整块国土的图层，在QGIS查看到底是哪个
China <- st_read(here("prac3_Data","gadm41_CHN.gpkg"), 
                      layer='ADM_ADM_0')


# 检查坐标参考系 Geodetic CRS
# WGS84 是最常见的全球投影系统之一，几乎用于所有 GPS 设备
print(China)


# 重新投影空间数据 / 转换坐标参考系CRS
# 原始空间数据是全球最常用的WGS84
# 为了之后方便载入当地数据，转换CRS为中国当地的
# 对应的EPSG是4610
ChinaPROJECTED <- China %>%
  st_transform(.,4610)

print(ChinaPROJECTED)


# 读取世界城市shp（包含城市点）
world_cities <- sf::st_read(here("prac3_Data", "World_Cities", "World_cities.shp"))


# 接下来处理的是栅格数据（raster data)😊
# 读取homework要求的数据
# ssp1 和 ssp5

ssp1 <-terra::rast(here("prac3_Data", "wc2.1_2.5m_tmax_ACCESS-CM2_ssp126_2081-2100.tif"))
# 展示格栅 ssp1 的基本信息
ssp1

ssp5 <-terra::rast(here("prac3_Data", "wc2.1_2.5m_tmax_ACCESS-CM2_ssp585_2081-2100.tif"))
# 展示格栅 ssp5 的基本信息
ssp5


# 目前拥有整个世界城市的shp（及城市点)
# 只保留需要的China（及城市点)
# 并且名称大写变小写，空格变_
# 使用Prac2：指定列的特定信息
China_cities <- world_cities %>%
  janitor::clean_names()%>%
  dplyr::filter(cntry_name=="China")


# 裁剪（crop）和覆盖（mask）Raster Data ssp1和ssp5
# 只保留需要的China
# 代码相同，但根据需要，生成ssp1和ssp5不同模型
# ssp1
China_diff1 <- ssp1 %>%
  terra::crop(.,China)

exact_China1 <- China_diff1 %>%
  terra::mask(.,China)

# ssp5
China_diff5 <- ssp5 %>%
  terra::crop(.,China)

exact_China5 <- China_diff5 %>%
  terra::mask(.,China)


# 根据作业需求
# 整个China ssp1和ssp5温度
# 至于是 谁减谁，试试，减去后是正数就是对的
diff_climate_model <- exact_China5 - exact_China1


# 重命名stack堆栈中图层的名称
month <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

names(diff_climate_model) <- month

# ssp1和ssp5的温度差数据 载入到 China的 城市点
# 形成 点位 温差数据
China_city_diff<- terra::extract(diff_climate_model, China_cities)



# China_cities是几何shp（包含城市点）
# China_city_diff 是点位温差数据
#
# 通过给China_citie添加ID
# 建立 几何shp的城市点和点位温差数据 的联系
# 使两者可以结合
# 这样就知道具体城市的温差
# 😊
China_cities_join_ID <- China_cities %>%
  dplyr::mutate(join_id= 1:n())

China_city_diff2 <- China_cities_join_ID%>%
  dplyr::left_join(.,
                   China_city_diff,
                   by = c("join_id" = "ID"))


# 接下来制作Histogram
# 选取 具体城市温差 数据中所需的部分
city_climate_diff <- China_city_diff2 %>%
  dplyr::select(c(,16:27))%>%
  sf::st_drop_geometry(.)%>%
  dplyr::as_tibble()

# tidy_city_diff是为形成最终直方图做准备的空图表
# Month是x轴名字
# temp_diff是Y轴的数据
tidy_city_diff <- city_climate_diff %>%
  tidyr::pivot_longer(everything(), 
                      names_to="Months", 
                      values_to="temp_diff")

# 指定Histogram 数据顺序
facet_plot <- tidy_city_diff %>%
  dplyr::mutate(Months = factor(Months, levels = c("Jan","Feb","Mar",
                                                   "Apr","May","Jun",
                                                   "Jul","Aug","Sep",
                                                   "Oct","Nov","Dec")))


# 形成Histogram
plot<-ggplot(facet_plot, aes(x=temp_diff, na.rm=TRUE))+
  geom_histogram(color="black", binwidth = .1)+
  labs(title="Ggplot2 faceted difference in climate scenarios of max temp", 
       x="Temperature",
       y="Frequency")+
  facet_grid(Months ~ .)+
  theme(plot.title = element_text(hjust = 0.5))

plot
