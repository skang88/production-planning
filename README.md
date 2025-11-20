# Production Planning Assistant System

## Project Overview

This project is an R Shiny-based web application designed to assist with production management tasks. It supports simulating projected inventory trends and establishing appropriate delivery plans based on customer daily requirements, current inventory, and delivery plan data.

## Key Features

-   **Comprehensive Delivery Plan Management**: View and modify delivery plans for all part numbers on a single screen.
-   **Detailed Part Number Analysis**:
    -   Select a specific part number to visualize projected inventory trends using graphs.
    -   Modify and save delivery plans in Pallet units.
    -   Receive automated plan suggestions based on safety stock using the 'Auto-generate Delivery Plan' function.
-   **Data Validation**: Review basic inventory, daily requirements, and delivery plan data used in simulations in a Wide Format table for validation.
-   **Database Integration**:
    -   Fetches customer inventory, daily requirements, and delivery plan data from GSCP (MySQL).
    -   Fetches our warehouse inventory, part number master, and quantity per pallet information from ERP (MS SQL).

## Tech Stack

-   **Language**: R
-   **Framework**: Shiny
-   **Key R Packages**: `shiny`, `dplyr`, `DT`, `RMySQL`, `odbc`, `DBI`, `ggplot2`, `rhandsontable`, etc.
-   **Databases**: MySQL, MS SQL Server

## Setup and Installation

### 1. Install R and RStudio

-   [R](https://cran.r-project.org/)을 설치합니다.
-   [RStudio Desktop](https://www.rstudio.com/products/rstudio/download/)을 설치합니다.

### 2. Install Required R Packages

You can install all necessary packages by running the `install.R` file in the project. Open `install.R` in RStudio and click the `Source` button, or run the following command in the R console:

```R
source("install.R")
```

### 3. Install Database Drivers

-   **MySQL**: Client libraries that `RMySQL` depends on might be required.
-   **MS SQL Server**: Since the `odbc` package is used, you need to install the appropriate [ODBC Driver for SQL Server](https://docs.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server) for your system.

### 4. Configure Environment Variables

The application reads database connection information from environment variables. Please set the following environment variables on your system, or set them using `Sys.setenv()` function before running the R script.

-   `MYSQL_USER`: MySQL username (Default: seokgyun)
-   `MYSQL_PWD`: MySQL password (Default: 1q2w3e4r)
-   `MYSQL_DBNAME`: MySQL database name (Default: GSCP)
-   `MYSQL_HOST`: MySQL host address (Default: 172.16.220.32)
-   `MYSQL_PORT`: MySQL port (Default: 3306)
-   `MSSQL_HOST`: MS SQL Server host address (Default: 172.16.220.3)
-   `MSSQL_DBNAME`: MS SQL database name (Default: SAG)
-   `MSSQL_USER`: MS SQL username (Default: seokgyun)
-   `MSSQL_PWD`: MS SQL password (Default: 1q2w3e4r)

### 5. Run the Application

Open the `app.R` file in RStudio and click the `Run App` button in the upper right corner.

## Running with Docker

You can use the `Dockerfile` included in the project to run the application in a containerized environment.

1.  **Build Docker Image**: Run the following command in the project root directory:

    ```bash
    docker build -t production-planning-app .
    ```

2.  **Run Docker Container**: Pass the database connection information as environment variables when running the container:

    ```bash
    docker run -p 8080:8080 \
      -e MYSQL_USER=your_mysql_user \
      -e MYSQL_PWD=your_mysql_password \
      # ... (add all other environment variables)
      production-planning-app
    ```

You can now access the application by navigating to `http://localhost:8080` in your web browser.