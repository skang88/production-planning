# 필요한 패키지 로드
if (!requireNamespace("shiny", quietly = TRUE)) install.packages("shiny", repos = "https://cran.rstudio.com/")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr", repos = "https://cran.rstudio.com/")
if (!requireNamespace("DT", quietly = TRUE)) install.packages("DT", repos = "https://cran.rstudio.com/")
if (!requireNamespace("RMySQL", quietly = TRUE)) install.packages("RMySQL", repos = "https://cran.rstudio.com/")
if (!requireNamespace("odbc", quietly = TRUE)) install.packages("odbc", repos = "https://cran.rstudio.com/") # MS SQL용
if (!requireNamespace("DBI", quietly = TRUE)) install.packages("DBI", repos = "https://cran.rstudio.com/")
if (!requireNamespace("lubridate", quietly = TRUE)) install.packages("lubridate", repos = "https://cran.rstudio.com/")
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2", repos = "https://cran.rstudio.com/")
if (!requireNamespace("showtext", quietly = TRUE)) install.packages("showtext", repos = "https://cran.rstudio.com/")
if (!requireNamespace("scales", quietly = TRUE)) install.packages("scales", repos = "https://cran.rstudio.com/")

library(shiny)
library(dplyr)
library(DT)
library(RMySQL)
library(odbc)
library(DBI)
library(lubridate)
library(ggplot2)
library(showtext)
library(scales)
if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr", repos = "https://cran.rstudio.com/")
library(tidyr)
if (!requireNamespace("rhandsontable", quietly = TRUE)) install.packages("rhandsontable", repos = "https://cran.rstudio.com/")
library(rhandsontable)
if (!requireNamespace("writexl", quietly = TRUE)) install.packages("writexl", repos = "https://cran.rstudio.com/")
library(writexl)

# 한글 폰트 설정
font_add_google("Nanum Gothic", "nanumgothic")
showtext_auto()

