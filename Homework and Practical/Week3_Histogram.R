library(sf)
library(here)
library(sp)

# 接下来处理的是矢量数据（vector data）

# 读取后缀是.gpkg的文件
st_layers(here("prac3_Data","gadm36_AUS_gpkg","gadm36_AUS.gpkg"))

# 读取Ausoutline的图层
Ausoutline <- st_read(here("prac3_Data","gadm36_AUS_gpkg","gadm36_AUS.gpkg"), 
                      layer='gadm36_AUS_0')


# 检查坐标参考系 Geodetic CRS
# WGS84 是最常见的全球投影系统之一，几乎用于所有 GPS 设备
print(Ausoutline)


# 如果加载以上几步，发现没有坐标参考系CRS，可以用EPSG
# CRS和EPSG是对应的
# 如：WGS84对应的EPSG是4326
#Ausoutline <- st_read(here("prac3_data", "gadm36_AUS_gpkg","gadm36_AUS.gpkg"), 
#                      layer='gadm36_AUS_0') %>% 
#  st_set_crs(4326)



# 重新投影空间数据 / 转换坐标参考系CRS
# 原始空间数据是全球最常用的WGS84
# 为了之后方便载入当地数据，转换CRS为澳大利亚当地的，也就是GDA94
# GDA94对应的EPSG是3112
AusoutlinePROJECTED <- Ausoutline %>%
  st_transform(.,3112)

print(AusoutlinePROJECTED)





# 接下来处理的是栅格数据（raster data)😊

# WorldClim 免费的全球气候层（栅格）数据集
# 读取数据 （12个月平均温度...）
# 此处读入的格栅以 jan 代表
library(raster)
library(terra)
jan<-terra::rast(here("prac3_Data", "wc2.1_5m_tavg","wc2.1_5m_tavg_01.tif"))
# 展示格栅 jan 的基本信息
jan


# 快速查看jan的数据，且形成map
plot(jan)


# 执行plot(jan)后出现“Error in x$.self$finalize() : attempt to apply non-function”
# 虽然plot成图 但存在潜在问题
# 为避免影响之后工作，重新投影栅格
# 重新投影栅格，必须重新计算整个网格
# 再把属性重新连接到网格

# ESRI:54009是World Mollweide
newproj<-"ESRI:54009"

# 借助World Mollweide,将投影投影保存到新对象
# 投影保留区域比例，但失去角度和形状的准确性
pr1 <- jan %>%
  terra::project(., newproj)
plot(pr1)


# 修正角度和形状问题，确保准确性
# 重新赋予 WGS84（最常见的全球投影系统）
pr1 <- pr1 %>%
  terra::project(., "EPSG:4326")
plot(pr1)



# 更智能的加载数据⭐   满足使用全部相关数据的需求

# 载入 数据文件夹
library(fs)
dir_info("prac3_Data/wc2.1_5m_tavg") 


# 选择真正需要的数据（12个月的平均温度）
# 目前所需的数据是后缀.tif
library(tidyverse)
listfiles<-dir_info("prac3_data/wc2.1_5m_tavg") %>%
  filter(str_detect(path, ".tif")) %>%
  dplyr::select(path)%>%
  pull()
# 查看后缀.tif文件的信息
listfiles


# 所有数据加载到SpatRaster，SR是栅格图层的集合
worldclimtemp <- listfiles %>%
  terra::rast()
# 查看所有数据都连接到栅格图层后，形成的stack堆栈的信息
worldclimtemp

# 查看一月的平均温度，查几月改[]内数字
#worldclimtemp[[1]]


# 重新命名stack堆栈中图层的名称
# 此重命名方法适针对 格栅数据😔
month <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

names(worldclimtemp) <- month

# 重命名后查看一月的平均温度
#worldclimtemp$Jan



# Raster stack栅格堆栈可以简易提取数据
# 示例如下
# 补充Australian城市数据
site <- c("Brisbane", "Melbourne", "Perth", "Sydney", "Broome", "Darwin", "Orange", 
          "Bunbury", "Cairns", "Adelaide", "Gold Coast", "Canberra", "Newcastle", 
          "Wollongong", "Logan City" )
