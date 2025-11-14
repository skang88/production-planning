# 데이터 핸들링 및 비교

# 필요한 패키지 로드
if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}
if (!requireNamespace("lubridate", quietly = TRUE)) {
  install.packages("lubridate")
}
library(dplyr)
library(lubridate)

# 주석: 'current_stock' 테이블에서 'material'과 'current_stock' 컬럼을 선택합니다.
# 실제 컬럼명이 다를 경우, 아래 코드의 컬럼명을 수정해야 합니다.
# 예: current_stock %>% select(자재코드_컬럼명, 재고량_컬럼명)
current_stock_simple <- current_stock %>%
  select(material, current_stock)

# 내일 날짜 계산
tomorrow_date <- Sys.Date() + 1

# 'daily_requirements'에서 내일 날짜 데이터만 필터링
# 주석: 'requirement_date', 'material_number', 'requirement_value' 컬럼명을 사용합니다. 실제 컬럼명에 맞게 수정이 필요할 수 있습니다.
dr_tomorrow <- daily_requirements %>%
  filter(ymd(requirement_date) == tomorrow_date) %>%
  select(material_number, daily_req_qty = requirement_value) %>% 
  rename(material = material_number)

# 'two_hour_info_tomorrow'의 소요량을 자재별로 합산
# 주석: 'material'과 'quantity' 컬럼명을 사용합니다. 실제 컬럼명에 맞게 수정이 필요할 수 있습니다.
t2h_tomorrow_agg <- two_hour_info_tomorrow %>%
  group_by(material) %>%
  summarise(two_hour_req_qty = sum(quantity, na.rm = TRUE))

# 두 데이터프레임을 'material' 기준으로 조인하여 소요량 비교
comparison_df <- dr_tomorrow %>%
  inner_join(t2h_tomorrow_agg, by = "material") %>%
  mutate(difference = daily_req_qty - two_hour_req_qty)

# 차이가 있는 항목만 필터링
diff_items <- comparison_df %>%
  filter(difference != 0)

# 결과 출력
print("--- 'daily_requirements'와 'two_hour_info_tomorrow'의 내일 소요량 비교 ---")
if (nrow(diff_items) > 0) {
  print("차이가 발견된 자재:")
  print(diff_items)
} else {
  print("모든 자재의 소요량이 일치합니다.")
}

# 메모리 정리
rm(current_stock_simple, tomorrow_date, dr_tomorrow, t2h_tomorrow_agg, comparison_df, diff_items)

print("데이터 핸들링 및 비교 스크립트 실행 완료.")

