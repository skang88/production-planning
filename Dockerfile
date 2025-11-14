# rocker/shiny-verse를 기반 이미지로 사용하여 Shiny Server와 tidyverse 관련 패키지를 사전 설치합니다.
FROM rocker/shiny-verse:latest

# 시스템 관리자 권한으로 전환
USER root

# ODBC, MySQL 클라이언트, 한글 폰트 등 시스템 의존성을 설치합니다.
# Microsoft ODBC Driver for SQL Server 설치를 위해 관련 도구를 먼저 설치합니다.
RUN apt-get update && apt-get install -y \
    gnupg \
    curl \
    unixodbc \
    unixodbc-dev \
    libmysqlclient-dev \
    fonts-nanum* \
    && rm -rf /var/lib/apt/lists/*

# Microsoft ODBC Driver for SQL Server를 설치합니다.
# Microsoft의 GPG 키를 추가하고, 패키지 리포지토리를 등록한 후 드라이버를 설치합니다.
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql17

# R 패키지 설치 스크립트를 이미지 안으로 복사합니다.
COPY install.R /tmp/install.R

# 스크립트를 실행하여 필요한 R 패키지들을 설치합니다.
RUN Rscript /tmp/install.R

# Shiny 애플리케이션 파일들을 Shiny Server의 기본 디렉토리로 복사합니다.
COPY app.R /srv/shiny-server/
COPY daily_requirement_heatmap.R /srv/shiny-server/
COPY data_explore.R /srv/shiny-server/
COPY data_import.R /srv/shiny-server/
COPY validate_2hou_plan_and_daily_requirements.R /srv/shiny-server/

# Shiny Server가 사용하는 기본 포트 3838을 노출합니다.
EXPOSE 3838

# 컨테이너 실행 시 Shiny Server를 시작하도록 기본 명령어를 설정합니다.
CMD ["/usr/bin/shiny-server"]