lon <- c(153.03, 144.96, 115.86, 151.21, 122.23, 130.84, 149.10, 115.64, 145.77, 
         138.6, 153.43, 149.13, 151.78, 150.89, 153.12)
lat <- c(-27.47, -37.91, -31.95, -33.87, 17.96, -12.46, -33.28, -33.33, -16.92, 
         -34.93, -28, -35.28, -32.93, -34.42, -27.64)
# 以上数据放到名为samples的列表
samples <- data.frame(site, lon, lat, row.names="site")
# 从已有的Raster stack（worldclimtemp)提取点数据
# 一个城市代表一个点
AUcitytemp<- terra::extract(worldclimtemp, samples)


# 为提取的点数据添加对应城市名称
# .before = "Jan" 在一月数据前建立城市名称列
Aucitytemp2 <- AUcitytemp %>% 
  as_tibble()%>% 
  add_column(Site = site, .before = "Jan")




# Descriptive Statistics 描述性统计😊

# 数据的其中一个子集形成 Histogram直方图
# Histogram：横轴-数据类型  纵轴-数据分布情况
# 以上面加入的城市 Perth 为例
Perthtemp <- Aucitytemp2 %>%
  filter(site=="Perth")

# ♥制作基础Histogram ♥
# x轴是温度，Y轴是出现频率
# Histogram有空缺的异常值，因为ID 3的存在
hist(as.numeric(Perthtemp))


# ♥美化Histogram ♥
library(tidyverse)
# 定义Histogram 在X轴的中断点
userbreak<-c(8,10,12,14,16,18,20,22,24,26)

# 选择形成Histogram的列（同时去除了ID 3）
Perthtemp <- Aucitytemp2 %>%
  filter(site=="Perth")

t<-Perthtemp %>%
  dplyr::select(Jan:Dec)

hist((as.numeric(t)), 
     breaks=userbreak, 
     col="red", 
     main="Histogram of Perth Temperature", 
     xlab="Temperature", 
     ylab="Frequency")


# 查看生成的Histogram 信息
histinfo <- as.numeric(t) %>%
  as.numeric()%>%
  hist(.)

# breaks：x轴的中断点
# count: 每一"条"的单元格数
# midpoints: 每一"条"的中间值
# density: 每一"条"的数据密度
histinfo



# 使用更多数据制作图 ⭐

# 整个Ausoutline 12个月的平均温度分布
# 【一】绘制Ausoutline几何map直观查看
# 形成Ausoutline领土形状
plot(Ausoutline$geom)

# 简化形状
AusoutSIMPLE <- Ausoutline %>%
  st_simplify(., dTolerance = 1000) %>%
  st_geometry()%>%
  plot()

# 形成初步图集
print(Ausoutline)
# crs()为确保两者在同一参考系
crs(worldclimtemp)
# 裁剪WorldClim数据，只保留Ausoutline的部分
# 组合 矢量的Ausoutline形状 + 保留的WorldClim栅格数据
Austemp <- Ausoutline %>%
  terra::crop(worldclimtemp,.)
plot(Austemp)

# 精细化图集
exactAus<-terra::mask(Austemp, Ausoutline)



# 【二】制作Ausoutline的Histogram
# 栅格数据变成 data.frame
# 使数据兼容
exactAusdf <- exactAus %>%
  as.data.frame()


library(ggplot2)
# 借助ggplot2 建立Histogram
# 🥧Histogram上只有一个数据🥧
# Ausoutline 三月
gghist <- ggplot(exactAusdf, 
                 aes(x=Mar)) + 
  geom_histogram(color="black", 
                 fill="white")+
  labs(title="Ggplot2 histogram of Australian March temperatures", 
       x="Temperature", 
       y="Frequency")

