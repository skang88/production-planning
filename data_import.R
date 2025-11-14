# 데이터 로드

# 172.16.220.32 My SQL 서버에
# seokgyun // 1q2w3e4r
# 커넥션 정보를 이용해서 
# GSCP 데이터베이스의
# current_stock, daily_requirements, two_hour_info_today, two_hour_info_tomorrow, two_hour_info_yesterday

# 필요한 패키지 설치 및 로드
if (!requireNamespace("RMySQL", quietly = TRUE)) {
  install.packages("RMySQL")
}
if (!requireNamespace("DBI", quietly = TRUE)) {
  install.packages("DBI")
}
library(RMySQL)
library(DBI)

# 데이터베이스 연결 정보
db_host <- "172.16.220.32"
db_user <- "seokgyun"
db_password <- "1q2w3e4r"
db_name <- "GSCP"

# 데이터베이스에 연결
# 연결 오류 발생 시에도 스크립트가 중지되지 않도록 tryCatch 사용
con <- tryCatch({
  dbConnect(MySQL(),
            user = db_user,
            password = db_password,
            dbname = db_name,
            host = db_host,
            port = 3306) # MySQL 기본 포트
}, error = function(e) {
  message("데이터베이스 연결에 실패했습니다: ", e$message)
  NULL
})

# 연결이 성공했을 경우에만 데이터 가져오기 실행
if (!is.null(con)) {
  
  # 가져올 테이블 목록
  tables_to_import <- c("current_stock", 
                        "daily_requirements", 
                        "two_hour_info_today", 
                        "two_hour_info_tomorrow", 
                        "two_hour_info_yesterday")
  
  # 각 테이블을 데이터프레임으로 로드
  for (table_name in tables_to_import) {
    if (table_name == "daily_requirements") {
      query <- "SELECT * FROM daily_requirements WHERE release_date = (SELECT MAX(release_date) FROM daily_requirements)"
    } else if (table_name == "current_stock") {
      query <- "SELECT * FROM current_stock WHERE capture_date = (SELECT MAX(capture_date) FROM current_stock)"
    } else {
      query <- paste0("SELECT * FROM ", table_name)
    }
    # 쿼리 실행 중 오류 발생을 대비한 tryCatch
    df <- tryCatch({
      dbGetQuery(con, query)
    }, error = function(e) {
      message("'", table_name, "' 테이블을 가져오는 중 오류가 발생했습니다: ", e$message)
      NULL
    })
    
    if (!is.null(df)) {
      assign(table_name, df)
      message("'", table_name, "' 테이블을 성공적으로 가져왔습니다.")
    }
  }
  
  # 데이터베이스 연결 종료
  dbDisconnect(con)
  message("데이터베이스 연결이 종료되었습니다.")
  
} else {
  message("데이터 가져오기 작업을 수행할 수 없습니다.")
}

# 메모리에서 더 이상 사용하지 않는 변수 정리
rm(db_host, db_user, db_password, db_name, con, tables_to_import)

# 스크립트 실행 완료 메시지
print("데이터 가져오기 스크립트 실행 완료.")

