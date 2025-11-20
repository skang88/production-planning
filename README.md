# 생산 관리 보조 시스템

## 프로젝트 개요

본 프로젝트는 생산 관리 업무를 보조하기 위한 R Shiny 기반의 웹 애플리케이션입니다. 고객사의 일일 소요량, 현재고, 납품 계획 데이터를 기반으로 예상 재고 추이를 시뮬레이션하고, 적절한 납품 계획을 수립할 수 있도록 지원합니다.

## 주요 기능

-   **종합 납품 계획 관리**: 전체 품번에 대한 납품 계획을 한 화면에서 확인하고 수정할 수 있습니다.
-   **개별 품번 상세 분석**:
    -   특정 품번을 선택하여 예상 재고 추이를 그래프로 시각화합니다.
    -   Pallet 단위로 납품 계획을 수정하고 저장할 수 있습니다.
    -   '납품 계획 자동 생성' 기능으로 안전재고 기반의 계획을 자동으로 제안받을 수 있습니다.
-   **데이터 검증**: 시뮬레이션에 사용된 기초재고, 일일소요량, 납품계획 데이터를 넓은 테이블(Wide Format) 형태로 조회하여 검증할 수 있습니다.
-   **데이터베이스 연동**:
    -   GSCP(MySQL)에서 고객사 재고, 일일 소요량, 납품 계획 데이터를 가져옵니다.
    -   ERP(MS SQL)에서 우리창고 재고, 품번 마스터, 팔레트당 수량 정보를 가져옵니다.

## 기술 스택

-   **언어**: R
-   **프레임워크**: Shiny
-   **주요 R 패키지**: `shiny`, `dplyr`, `DT`, `RMySQL`, `odbc`, `DBI`, `ggplot2`, `rhandsontable` 등
-   **데이터베이스**: MySQL, MS SQL Server

## 설치 및 실행 방법

### 1. R 및 RStudio 설치

-   [R](https://cran.r-project.org/)을 설치합니다.
-   [RStudio Desktop](https://www.rstudio.com/products/rstudio/download/)을 설치합니다.

### 2. 필요한 R 패키지 설치

프로젝트의 `install.R` 파일을 실행하여 필요한 모든 패키지를 한 번에 설치할 수 있습니다. RStudio에서 `install.R` 파일을 열고 `Source` 버튼을 클릭하거나, R 콘솔에서 다음 명령어를 실행하세요.

```R
source("install.R")
```

### 3. 데이터베이스 드라이버 설치

-   **MySQL**: `RMySQL` 패키지가 의존하는 클라이언트 라이브러리가 필요할 수 있습니다.
-   **MS SQL Server**: `odbc` 패키지를 사용하므로, 시스템에 맞는 [ODBC Driver for SQL Server](https://docs.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)를 설치해야 합니다.

### 4. 환경 변수 설정

애플리케이션은 데이터베이스 접속 정보를 환경 변수에서 읽어옵니다. 시스템에 다음 환경 변수를 설정하거나, R 스크립트 실행 전에 `Sys.setenv()` 함수를 사용하여 설정해주세요.

-   `MYSQL_USER`: MySQL 사용자 이름 (기본값: seokgyun)
-   `MYSQL_PWD`: MySQL 비밀번호 (기본값: 1q2w3e4r)
-   `MYSQL_DBNAME`: MySQL 데이터베이스 이름 (기본값: GSCP)
-   `MYSQL_HOST`: MySQL 호스트 주소 (기본값: 172.16.220.32)
-   `MYSQL_PORT`: MySQL 포트 (기본값: 3306)
-   `MSSQL_HOST`: MS SQL 서버 호스트 주소 (기본값: 172.16.220.3)
-   `MSSQL_DBNAME`: MS SQL 데이터베이스 이름 (기본값: SAG)
-   `MSSQL_USER`: MS SQL 사용자 이름 (기본값: seokgyun)
-   `MSSQL_PWD`: MS SQL 비밀번호 (기본값: 1q2w3e4r)

### 5. 애플리케이션 실행

RStudio에서 `app.R` 파일을 열고, 우측 상단의 `Run App` 버튼을 클릭합니다.

## Docker로 실행하기

프로젝트에 포함된 `Dockerfile`을 사용하여 애플리케이션을 컨테이너 환경에서 실행할 수 있습니다.

1.  **Docker 이미지 빌드**: 프로젝트 루트 디렉토리에서 다음 명령어를 실행합니다.

    ```bash
    docker build -t production-planning-app .
    ```

2.  **Docker 컨테이너 실행**: 데이터베이스 접속 정보를 환경 변수로 전달하여 컨테이너를 실행합니다.

    ```bash
    docker run -p 8080:8080 \
      -e MYSQL_USER=your_mysql_user \
      -e MYSQL_PWD=your_mysql_password \
      # ... (다른 모든 환경 변수 추가)
      production-planning-app
    ```

이제 웹 브라우저에서 `http://localhost:8080`으로 접속하여 애플리케이션을 사용할 수 있습니다.