# 在Histogram上添加显示平均温度的蓝色虚线
gghist + geom_vline(aes(xintercept=mean(Mar, 
                                        na.rm=TRUE)),
                    color="blue", 
                    linetype="dashed", 
                    size=1)+
  theme(plot.title = element_text(hjust = 0.5))


# 🥧同一个Histogram上多个数据🥧
# 使用pivot_longer()
# squishdata是为形成最终直方图做准备的空图表
# Month列里是1-12月名字
# Temp列里是值
squishdata<-exactAusdf%>%
  pivot_longer(
    cols = 1:12,
    names_to = "Month",
    values_to = "Temp"
  )

# 例如，选择Jan 和 Jun 在直方图中展示数据
twomonths <- squishdata %>%
  # | = OR
  filter(., Month=="Jan" | Month=="Jun")

# 所选两个月的温度品均值
meantwomonths <- twomonths %>%
  group_by(Month) %>%
  summarise(mean=mean(Temp, na.rm=TRUE))

meantwomonths

# 基于不同变量（Jan Jun）填充颜色..线条..
ggplot(twomonths, aes(x=Temp, color=Month, fill=Month)) +
  geom_histogram(position="identity", alpha=0.5)+
  geom_vline(data=meantwomonths, 
             aes(xintercept=mean, 
                 color=Month),
             linetype="dashed")+
  labs(title="Ggplot2 histogram of Australian Jan and Jun
       temperatures",
       x="Temperature",
       y="Frequency")+
  theme_classic()+
  theme(plot.title = element_text(hjust = 0.5))


# 🥧多个数据在各自的Histogram🥧
# drop_na()指定数据顺序
data_complete_cases <- squishdata %>%
  drop_na()%>% 
  mutate(Month = factor(Month, levels = c("Jan","Feb","Mar",
                                          "Apr","May","Jun",
                                          "Jul","Aug","Sep",
                                          "Oct","Nov","Dec")))

# 形成Histogram
ggplot(data_complete_cases, aes(x=Temp, na.rm=TRUE))+
  geom_histogram(color="black", binwidth = 5)+
  labs(title="Ggplot2 faceted histogram of Australian temperatures", 
       x="Temperature",
       y="Frequency")+
  facet_grid(Month ~ .)+
  theme(plot.title = element_text(hjust = 0.5))


# 🥧可以交互的Histogram🥧
library(plotly)
# 例如，选择Jan 和 Jun 在直方图中展示数据
jan <- squishdata %>%
  drop_na() %>%
  filter(., Month=="Jan")

jun <- squishdata %>%
  drop_na() %>%
  filter(., Month=="Jun")

# 命名x y轴
x <- list (title = "Temperature")
y <- list (title = "Frequency")

# 设置bin"条“宽度
xbinsno<-list(start=0, end=40, size = 2.5)

# 形成Histogram
ihist<-plot_ly(alpha = 0.6) %>%
  add_histogram(x = jan$Temp,
                xbins=xbinsno, name="January") %>%
  add_histogram(x = jun$Temp,
                xbins=xbinsno, name="June") %>% 
  layout(barmode = "overlay", xaxis=x, yaxis=y)

ihist




# 🌙以下是展示数据的平均值.最大值.最小值...🍎
# 每个月平均值
meanofall <- squishdata %>%
  group_by(Month) %>%
  summarise(mean = mean(Temp, na.rm=TRUE))

# 接下来的数据查看，记得都加此行
# print the top 1
head(meanofall, n=1)


# 每个月标准差
sdofall <- squishdata %>%
  group_by(Month) %>%
  summarize(sd = sd(Temp, na.rm=TRUE))

# 每个月最大值
maxofall <- squishdata %>%
  group_by(Month) %>%
  summarize(max = max(Temp, na.rm=TRUE))

# 每个月最小值
minofall <- squishdata %>%
  group_by(Month) %>%
  summarize(min = min(Temp, na.rm=TRUE))

# 每个月四分位距
IQRofall <- squishdata %>%
  group_by(Month) %>%
  summarize(IQR = IQR(Temp, na.rm=TRUE))



