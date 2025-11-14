# 데이터 탐색 및 시각화: 일별/품번별 소요량 히트맵

# --- 1. 필요한 패키지 로드 ---
# 데이터 핸들링, 시각화, DB연결에 필요한 패키지를 로드합니다.
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")
if (!requireNamespace("RMySQL", quietly = TRUE)) install.packages("RMySQL")
if (!requireNamespace("DBI", quietly = TRUE)) install.packages("DBI")
if (!requireNamespace("lubridate", quietly = TRUE)) install.packages("lubridate")
if (!requireNamespace("showtext", quietly = TRUE)) install.packages("showtext")
if (!requireNamespace("curl", quietly = TRUE)) install.packages("curl") # curl 패키지 추가

library(dplyr)
library(ggplot2)
library(RMySQL)
library(DBI)
library(lubridate)
library(showtext)
library(curl) # curl 패키지 로드

# 한글 폰트 설정 (Windows 사용자의 경우)
font_add_google("Nanum Gothic", "nanumgothic")
showtext_auto()

# --- 2. 데이터베이스 연결 및 데이터 로드 ---
db_host <- "172.16.220.32"
db_user <- "seokgyun"
db_password <- "1q2w3e4r"
db_name <- "GSCP"

daily_requirements <- tryCatch({
  con <- dbConnect(MySQL(), user = db_user, password = db_password, dbname = db_name, host = db_host, port = 3306)
  query_req <- "SELECT * FROM daily_requirements WHERE release_date = (SELECT MAX(release_date) FROM daily_requirements)"
  df <- dbGetQuery(con, query_req)
  dbDisconnect(con)
  message("데이터베이스에서 소요량 데이터를 성공적으로 가져왔습니다.")
  df
}, error = function(e) {
  message("DB 연결 또는 쿼리 실행 중 오류 발생: ", e$message)
  NULL
})

# --- 3. 데이터 처리 ---
# 가져온 데이터가 있을 경우에만 후속 처리 실행
if (!is.null(daily_requirements)) {
  
  # 날짜 형식 변환 및 품번별, 일자별 소요량 합산
  heatmap_data <- daily_requirements %>%
    mutate(requirement_date = as.Date(requirement_date)) %>%
    group_by(material_number, requirement_date) %>%
    summarise(total_req = sum(requirement_value, na.rm = TRUE)) %>%
    ungroup()

  # --- 4. 히트맵 시각화 ---
  heatmap_plot <- ggplot(heatmap_data, aes(x = requirement_date, y = reorder(material_number, desc(material_number)), fill = total_req)) +
    geom_tile(color = "white", size = 0.5) + # 각 타일의 테두리 설정
    geom_text(aes(label = ifelse(total_req > 0, total_req, "")), color = "black", size = 3) + # 0보다 큰 값만 텍스트로 표시
    scale_fill_gradient(low = "ivory", high = "red", name = "소요량") + # 색상 스케일 설정
    scale_x_date(date_breaks = "1 day", date_labels = "%m/%d") + # x축 날짜 형식 지정
    labs(
      title = "품번별 일일 소요량 히트맵",
      subtitle = paste("데이터 기준 Release Date:", max(daily_requirements$release_date)),
      x = "소요 날짜",
      y = "품번"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1), # x축 텍스트 90도 회전
      plot.title = element_text(size = 20, face = "bold"),
      legend.position = "bottom"
    )

  # --- 5. 그래프 출력 ---
  print(heatmap_plot)
  
} else {
  message("데이터가 없어 히트맵을 생성할 수 없습니다.")
}
