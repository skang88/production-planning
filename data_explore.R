# 3-Way 데이터 결합 및 일자별 재고 소진 계산

# --- 1. 필요한 패키지 로드 ---
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("DBI", quietly = TRUE)) install.packages("DBI")
if (!requireNamespace("RMySQL", quietly = TRUE)) install.packages("RMySQL")
if (!requireNamespace("odbc", quietly = TRUE)) install.packages("odbc")

library(dplyr)
library(DBI)
library(RMySQL)
library(odbc)

# --- 2. 데이터 로드 함수 정의 ---

# MySQL 데이터 로드 함수
fetch_mysql_data <- function() {
  db_host <- "172.16.220.32"
  db_user <- "seokgyun"
  db_password <- "1q2w3e4r"
  db_name <- "GSCP"
  
  tryCatch({
    con <- dbConnect(MySQL(), user = db_user, password = db_password, dbname = db_name, host = db_host, port = 3306)
    
    query_stock <- "SELECT * FROM current_stock WHERE capture_date = (SELECT MAX(capture_date) FROM current_stock)"
    customer_stock <- dbGetQuery(con, query_stock)
    
    query_req <- "SELECT * FROM daily_requirements WHERE release_date = (SELECT MAX(release_date) FROM daily_requirements)"
    daily_req <- dbGetQuery(con, query_req)
    
    dbDisconnect(con)
    message("MySQL 데이터 로드 성공.")
    return(list(customer_stock = customer_stock, daily_req = daily_req))
  }, error = function(e) {
    message("MySQL 데이터 로드 실패: ", e$message)
    return(NULL)
  })
}

# MS SQL Server 데이터 로드 함수
fetch_mssql_data <- function() {
  db_driver <- "SQL Server"
  db_server <- "172.16.220.3"
  db_database <- "SAG"
  db_user <- "seokgyun"
  db_password <- "1q2w3e4r"
  
  query_stock <- "
    SELECT ITMNO, SUM(JQTY) AS RackStock
    FROM SAG.dbo.MAT_ITMBLPFSUB
    WHERE WARHS = 'AA' AND JQTY > 0
    GROUP BY ITMNO
  "
  
  tryCatch({
    con_str <- paste0("Driver={", db_driver, "};Server=", db_server, ";Database=", db_database, ";Uid=", db_user, ";Pwd=", db_password, ";")
    con <- dbConnect(odbc(), .connection_string = con_str)
    df <- dbGetQuery(con, query_stock)
    dbDisconnect(con)
    message("MS SQL Server 데이터 로드 성공.")
    return(df)
  }, error = function(e) {
    message("MS SQL Server 데이터 로드 실패: ", e$message)
    return(NULL)
  })
}

# --- 3. 데이터 로드 실행 ---
mysql_data <- fetch_mysql_data()
our_stock <- fetch_mssql_data()

# --- 4. 데이터 처리 및 계산 ---
if (!is.null(mysql_data) && !is.null(our_stock)) {
  
  # 4.1. 초기 총 재고 계산
  customer_stock_simple <- mysql_data$customer_stock %>%
    select(material, customer_stock = current_stock)
  
  our_stock_simple <- our_stock %>%
    rename(material = ITMNO, our_stock = RackStock)
  
  total_initial_stock <- full_join(customer_stock_simple, our_stock_simple, by = "material") %>%
    mutate(
      customer_stock = ifelse(is.na(customer_stock), 0, customer_stock),
      our_stock = ifelse(is.na(our_stock), 0, our_stock),
      total_stock = customer_stock + our_stock
    ) %>%
    select(material, total_stock)

  # 4.2. 일별 소요량 정리
  daily_req_processed <- mysql_data$daily_req %>%
    mutate(requirement_date = as.Date(requirement_date)) %>%
    group_by(material_number, requirement_date) %>%
    summarise(req_qty = sum(requirement_value, na.rm = TRUE)) %>%
    ungroup() %>%
    rename(material = material_number)

  # 4.3. 재고와 소요량 결합 및 재고 소진 시뮬레이션
  depletion_simulation <- daily_req_processed %>%
    filter(req_qty > 0) %>% # 소요량이 0보다 큰 경우만 계산
    left_join(total_initial_stock, by = "material") %>%
    mutate(total_stock = ifelse(is.na(total_stock), 0, total_stock)) %>%
    group_by(material) %>%
    arrange(requirement_date) %>%
    mutate(
      cumulative_req = cumsum(req_qty),
      projected_stock = total_stock - cumulative_req
    ) %>%
    ungroup() %>%
    select(
      품번 = material,
      소요날짜 = requirement_date,
      초기재고 = total_stock,
      일일소요량 = req_qty,
      누적소요량 = cumulative_req,
      예상재고 = projected_stock
    )

  # --- 5. 결과 확인 ---
  message("일자별 재고 소진 시뮬레이션 결과 (상위 20개):")
  print(head(depletion_simulation, 20))
  
} else {
  message("데이터 로드에 실패하여 계산을 진행할 수 없습니다.")
}