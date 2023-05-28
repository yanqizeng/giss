library(sf)
library(tmap)
library(tmaptools)
library(RSQLite)
library(tidyverse)
library(dplyr)
library(janitor)
library(plotly)

# 读取储存在R Project文件夹里的csv数据（方法1）
# LondonDataOSK是赋予数据在R里的代称，可随意更换
LondonDataOSK<- read.csv("prac2_data/ward-profiles-excel-version.csv", 
                         header = TRUE, 
                         sep = ",",  
                         encoding = "latin1")


# 读取储存在R Project文件夹里的csv数据（方法2）
# 安装 install.packages("here")  已安装
# 调用 library(here)
# 运行 
#LondonDataOSK<- read.csv(here::here("prac2_data","ward-profiles-excel-version.csv"), 
#                         header = TRUE, sep = ",",  
#                         encoding = "latin1")


# 直接从网页连接读取数据
#LondonData <- read_csv("https://data.london.gov.uk/download/ward-profiles-and-atlas/772d2d64-e8c6-46cb-86f9-e52b4c7851bc/ward-profiles-excel-version.csv",
#                       locale = locale(encoding = "latin1"),
#                       na = "n/a")



# 检查程序是否成功读取，更换“LondonDataOSK" 即可
Datatypelist <- LondonDataOSK %>% 
  summarise_all(class) %>%
  pivot_longer(everything(), 
               names_to="All_variables", 
               values_to="Variable_class")

Datatypelist


# 快速编辑数据，更换“LondonDataOSK" 即可
# LondonDataOSK <- edit(LondonDataOSK)


# 汇总数据
#summary(df)


# 查看列标题，更换“LondonDataOSK" 即可，想查看前几列head()里填几
LondonDataOSK%>%
  colnames()%>%
  head(30)


# 选择行😀 
# 选择第几行 - 第几行的数据，并创建子集，例如目前627-659
#LondonBoroughs <- LondonDataOSK%>%
#  slice(627:659)


# 或者根据区域代码提取
# “New.code"是（码34 读取结果）区域代码的标题，结合原数据一起看
# "E09"是所有以E09开头的区域
#  LondonBoroughs 是根据区域代码提取数据，形成的列表
LondonBoroughs<- LondonDataOSK %>% 
  filter(str_detect(`New.code`, "^E09"))


# 检查按区域编码的载入是否有效
# `Ward.name` 是（码34 读取结果）区域名称的标题
LondonBoroughs$`Ward.name`


# 数据重复，多行出现时，仅提取一行
LondonBoroughs<-LondonBoroughs %>%
  distinct()



# 选择列😀
# 选择包含某些单词的列，即 根据名称选列
#  LondonBoroughs_contains是在选完行 的基础上，根据名称选择数据，形成的列表
# 注意：具体数据名称参考 码52 （LondonDataOSK%>% colnames()%>% head(30)）
LondonBoroughs_contains<-LondonBoroughs %>% 
  dplyr::select(contains("New.code"),
                contains("Ward.name"),
                contains("expectancy"), 
                contains("obese..2011.12.to.2013.14")) 


# 重命名列，例如，“Ward.name" 重命名为 Borough
LondonBoroughs_contains <- LondonBoroughs_contains %>%
  dplyr::rename(Borough=`Ward.name`)%>%
  clean_names()




# ♥
# 1.男性和女性的平均预期寿命（averagelifeexpectancy）
# 2.基于伦敦平均值的每个伦敦行政区的标准化值（normalisedlifeepectancy）
# 3.只展示 自治市镇的名称、平均预期寿命和标准化预期寿命
# 4.根据标准化预期寿命（normalisedlifeepectancy）降序排列输出

Life_expectancy <- LondonBoroughs_contains %>%
  # 1
  # 计算的数据具体名称，来自右侧LondonBoroughs_contains表格
  mutate(averagelifeexpectancy= (female_life_expectancy_2009_13 +
                                   male_life_expectancy_2009_13)/2)%>%
  # 2
  mutate(normalisedlifeepectancy= averagelifeexpectancy /
           mean(averagelifeexpectancy))%>%
  # 3
  dplyr::select(new_code,
                borough,
                averagelifeexpectancy, 
                normalisedlifeepectancy)%>%
  # 4
  arrange(desc(normalisedlifeepectancy))

          
# 展示上面计算结果的顶部5行
slice_head(Life_expectancy, n=5)

# 展示上面计算结果的底部5行
slice_tail(Life_expectancy,n=5)



# ♥
# 对比伦敦行政区的预期寿命与英国平均81.16岁
# 伦敦行政区的预期寿命（Life_expectancy）
# 对比结果列表（Life_expectancy2）

Life_expectancy2 <- Life_expectancy %>%
  mutate(UKcompare = case_when(averagelifeexpectancy>81.16 ~ "above UK average",
                               TRUE ~ "below UK average"))
Life_expectancy2



# ♥
# 伦敦自治市的预期寿命范围高于全国平均水平 （数据证明，高的有几个，低的有几个）

Life_expectancy2_group <- Life_expectancy2 %>%
  mutate(UKdiff = averagelifeexpectancy-81.16) %>%
  group_by(UKcompare)%>%
  summarise(range=max(UKdiff)-min(UKdiff), count=n(), Average=mean(UKdiff))

Life_expectancy2_group



# ♥
# 根据自治市镇的分布 与 全国平均水平 相比获得更详细的信息
# 例：低1年的几个，高2年的几个

Life_expectancy3 <- Life_expectancy %>%
  # 1.再次计算出自治市镇的预期寿命与全国平均水平之间的差异
  mutate(UKdiff = averagelifeexpectancy-81.16)%>%
  
  # 2.根据列是否为数字来舍入整个表
  mutate(across(where(is.numeric), round, 3))%>%
  
  # 3.将UKdiff四舍五入到小数点后 0 位
  mutate(across(UKdiff, round, 0))%>%
  
  # 4.查找平均年龄等于或超过 81 岁的镇
  mutate(UKcompare = case_when(averagelifeexpectancy >= 81 ~ 
                                 str_c("equal or above UK average by",
                                       UKdiff, 
                                       "years", 
                                       sep=" "), 
                               TRUE ~ str_c("below UK average by",
                                            UKdiff,
                                            "years",
                                            sep=" ")))%>%
  
  # 5.按UKcompare列分组
  group_by(UKcompare)%>%
  
  # 6.数一数每组的人数
  summarise(count=n())

Life_expectancy3




# 使用数据制作一些简单的图👇
# plot()函数简单快速出图
plot(LondonBoroughs$Male.life.expectancy..2009.13,
     LondonBoroughs$Rate.of.new.registrations.of.migrant.workers...2011.12)

# 拉皮条/美化 图表
# 首先 install.packages("plotly")
plot_ly(LondonBoroughs, 
        #data for x axis
        x = ~Male.life.expectancy..2009.13, 
        #data for y axis
        y = ~Rate.of.new.registrations.of.migrant.workers...2011.12, 
        #attribute to display when hovering 
        type = "scatter", 
        mode = "markers")
