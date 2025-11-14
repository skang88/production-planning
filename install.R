# install.R
# 필요한 모든 R 패키지를 설치합니다.
install.packages(c(
  "shiny", 
  "dplyr", 
  "DT", 
  "RMySQL", 
  "odbc", 
  "DBI", 
  "lubridate", 
  "ggplot2", 
  "showtext", 
  "scales", 
  "tidyr", 
  "rhandsontable", 
  "writexl",
  "curl"
), repos = "https://cran.rstudio.com/")