# UI (사용자 인터페이스) 정의
ui <- fluidPage(
  tags$head(tags$style(HTML("
    .thick-right-border {
      border-right: 2px solid #555 !important;
    }
  "))),
  titlePanel("생산 관리 보조 시스템"),
  
  tabsetPanel(
    id = "main_tabs",
    tabPanel("납품 계획 입력",
             fluidRow(
               column(2, # Reduced width from 3 to 2
                      wellPanel(
                        h4("품번 선택"),
                        # 품번 선택
                        selectInput("sim_material_selector", NULL, choices = NULL, width = "100%"),
                        fluidRow(
                          column(3, actionButton("first_material", "<<", width = "100%")),
                          column(3, actionButton("prev_material", "<", width = "100%")),
                          column(3, actionButton("next_material", ">", width = "100%")),
                          column(3, actionButton("last_material", ">>", width = "100%"))
                        )
                      ),
                      uiOutput("data_timestamps"),
                      actionButton("auto_fill_all_materials", "모든 품번 대상 납품계획 자동 생성", class = "btn-warning", style = "margin-top: 10px; width: 100%;")
               ),
               column(10, # Expanded width from 9 to 10
                      h4("예상 재고 추이 그래프"),
                      plotOutput("simulation_plot"), # 시계열 차트
                      
                      h4("납품 계획 상세 (Pallet 단위 입력)"),
                      rHandsontableOutput("plan_handsontable"),
                      actionButton("auto_fill_plan", "납품 계획 자동 생성", class = "btn-primary", style = "margin-top: 10px;"),
                      actionButton("save_plan", "납품 계획 저장", class = "btn-success", style = "margin-top: 10px;"),
                      actionButton("reset_plan", "계획 초기화 (D+1~)", class = "btn-danger", style = "margin-top: 10px; margin-left: 5px;"),
                      
                      hr(),
                      h4("상세 데이터"),
                      DTOutput("simulation_table") # 데이터 테이블
               )
             )
    ),
    tabPanel("종합 납품 계획",
             fluidRow(
               column(12,
                      h4("전체 품번 납품 계획 (EA 단위)"),
                      p("표에서 직접 수량을 수정하고 '저장' 버튼을 누르세요."),
                      rHandsontableOutput("aggregated_plan_table"),
                      fluidRow( # Use fluidRow to contain buttons
                          column(12, align = "right", # Align both buttons to the right
                                 actionButton("save_aggregated_plan", "변경사항 저장", class = "btn-success", style = "margin-top: 10px; margin-left: 10px;"), # Add margin-left for spacing
                                 downloadButton("download_aggregated_plan", "엑셀 다운로드", class = "btn-info", style = "margin-top: 10px;")
                          )
                      )
               )
             )
    ),
    tabPanel("데이터 검증",
             fluidRow(
               column(12,
                      h4("시뮬레이션 상세 데이터 (Wide Format)"),
                      rHandsontableOutput("validation_table")
               )
             )
    )
  )
)

# 서버 로직 정의
server <- function(input, output, session) {
  
  # --- 1. DB 연결 및 데이터 로드 ---
  db_data <- reactiveValues(
    customer_stock = NULL, 
    daily_requirements = NULL,
    our_stock = NULL,
    today_delivery_plan = NULL,
    master_materials = NULL
  )
  
  # 앱 시작 시 데이터 로드
  tryCatch({
    # 1.1 MySQL 연결 및 데이터 로드
    mysql_con <- dbConnect(MySQL(), user="seokgyun", password="1q2w3e4r", dbname="GSCP", host="172.16.220.32", port=3306)
    session$onSessionEnded(function() { dbDisconnect(mysql_con) })
    
    # 'delivery_plans' 테이블 자동 생성
    if (!dbExistsTable(mysql_con, "delivery_plans")) {
        dbExecute(mysql_con, "
            CREATE TABLE delivery_plans (
                id INT AUTO_INCREMENT PRIMARY KEY,
                material VARCHAR(255) NOT NULL,
                delivery_date DATE NOT NULL,
                quantity INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY mat_date_uniq (material, delivery_date)
            )
        ")
        message("Table 'delivery_plans' created successfully.")
    }
    
    db_data$customer_stock <- dbGetQuery(mysql_con, "SELECT * FROM current_stock WHERE capture_date = (SELECT MAX(capture_date) FROM current_stock WHERE capture_date < (SELECT MAX(capture_date) FROM current_stock))")
    db_data$daily_requirements <- dbGetQuery(mysql_con, "SELECT * FROM daily_requirements WHERE release_date = (SELECT MAX(release_date) FROM daily_requirements)")
    db_data$delivery_plans <- dbGetQuery(mysql_con, "SELECT material, delivery_date, quantity FROM delivery_plans")
    
    # 1.2 MS SQL Server 연결 및 데이터 로드
    mssql_con <- dbConnect(odbc(), .connection_string = "Driver={ODBC Driver 17 for SQL Server};Server=172.16.220.3;Database=SAG;Uid=seokgyun;Pwd=1q2w3e4r;")
    session$onSessionEnded(function() { dbDisconnect(mssql_con) })
    
    db_data$our_stock <- dbGetQuery(mssql_con, "SELECT ITMNO, SUM(JQTY) AS RackStock FROM SAG.dbo.MAT_ITMBLPFSUB WHERE WARHS = 'AA' AND JQTY > 0 GROUP BY ITMNO")
    db_data$pallet_qty <- dbGetQuery(mssql_con, "SELECT ITMNO, PLT_QTY FROM SAG.dbo.BAS_ITMSTPF WHERE PUM_CD = 'A' and ACT_GB = 'A'")
    
    today_date_str <- format(Sys.Date(), "%Y%m%d")
    today_delivery_query <- sprintf("
        SELECT 
            A.ITMNO AS material, 
            SUM(A.QTY) AS quantity
        FROM 
            SAG.dbo.MAT_LOCA_ALM A
        WHERE 
            A.GUBN = 'B' 
            AND LEFT(A.LOCAT, 8) = '%s'
            AND A.STS <> 'D'
        GROUP BY 
            A.ITMNO", today_date_str)
    db_data$today_delivery_plan <- dbGetQuery(mssql_con, today_delivery_query)
    
    db_data$master_materials <- dbGetQuery(mssql_con, "SELECT ITMNO, ITM_NM, PLT_QTY, LRGB, CHJ_CD FROM SAG.dbo.BAS_ITMSTPF WHERE PUM_CD = 'A' and ACT_GB = 'A' ORDER BY CHJ_CD, ITMNO") %>%
      mutate(ITMNO = trimws(ITMNO)) # 공백 제거
    
    message("모든 데이터베이스에서 데이터를 성공적으로 가져왔습니다.")
    
  }, error = function(e) {
    showModal(modalDialog(title = "DB 연결 오류", paste("데이터베이스에 연결할 수 없습니다:", e$message)))
  })
  
  # --- 2. 계산 로직 ---
  
  # 2.1 전체 재고 소진 시뮬레이션 데이터 (모든 품번)
  simulation_data <- reactive({
    req(db_data$master_materials, db_data$customer_stock, db_data$daily_requirements, db_data$delivery_plans, db_data$today_delivery_plan)
    
    # 고객사 재고만 초기 재고로 사용 (plant_stock 컬럼 참조)
    total_initial_stock <- db_data$customer_stock %>%
      mutate(material = trimws(material)) %>% # 공백 제거
      select(material, total_stock = plant_stock) %>% # current_stock 대신 plant_stock 사용
      mutate(total_stock = ifelse(is.na(total_stock), 0, total_stock))

    # 일일 소요량 집계
    daily_req_processed <- db_data$daily_requirements %>%
      mutate(material_number = trimws(material_number)) %>% # 공백 제거
      mutate(requirement_date = as.Date(requirement_date)) %>%
      group_by(material_number, requirement_date) %>%
      summarise(req_qty = sum(requirement_value, na.rm = TRUE), .groups = 'drop') %>%
      rename(material = material_number)

    # 납품 계획 전처리
    delivery_plans_processed <- db_data$delivery_plans %>%
        mutate(material = trimws(material)) %>% # 공백 제거
        mutate(delivery_date = as.Date(delivery_date)) %>%
        rename(plan_qty = quantity, requirement_date = delivery_date)

    # 오늘자 납품 계획은 별도 쿼리 결과로 대체
    today_plan_from_query <- db_data$today_delivery_plan %>%
        mutate(requirement_date = Sys.Date(),
               material = trimws(material)) %>%
        select(material, requirement_date, plan_qty = quantity)

    # 기존 계획에서 오늘 날짜를 제외하고, 위에서 만든 오늘자 계획을 합침
    delivery_plans_combined <- delivery_plans_processed %>%
        filter(requirement_date != Sys.Date()) %>%
        bind_rows(today_plan_from_query)

    # 소요량과 납품 계획 병합
    daily_events <- full_join(
        daily_req_processed,
        delivery_plans_combined, # 수정된 납품 계획 사용
        by = c("material", "requirement_date")
      ) %>%
      mutate(
        req_qty = ifelse(is.na(req_qty), 0, req_qty),
        plan_qty = ifelse(is.na(plan_qty), 0, plan_qty)
      )

    # --- DEBUGGING START ---
    cat("\n\n--- DEBUGGING simulation_data ---\n")
    cat("\n>>> 1. master_materials:\n")
    print(str(db_data$master_materials))
    print(head(db_data$master_materials))
    
    cat("\n>>> 2. daily_events:\n")
    print(str(daily_events))
    print(head(daily_events))
    
    cat("\n>>> 3. total_initial_stock:\n")
    print(str(total_initial_stock))
    print(head(total_initial_stock))
    cat("\n--- END DEBUGGING ---\n\n")
    # --- DEBUGGING END ---

    # 재고 시뮬레이션 재계산 (D+0부터 새로 시작)
    depletion_simulation <- db_data$master_materials %>%
      select(material = ITMNO) %>% # 모든 품번 리스트에서 시작
      # 모든 품번과 모든 날짜의 조합을 만듬 (전체 그리드)
      tidyr::crossing(requirement_date = seq.Date(from = Sys.Date(), to = Sys.Date() + 14, by = "day")) %>%
      # 이벤트(소요량, 납품계획) 데이터 결합
      left_join(daily_events, by = c("material", "requirement_date")) %>%
      # DB 초기재고 데이터 결합
      left_join(total_initial_stock, by = "material") %>%
      # NA값들을 0으로 처리
      mutate(
        req_qty = ifelse(is.na(req_qty), 0, req_qty),
        plan_qty = ifelse(is.na(plan_qty), 0, plan_qty),
        total_stock = ifelse(is.na(total_stock), 0, total_stock)
      ) %>%
      group_by(material) %>%
      arrange(requirement_date) %>%
      mutate(
        net_change = plan_qty - req_qty,
        # cumsum을 D+0부터 새로 시작. total_stock이 D+0의 기초재고 역할을 함.
        projected_stock = total_stock[1] + cumsum(net_change),
        기초재고 = lag(projected_stock, default = total_stock[1])
      ) %>%
      ungroup() %>%
      select(
        품번 = material,
        소요날짜 = requirement_date,
        DB초기재고 = total_stock,
        기초재고,
        일일소요량 = req_qty,
        납품계획 = plan_qty,
        예상재고 = projected_stock
      )
      
    return(depletion_simulation)
  })
  
  # 2.2 품번 선택 로직 (드롭다운 + 버튼)
  material_list_rv <- reactiveVal(character(0))

  observe({
    req(db_data$master_materials)
    new_material_list <- db_data$master_materials$ITMNO
    
    material_list_rv(new_material_list)
    
    current_selected <- isolate(input$sim_material_selector)
    if (!is.null(current_selected) && current_selected %in% new_material_list) {
      updateSelectInput(session, "sim_material_selector", choices = new_material_list, selected = current_selected)
    } else if (length(new_material_list) > 0) {
      updateSelectInput(session, "sim_material_selector", choices = new_material_list, selected = new_material_list[1])
    } else {
      updateSelectInput(session, "sim_material_selector", choices = character(0))
    }
  })

  observeEvent(input$next_material, {
    current_list <- material_list_rv()
    req(length(current_list) > 1, input$sim_material_selector)
    
    current_index <- which(current_list == input$sim_material_selector)
    next_index <- if (current_index == length(current_list)) 1 else current_index + 1
    
    updateSelectInput(session, "sim_material_selector", selected = current_list[next_index])
  })

  observeEvent(input$prev_material, {
    current_list <- material_list_rv()
    req(length(current_list) > 1, input$sim_material_selector)
    
    current_index <- which(current_list == input$sim_material_selector)
    prev_index <- if (current_index == 1) length(current_list) else current_index - 1
    
    updateSelectInput(session, "sim_material_selector", selected = current_list[prev_index])
  })
  
  observeEvent(input$first_material, {
    current_list <- material_list_rv()
    req(length(current_list) > 0)
    updateSelectInput(session, "sim_material_selector", selected = current_list[1])
  })

  observeEvent(input$last_material, {
    current_list <- material_list_rv()
    req(length(current_list) > 0)
    updateSelectInput(session, "sim_material_selector", selected = current_list[length(current_list)])
  })
  
  # 2.3 선택된 품번의 데이터만 필터링
  filtered_simulation_data <- reactive({
    req(simulation_data(), input$sim_material_selector)
    simulation_data() %>%
      filter(품번 == input$sim_material_selector)
  })
  
  # 안전 재고 계산 로직
  safety_stock_ea <- reactive({
    req(input$sim_material_selector, db_data$daily_requirements, db_data$pallet_qty)
    
    material_code <- trimws(input$sim_material_selector)
    
    # 1. 향후 10일간의 평균 소요량 계산
    future_req_10_days <- db_data$daily_requirements %>%
        mutate(requirement_date = as.Date(requirement_date)) %>%
        filter(
            material_number == material_code,
            requirement_date >= Sys.Date(),
            requirement_date <= Sys.Date() + 9
        )
    
    total_req_10_days <- sum(future_req_10_days$requirement_value, na.rm = TRUE)
    
    # 순수히 소요량이 있는 날짜의 개수 계산 (생산일 기준)
    num_production_days <- future_req_10_days %>%
      filter(requirement_value > 0) %>%
      distinct(requirement_date) %>%
      nrow()
      
    avg_daily_req <- if (num_production_days > 0) {
      total_req_10_days / num_production_days
    } else {
      0 # 소요량이 있는 날이 없으면 평균 소요량은 0
    }
    
    # 2. 팔레트당 수량 가져오기
    pallet_info <- db_data$pallet_qty %>% 
      mutate(ITMNO = trimws(ITMNO)) %>% 
      filter(ITMNO == material_code)
    pallet_qty_per_unit <- if (nrow(pallet_info) > 0 && pallet_info$PLT_QTY[1] > 0) pallet_info$PLT_QTY[1] else 1
    
    # 3. 안전 재고 계산 (팔레트 단위로 올림)
    safety_stock_pallets <- ceiling(avg_daily_req / pallet_qty_per_unit)
    safety_stock_final_ea <- safety_stock_pallets * pallet_qty_per_unit
    
    return(safety_stock_final_ea)
  })
  
  # --- 데이터 기준 시점 표시 로직 ---
  
  # 데이터 기준 시점 UI 렌더링
  output$data_timestamps <- renderUI({
    req(release_date_val(), stock_capture_time_val())
    
    tagList(
      tags$hr(style = "margin-top: 10px; margin-bottom: 10px;"),
      tags$div(
        style = "font-size: 11px; color: #555; padding: 5px; border: 1px solid #eee; border-radius: 5px; background-color: #f9f9f9;",
        tags$strong("데이터 기준 시점"),
        tags$br(),
        paste("소요량:", release_date_val()),
        tags$br(),
        paste("재고:", stock_capture_time_val()),
        tags$br(),
        tags$br(), # Add an extra line break for spacing
        tags$span(style = "font-size: 10px; color: #888;", "데이터 출처: GSCP 웹사이트 제공 엑셀파일")
      )
    )
  })
  
  # 소요량 기준일 (release_date)
  release_date_val <- reactive({
    req(db_data$daily_requirements)
    release_date <- db_data$daily_requirements$release_date[1]
    # release_date는 날짜만 포함할 가능성이 높음
    format(as.Date(release_date), "%Y-%m-%d")
  })

  # 재고 기준일 (created_at), UTC -> KST 변환
  stock_capture_time_val <- reactive({
    req(db_data$customer_stock, "created_at" %in% names(db_data$customer_stock))
    
    # created_at이 POSIXct가 아닐 수 있으므로 UTC로 해석하여 변환
    created_at_posix <- as.POSIXct(db_data$customer_stock$created_at, tz = "UTC")
    
    # 가장 최신 시간 선택
    latest_utc_time <- max(created_at_posix, na.rm = TRUE)
    
    # KST로 변환하여 포맷 지정
    format(latest_utc_time, "%Y-%m-%d %H:%M", tz = "America/New_York")
  })
  
# plan_data_rv: 편집 가능한 테이블의 데이터를 관리하는 reactiveVal
plan_data_rv <- reactiveVal(NULL)

# 품번이 변경될 때 테이블 데이터를 초기화/재계산하는 옵저버
observeEvent(filtered_simulation_data(), {
    sim_data_filtered <- filtered_simulation_data()
    req(sim_data_filtered, nrow(sim_data_filtered) > 0, db_data$pallet_qty)

    material_code <- trimws(sim_data_filtered$품번[1])
    pallet_info <- db_data$pallet_qty %>% 
      mutate(ITMNO = trimws(ITMNO)) %>% 
      filter(ITMNO == material_code)
    pallet_qty_per_unit <- if (nrow(pallet_info) > 0 && pallet_info$PLT_QTY[1] > 0) pallet_info$PLT_QTY[1] else 1

    plot_start_date <- Sys.Date()
    plot_end_date <- plot_start_date + 14
    
    # D+0의 기초재고는 DB에서 가져온 최신 재고값(DB초기재고)을 직접 사용
    initial_stock <- if (nrow(sim_data_filtered) > 0) sim_data_filtered$DB초기재고[1] else 0
    initial_stock <- as.numeric(initial_stock[1]); if (is.na(initial_stock)) initial_stock <- 0

    data_for_period <- tibble(소요날짜 = seq.Date(from = plot_start_date, to = plot_end_date, by = "day")) %>%
      left_join(sim_data_filtered, by = "소요날짜") %>%
      mutate(
        일일소요량 = ifelse(is.na(일일소요량), 0, as.numeric(일일소요량)),
        납품계획 = ifelse(is.na(납품계획), 0, as.numeric(납품계획))
      ) %>%
      arrange(소요날짜) %>%
      mutate(
        납품계획_Pallet = round(납품계획 / pallet_qty_per_unit),
        net_change = 납품계획 - 일일소요량,
        예상재고 = initial_stock + cumsum(net_change)
      )

    df <- data.frame(
      row.names = c("일일소요량 (EA)", "납품계획 (EA)", "예상재고 (EA)", "납품계획 (Pallet)"),
      t(data_for_period[, c("일일소요량", "납품계획", "예상재고", "납품계획_Pallet")])
    )
    date_sequence <- seq.Date(from = plot_start_date, to = plot_end_date, by = "day")
    colnames(df) <- paste0("D+", 0:14, "\n(", format(date_sequence, "%m/%d"), ")")
    
    plan_data_rv(df)
}, ignoreNULL = FALSE)

# 사용자가 테이블을 편집할 때 실시간으로 재계산하는 옵저버
observeEvent(input$plan_handsontable, {
    current_data <- isolate(plan_data_rv())
    edited_data <- hot_to_r(input$plan_handsontable)
    req(current_data, edited_data)

    current_pallet_vec <- as.numeric(unlist(current_data["납품계획 (Pallet)",]))
    edited_pallet_vec <- as.numeric(unlist(edited_data["납품계획 (Pallet)",]))

    # 사용자가 '납품계획 (Pallet)' 행을 수정했을 때만 재계산 실행 (값 비교)
    if (!isTRUE(all.equal(current_pallet_vec, edited_pallet_vec))) {
        material_code <- trimws(isolate(input$sim_material_selector))
        pallet_info <- db_data$pallet_qty %>% 
          mutate(ITMNO = trimws(ITMNO)) %>% 
          filter(ITMNO == material_code)
        pallet_qty_per_unit <- if (nrow(pallet_info) > 0 && pallet_info$PLT_QTY[1] > 0) pallet_info$PLT_QTY[1] else 1
        
        # 1. 팔레트 수량을 EA 수량으로 변환
        edited_data["납품계획 (EA)",] <- edited_pallet_vec * pallet_qty_per_unit
        
        # 일일 소요량이 없는 날짜에는 납품 계획을 0으로 강제
        req_ea_vec_from_current <- as.numeric(unlist(current_data["일일소요량 (EA)",]))
        zero_req_cols <- which(req_ea_vec_from_current == 0)
        
        if (length(zero_req_cols) > 0) {
          edited_data["납품계획 (EA)", zero_req_cols] <- 0
          edited_data["납품계획 (Pallet)", zero_req_cols] <- 0
        }
        
        # 2. 예상 재고를 재계산하기 위한 초기 재고 값 가져오기
        sim_data_filtered <- isolate(filtered_simulation_data())
        # D+0의 기초재고는 DB에서 가져온 최신 재고값(DB초기재고)을 직접 사용
        initial_stock <- if (nrow(sim_data_filtered) > 0) sim_data_filtered$DB초기재고[1] else 0
        initial_stock <- as.numeric(initial_stock[1]); if (is.na(initial_stock)) initial_stock <- 0
        
        # 3. 벡터 연산을 위해 데이터 추출 및 예상재고 재계산
        plan_ea_vec <- as.numeric(unlist(edited_data["납품계획 (EA)",]))
        req_ea_vec <- as.numeric(unlist(edited_data["일일소요량 (EA)",]))
        
        net_change_vec <- plan_ea_vec - req_ea_vec
        edited_data["예상재고 (EA)",] <- initial_stock + cumsum(net_change_vec)
        
        # 4. 재계산된 데이터로 reactiveVal 업데이트
        plan_data_rv(edited_data)
    }
})

  # 2.5 rhandsontable 렌더링
  output$plan_handsontable <- renderRHandsontable({
    df <- plan_data_rv()
    req(df)

    # 일일소요량이 0인 컬럼을 숨기기 위한 로직
    daily_req_row <- df["일일소요량 (EA)", ]
    # D+0 (첫 번째 컬럼)을 제외하고 소요량이 0인 컬럼의 인덱스를 찾음
    cols_to_hide <- which(daily_req_row == 0)
    cols_to_hide <- setdiff(cols_to_hide, 1) # 1번 컬럼(D+0)은 숨기지 않음
    
    # 입력 행을 하이라이트하기 위한 JavaScript 렌더러
    renderer <- "
      function(instance, td, row, col, prop, value, cellProperties) {
        Handsontable.renderers.NumericRenderer.apply(this, arguments);
        if (row == 3) { // 0-indexed, so 4th row is index 3
          td.style.background = '#F0F8FF';
          td.style.fontWeight = 'bold';
        }
      }
    "
    
    hot_table <- rhandsontable(df, stretchH = "all", rowHeaderWidth = 120) %>%
      # 편집 불가능 행들을 읽기 전용으로 설정
      hot_row(c(1, 2, 3), readOnly = TRUE) %>%
      # D+0 납품계획은 수정 불가
      hot_cell(4, 1, readOnly = TRUE) %>%
      # 모든 열을 정수 형식으로 표시하고, 입력 행을 하이라이트
      hot_cols(format = "0", renderer = renderer)

    # 소요량 없는 컬럼 숨기기
    if (length(cols_to_hide) > 0) {
      hot_table <- hot_table %>% hot_col(cols_to_hide, width = 0.1)
    }
    
    hot_table
  })
  
  # 납품 계획 자동 생성
  observeEvent(input$auto_fill_plan, {
    req(plan_data_rv(), safety_stock_ea(), input$sim_material_selector)
    
    # 1. 필요한 데이터 가져오기
    current_plan <- plan_data_rv()
    safety_stock <- safety_stock_ea()
    material_code <- trimws(input$sim_material_selector)
    
    # 팔레트당 수량
    pallet_info <- db_data$pallet_qty %>% 
      mutate(ITMNO = trimws(ITMNO)) %>% 
      filter(ITMNO == material_code)
    pallet_qty_per_unit <- if (nrow(pallet_info) > 0 && pallet_info$PLT_QTY[1] > 0) pallet_info$PLT_QTY[1] else 1
    
    # 초기 재고 (D-1 재고)
    sim_data_filtered <- isolate(filtered_simulation_data())
    # D+0의 기초재고는 DB에서 가져온 최신 재고값(DB초기재고)을 직접 사용
    initial_stock <- if (nrow(sim_data_filtered) > 0) sim_data_filtered$DB초기재고[1] else 0
    initial_stock <- as.numeric(initial_stock[1]); if (is.na(initial_stock)) initial_stock <- 0
    
    # 2. 자동 계획 로직
    req_ea_vec <- as.numeric(unlist(current_plan["일일소요량 (EA)",]))
    new_plan_ea_vec <- numeric(length(req_ea_vec)) # 새 계획을 0으로 초기화
    
    # 날짜별로 반복하며 재고 확인 및 납품 계획 추가
    projected_stock_vec <- numeric(length(req_ea_vec))
    
    # D+0 (i=1)은 자동 생성에서 제외하고, 기존 계획을 그대로 사용
    new_plan_ea_vec[1] <- as.numeric(unlist(current_plan["납품계획 (EA)", 1]))
    projected_stock_vec[1] <- initial_stock + new_plan_ea_vec[1] - req_ea_vec[1]

    # D+1 (i=2)부터 자동 생성 로직 적용
    for (i in 2:length(req_ea_vec)) {
      if (req_ea_vec[i] == 0) { # 일일 소요량이 없으면 납품 계획도 0
        new_plan_ea_vec[i] <- 0
      } else {
        # 이전 날짜의 재고를 가져옴
        stock_before_today <- projected_stock_vec[i-1]
        
        # 현재 날짜의 예상 재고 (납품 추가 전)
        stock_today_no_delivery <- stock_before_today - req_ea_vec[i]
        
        # 만약 재고가 안전재고보다 낮아지면 납품 추가
        if (stock_today_no_delivery < safety_stock) {
          deficit <- safety_stock - stock_today_no_delivery
          pallets_to_add <- ceiling(deficit / pallet_qty_per_unit)
          qty_to_add <- pallets_to_add * pallet_qty_per_unit
          new_plan_ea_vec[i] <- qty_to_add
        } else {
          new_plan_ea_vec[i] <- 0 # 안전재고 이상이면 납품 없음
        }
      }
      # 최종 예상 재고 계산 (새 납품 계획 반영)
      projected_stock_vec[i] <- projected_stock_vec[i-1] + new_plan_ea_vec[i] - req_ea_vec[i]
    }
    
    # 3. plan_data_rv 업데이트
    new_plan_df <- current_plan
    new_plan_df["납품계획 (EA)",] <- new_plan_ea_vec
    new_plan_df["납품계획 (Pallet)",] <- round(new_plan_ea_vec / pallet_qty_per_unit)
    new_plan_df["예상재고 (EA)",] <- projected_stock_vec
    
    plan_data_rv(new_plan_df)
    
    showNotification("납품 계획이 자동 생성되었습니다. 내용을 확인하고 저장하세요.", type = "message")
  })
  
  # 모든 품번 대상 납품계획 자동 생성
  observeEvent(input$auto_fill_all_materials, {
    req(material_list_rv(), db_data$daily_requirements, db_data$customer_stock, db_data$pallet_qty)
    
    all_materials <- material_list_rv()
    all_generated_plans <- list() # 모든 품번의 생성된 계획을 저장할 리스트
    
    withProgress(message = '모든 품번 납품 계획 자동 생성 중...', value = 0, {
      for (k in 1:length(all_materials)) {
        material_code <- all_materials[k]
        incProgress(1/length(all_materials), detail = paste("품번:", material_code))
        
        # 1. 필요한 데이터 가져오기 (각 품번별로)
        # 안전 재고 계산 (safety_stock_ea() 로직 재사용)
        # 이 부분은 safety_stock_ea() reactive를 직접 호출할 수 없으므로 로직을 복사하거나 함수화해야 함
        future_req_10_days <- db_data$daily_requirements %>%
            mutate(requirement_date = as.Date(requirement_date)) %>%
            filter(
                material_number == material_code,
                requirement_date >= Sys.Date(),
                requirement_date <= Sys.Date() + 9
            )
        total_req_10_days <- sum(future_req_10_days$requirement_value, na.rm = TRUE)
        num_production_days <- future_req_10_days %>%
          filter(requirement_value > 0) %>%
          distinct(requirement_date) %>%
          nrow()
        avg_daily_req <- if (num_production_days > 0) {
          total_req_10_days / num_production_days
        } else {
          0
        }
        
        pallet_info <- db_data$pallet_qty %>% 
          mutate(ITMNO = trimws(ITMNO)) %>% 
          filter(ITMNO == material_code)
        pallet_qty_per_unit <- if (nrow(pallet_info) > 0 && pallet_info$PLT_QTY[1] > 0) pallet_info$PLT_QTY[1] else 1
        
        safety_stock <- ceiling(avg_daily_req / pallet_qty_per_unit) * pallet_qty_per_unit
        
        # 초기 재고 (D-1 재고)
        # D+0의 기초재고는 DB에서 가져온 최신 재고값(DB초기재고)을 직접 사용
        sim_data_for_material <- simulation_data() %>% filter(품번 == material_code)
        initial_stock <- if (nrow(sim_data_for_material) > 0) sim_data_for_material$DB초기재고[1] else 0
        initial_stock <- as.numeric(initial_stock[1]); if (is.na(initial_stock)) initial_stock <- 0
        
        # 2. 자동 계획 로직 (전체 D+0 ~ D+14 기간에 대해 계산)
        full_sim_data_for_material_period <- sim_data_for_material %>%
          filter(소요날짜 >= Sys.Date(), 소요날짜 <= Sys.Date() + 14) %>%
          arrange(소요날짜)

        full_req_ea_vec <- full_sim_data_for_material_period$일일소요량
        full_new_plan_ea_vec <- numeric(length(full_req_ea_vec))
        full_projected_stock_vec <- numeric(length(full_req_ea_vec))

        # D+0 (오늘) 납품은 자동 입력에서 제외
        stock_before_today_d0 <- initial_stock
        full_projected_stock_vec[1] <- stock_before_today_d0 - full_req_ea_vec[1]
        full_new_plan_ea_vec[1] <- 0

        # D+1부터 D+14까지 자동 계획 로직 적용
        for (i in 2:length(full_req_ea_vec)) {
          stock_before_today <- full_projected_stock_vec[i-1]
          stock_today_no_delivery <- stock_before_today - full_req_ea_vec[i]
          
          if (full_req_ea_vec[i] == 0) {
            full_new_plan_ea_vec[i] <- 0
          } else {
            if (stock_today_no_delivery < safety_stock) {
              deficit <- safety_stock - stock_today_no_delivery
              pallets_to_add <- ceiling(deficit / pallet_qty_per_unit)
              qty_to_add <- pallets_to_add * pallet_qty_per_unit
              full_new_plan_ea_vec[i] <- qty_to_add
            } else {
              full_new_plan_ea_vec[i] <- 0
            }
          }
          full_projected_stock_vec[i] <- stock_before_today + full_new_plan_ea_vec[i] - full_req_ea_vec[i]
        }
        
        # 생성된 계획을 리스트에 추가
        generated_plan_df <- tibble(
          material = material_code,
          delivery_date = full_sim_data_for_material_period$소요날짜,
          quantity = full_new_plan_ea_vec
        )
        all_generated_plans[[k]] <- generated_plan_df
      }
    })
    
    # 모든 품번의 계획을 하나의 데이터프레임으로 결합
    final_plans_to_save <- bind_rows(all_generated_plans) %>%
      filter(quantity > 0) # 0인 계획은 저장하지 않음 (DB에 0으로 업데이트하는 대신)
    
    # DB에 저장 (기존 계획 삭제 후 새로 삽입)
    mysql_con <- dbConnect(MySQL(), user="seokgyun", password="1q2w3e4r", dbname="GSCP", host="172.16.220.32", port=3306)
    on.exit(dbDisconnect(mysql_con))
    
    # 기존 D+0 ~ D+14 기간의 계획 삭제
    dbExecute(mysql_con, sprintf(
      "DELETE FROM delivery_plans WHERE delivery_date >= %s AND delivery_date <= %s",
      dbQuoteString(mysql_con, as.character(Sys.Date())),
      dbQuoteString(mysql_con, as.character(Sys.Date() + 14))
    ))
    
    if (nrow(final_plans_to_save) > 0) {
      dbWriteTable(mysql_con, "delivery_plans", final_plans_to_save, append = TRUE, row.names = FALSE)
    }
    
    showNotification("모든 품번의 납품 계획이 자동 생성 및 저장되었습니다.", type = "message", duration = 5)
    
    # DB에서 데이터 다시 로드하여 전체 앱에 반영
    db_data$delivery_plans <- dbGetQuery(mysql_con, "SELECT material, delivery_date, quantity FROM delivery_plans")
  })
  
  # 2.6 납품 계획 저장
  observeEvent(input$save_plan, {
    req(plan_data_rv(), input$sim_material_selector)
    
    final_df <- plan_data_rv()
    plan_to_save_ea <- final_df["납품계획 (EA)", ]
    material_code <- input$sim_material_selector
    
    # D+1부터 저장 (i=1은 D+0이므로 제외)
    for (i in 2:ncol(plan_to_save_ea)) {
      day_offset <- i - 1
      delivery_date <- Sys.Date() + day_offset
      quantity_to_save <- as.numeric(plan_to_save_ea[[i]])
      
      # 수량이 0 이상일 때만 DB에 저장/업데이트 (0이면 삭제도 고려할 수 있으나, 여기서는 0으로 업데이트)
      query <- sprintf(
        "INSERT INTO delivery_plans (material, delivery_date, quantity) VALUES (%s, %s, %d) ON DUPLICATE KEY UPDATE quantity = %d",
        dbQuoteString(mysql_con, material_code),
        dbQuoteString(mysql_con, as.character(delivery_date)),
        quantity_to_save,
        quantity_to_save
      )
      dbExecute(mysql_con, query)
    }
    
    showNotification("납품 계획이 저장되었습니다.", type = "message", duration = 3)
    
    # DB에서 데이터 다시 로드하여 전체 앱에 반영
    db_data$delivery_plans <- dbGetQuery(mysql_con, "SELECT material, delivery_date, quantity FROM delivery_plans")
  })

  # 납품 계획 초기화 (D+1 ~ D+14)
  observeEvent(input$reset_plan, {
    req(input$sim_material_selector)
    
    material_code <- input$sim_material_selector
    
    showModal(modalDialog(
      title = "납품 계획 초기화 확인",
      paste("정말로", material_code, "품번의 D+1 이후 납품 계획을 모두 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."),
      footer = tagList(
        modalButton("취소"),
        actionButton("confirm_reset", "확인", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_reset, {
    removeModal()
    
    req(input$sim_material_selector)
    material_code <- isolate(input$sim_material_selector)
    
    start_date <- Sys.Date() + 1
    end_date <- Sys.Date() + 14
    
    query <- sprintf(
      "DELETE FROM delivery_plans WHERE material = %s AND delivery_date >= %s AND delivery_date <= %s",
      dbQuoteString(mysql_con, material_code),
      dbQuoteString(mysql_con, as.character(start_date)),
      dbQuoteString(mysql_con, as.character(end_date))
    )
    
    tryCatch({
      dbExecute(mysql_con, query)
      
      # DB에서 데이터 다시 로드하여 전체 앱에 반영
      db_data$delivery_plans <- dbGetQuery(mysql_con, "SELECT material, delivery_date, quantity FROM delivery_plans")
      
      showNotification(paste(material_code, "품번의 납품 계획이 초기화되었습니다."), type = "message")
    }, error = function(e) {
      showNotification(paste("계획 초기화 중 오류 발생:", e$message), type = "error")
    })
  })

  # --- 3. UI 렌더링 ---
  
  # 3.1 상세 뷰 (그래프, 테이블)에 사용될 데이터
  data_for_details_view <- reactive({
    req(filtered_simulation_data())
    
    all_data <- filtered_simulation_data()
    
    # 오늘 날짜 이후이면서 일일 소요량이 0보다 큰 데이터만 표시하도록 필터링
    display_data <- all_data %>%
      filter(소요날짜 >= Sys.Date(), 일일소요량 > 0)
      
    return(display_data)
  })
  
  # 3.2 시뮬레이션 탭
  output$simulation_plot <- renderPlot({
    req(data_for_details_view(), safety_stock_ea())
    
    plot_data <- data_for_details_view()
    
    if (nrow(plot_data) == 0) return(NULL) # 데이터 없으면 그래프 안그림
    
    # 날짜 축 범위 설정
    plot_start_date <- min(plot_data$소요날짜)
    plot_end_date <- plot_start_date + 14
    
    # 그래프에 사용할 데이터 필터링 (15일치만)
    plot_data <- plot_data %>%
      filter(소요날짜 >= plot_start_date, 소요날짜 <= plot_end_date)
      
    # 막대 그래프를 위한 데이터 재구성 (pivot_longer)
    plot_data_long <- plot_data %>%
        select(소요날짜, 일일소요량, 납품계획) %>%
        tidyr::pivot_longer(cols = c(일일소요량, 납품계획), names_to = "type", values_to = "value") # 0인 막대도 포함하여 너비 일관성 유지

    # Y축 범위 계산
    y_max <- max(
        max(plot_data$예상재고, na.rm = TRUE), 
        max(plot_data_long$value, na.rm = TRUE)
    ) * 1.1
    y_min <- min(
        0, 
        min(plot_data$예상재고, na.rm = TRUE)
    )

    ggplot() +
      # 일일소요량과 납품계획을 막대 그래프로 표시
      geom_bar(data = plot_data_long, aes(x = 소요날짜, y = value, fill = type), stat = "identity", width = 0.6, position = "dodge") +
      
      # 예상재고를 라인 그래프로 표시
      geom_line(data = plot_data, aes(x = 소요날짜, y = 예상재고, color = "예상재고"), linewidth = 1.2) +
      geom_point(data = plot_data, aes(x = 소요날짜, y = 예상재고), color = "#0072B2", size = 3) +
      
      # 기준선 (0, 안전재고)
      geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
      geom_hline(yintercept = safety_stock_ea(), linetype = "dashed", color = "darkorange", linewidth = 1) +
      
      # 안전재고 라벨
      annotate("text", x = plot_start_date, y = safety_stock_ea(), 
               label = paste("안전재고:", format(round(safety_stock_ea()), big.mark = ",")), 
               hjust = -0.1, vjust = -0.5, color = "darkorange", size = 5, family = "nanumgothic", fontface = "bold") +
      
      # 그래프 색상 및 범례 설정
      scale_fill_manual(name = "구분", values = c("일일소요량" = "#D55E00", "납품계획" = "#56B4E9")) +
      scale_color_manual(name = NULL, values = c("예상재고" = "#0072B2")) +
      
      # 라벨 및 제목
      labs(
        title = paste(input$sim_material_selector, "예상 재고 및 소요/납품 추이"),
        x = NULL, # "날짜"
        y = "수량 (EA)"
      ) +
      
      # 축 및 테마 설정
      scale_y_continuous(labels = scales::comma) +
      scale_x_date(date_breaks = "1 day", date_labels = "%m/%d") +
      coord_cartesian(
          xlim = c(plot_start_date - 0.5, plot_end_date + 0.5), 
          ylim = c(y_min, y_max)
      ) +
      theme_minimal(base_family = "nanumgothic") +
      theme(
          plot.title = element_text(size = 20, face = "bold"),
          legend.position = "top",
          legend.title = element_text(face = "bold", size = 12),
          legend.text = element_text(size = 11),
          axis.text.x = element_text(size = 10),
          axis.text.y = element_text(size = 10),
          axis.title.y = element_text(size = 12, face = "bold")
      )
  })
  
  output$simulation_table <- renderDT({
    datatable(data_for_details_view(), options = list(pageLength = 25), rownames = FALSE)
  })
  
  
  # --- 4. 종합 납품 계획 탭 ---
  
  # 4.1 종합 납품 계획 데이터 생성 (EA 단위)
  aggregated_plan_data <- reactive({
    req(db_data$delivery_plans, db_data$pallet_qty, db_data$daily_requirements, db_data$customer_stock)
    
    start_date <- Sys.Date()
    end_date <- start_date + 14
    
    # 1. Identify dates with any requirement
    dates_with_any_req <- db_data$daily_requirements %>%
      mutate(requirement_date = as.Date(requirement_date)) %>%
      filter(requirement_date >= start_date, requirement_date <= end_date, requirement_value > 0) %>%
      distinct(requirement_date) %>%
      pull(requirement_date) %>%
      sort()
      
    if(length(dates_with_any_req) == 0) {
      return(tibble(품번 = "향후 15일간 소요량이 있는 날짜가 없습니다.", 품명 = ""))
    }

    # 2. Get valid items from master list
    valid_items <- db_data$master_materials %>%
        mutate(ITMNO = trimws(ITMNO)) %>%
        distinct(ITMNO, CHJ_CD) %>% # Include CHJ_CD
        rename(품번 = ITMNO)

    # 3. Get plan data
    plan_data <- db_data$delivery_plans %>%
        mutate(delivery_date = as.Date(delivery_date),
               material = trimws(material)) %>%
        filter(delivery_date %in% dates_with_any_req)

    # 4. Join and pivot
    aggregated_data <- valid_items %>%
        left_join(plan_data, by = c("품번" = "material")) %>%
        tidyr::pivot_wider(
            id_cols = 품번,
            names_from = delivery_date,
            values_from = quantity,
            values_fill = 0
        )
        
    # 5. Add and format columns
    all_cols_dates <- as.character(dates_with_any_req)
    missing_cols <- setdiff(all_cols_dates, names(aggregated_data))
    if(length(missing_cols) > 0) {
      aggregated_data[missing_cols] <- 0
    }
    aggregated_data <- aggregated_data %>% select(품번, all_of(all_cols_dates))
    
    # 6. Add descriptions
    item_descriptions <- db_data$customer_stock %>%
        select(품번 = material, 품명 = description) %>%
        mutate(품번 = trimws(품번)) %>%
        distinct(품번, .keep_all = TRUE)
        
    final_data <- aggregated_data %>%
        left_join(item_descriptions, by = "품번") %>%
        mutate(품명 = ifelse(is.na(품명), "", 품명)) %>%
        left_join(valid_items %>% select(품번, CHJ_CD), by = "품번") %>%
        arrange(CHJ_CD, 품번) %>%
        select(품번, 품명, everything()) %>% # 컬럼 순서 재정렬
        select(-CHJ_CD)

    # 7. Format column names
    formatted_colnames <- paste0("D+", as.numeric(dates_with_any_req - Sys.Date()), "\n(", format(dates_with_any_req, "%m/%d"), ")")
    names(final_data)[-c(1,2)] <- formatted_colnames
        
    return(final_data)
  })
  
  # --- 5. 데이터 검증 탭 로직 ---
  
  # 5.1 데이터 검증을 위한 Wide Format 데이터 생성
  validation_data_wide <- reactive({
    req(simulation_data())
    
    # 1. 모든 품번의 모든 날짜 데이터 준비
    df_all_data <- simulation_data() %>%
      select(품번, 소요날짜, 기초재고, 일일소요량, 납품계획) %>%
      left_join(db_data$master_materials %>% select(ITMNO, CHJ_CD) %>% rename(품번 = ITMNO), by = "품번")
      
    # 2. 일일 소요량이 있는 날짜만 식별 (D+0은 항상 포함)
    dates_with_any_req <- df_all_data %>%
      filter(일일소요량 > 0) %>%
      distinct(소요날짜) %>%
      pull(소요날짜)
      
    # 3. 식별된 날짜와 품번 컬럼만 포함하도록 데이터 필터링
    df_filtered_dates <- df_all_data %>%
      filter(소요날짜 %in% dates_with_any_req | 소요날짜 == Sys.Date()) # D+0은 소요량과 관계없이 항상 포함
      
    # 4. 데이터가 없으면 빈 테이블 반환
    if (nrow(df_filtered_dates) == 0) return(tibble())
      
    # 5. day_label을 날짜로 변경
    df_pivot <- df_filtered_dates %>%
      mutate(
        date_label = format(소요날짜, "%m/%d")
      ) %>%
      select(품번, date_label, 기초재고, 일일소요량, 납품계획, CHJ_CD)
      
    # wide 포맷으로 변환
    df_wide <- df_pivot %>%
      pivot_longer(
        cols = c(기초재고, 일일소요량, 납품계획),
        names_to = "metric",
        values_to = "value"
      ) %>%
      # 메트릭 이름 축약
      mutate(metric = case_when(
        metric == "기초재고" ~ "기초",
        metric == "일일소요량" ~ "소요",
        metric == "납품계획" ~ "납품",
        TRUE ~ metric
      )) %>%
      pivot_wider(
        names_from = c(date_label, metric),
        values_from = value,
        names_glue = "{date_label} {metric}"
      ) %>%
      arrange(CHJ_CD, 품번) %>%
      select(-CHJ_CD)
      
    return(df_wide)
  })
  
  # 5.2 데이터 검증 테이블 렌더링
  output$validation_table <- renderRHandsontable({
    df <- validation_data_wide()
    req(df)
    
    # 데이터가 없는 경우 빈 테이블 표시
    if (nrow(df) == 0) {
      return(rhandsontable(tibble("표시할 데이터가 없습니다.")))
    }

    hot_table <- rhandsontable(df, stretchH = "all", rowHeader = FALSE) %>%
      hot_col(1, width = 150) %>% # 품번 컬럼 너비 확장
      hot_cols(readOnly = TRUE) %>%
      hot_cols(format = "0")
      
    # 날짜 그룹별로 오른쪽 테두리 추가
    num_metrics <- 3
    num_date_cols <- ncol(df) - 1
    if (num_date_cols > 0) {
      border_cols <- seq(from = 1 + num_metrics, to = 1 + num_date_cols, by = num_metrics)
      hot_table <- hot_table %>% hot_col(border_cols, className = "thick-right-border")
    }
    
    hot_table
  })
  
  # 4.2 종합 납품 계획 엑셀 다운로드
  output$download_aggregated_plan <- downloadHandler(
    filename = function() {
      paste("종합_납품계획_", Sys.Date(), ".xlsx", sep = "")
    },
    content = function(file) {
      writexl::write_xlsx(aggregated_plan_data(), path = file)
    }
  )
  
  # 4.3 종합 납품 계획 테이블 렌더링
  output$aggregated_plan_table <- renderRHandsontable({
    req(aggregated_plan_data())
    rhandsontable(aggregated_plan_data(), readOnly = FALSE, rowHeader = FALSE, stretchH = "all") %>%
      hot_col(1, readOnly = TRUE, width = 80) %>% # 품번 열 너비 조정
      hot_col(2, readOnly = TRUE, width = 150) %>% # 품명 열 너비 조정
      hot_cols(format = "0")
  })
  
  # 4.3 종합 납품 계획 저장
  observeEvent(input$save_aggregated_plan, {
    req(input$aggregated_plan_table)
    
    edited_data <- hot_to_r(input$aggregated_plan_table)
    
    # Convert wide data back to long format for saving
    long_data <- edited_data %>%
      tidyr::pivot_longer(
        cols = -c(품번, 품명),
        names_to = "delivery_date_str",
        values_to = "quantity"
      )
      
    # Save to DB
    for (row in 1:nrow(long_data)) {
      material_code <- trimws(long_data$품번[row])
      quantity_to_save <- as.numeric(long_data$quantity[row])
      
      # Extract date from column name like "D+0\n(11/13)"
      date_str_part <- regmatches(long_data$delivery_date_str[row], regexpr("\\(\\d{2}/\\d{2}\\)", long_data$delivery_date_str[row]))
      date_in_year <- as.Date(gsub("[()]", "", date_str_part), format = "%m/%d")
      
      # Handle year change for dates like "01/05" in December
      if (month(date_in_year) < month(Sys.Date())) {
        year(date_in_year) <- year(Sys.Date()) + 1
      } else {
        year(date_in_year) <- year(Sys.Date())
      }
      
      query <- sprintf(
        "INSERT INTO delivery_plans (material, delivery_date, quantity) VALUES (%s, %s, %d) ON DUPLICATE KEY UPDATE quantity = %d",
        dbQuoteString(mysql_con, material_code),
        dbQuoteString(mysql_con, as.character(date_in_year)),
        quantity_to_save,
        quantity_to_save
      )
      dbExecute(mysql_con, query)
    }
    
    showNotification("전체 납품 계획이 저장되었습니다.", type = "message", duration = 3)
    
    # Reload data to reflect changes
    db_data$delivery_plans <- dbGetQuery(mysql_con, "SELECT material, delivery_date, quantity FROM delivery_plans")
  })
  
}

# Shiny 앱 실행
shinyApp(ui = ui, server = server, options = list(host = "0.0.0.0", port = 8080))
