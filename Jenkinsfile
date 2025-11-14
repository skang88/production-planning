// Jenkinsfile
pipeline {
    // Jenkins 에이전트에 Docker가 설치되어 있다고 가정합니다.
    agent any



    stages {
        stage('Checkout') {
            steps {
                // Git 저장소에서 코드를 가져옵니다.
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                // Dockerfile을 사용하여 이미지를 빌드합니다.
                sh 'docker build -t production-planning-app:latest'
            }
        }



        stage('Deploy') {
            steps {
                // Jenkins의 Secret Text Credential을 사용하여 DB 정보를 가져옵니다.
                // Jenkins에서 'MYSQL_HOST', 'MYSQL_USER', 'MYSQL_PWD' 등의 ID로 Secret Text Credential을 생성해야 합니다.
                withCredentials([
                    string(credentialsId: 'MYSQL_HOST', variable: 'MYSQL_HOST_VAR'),
                    string(credentialsId: 'MYSQL_USER', variable: 'MYSQL_USER_VAR'),
                    string(credentialsId: 'MYSQL_PWD', variable: 'MYSQL_PWD_VAR'),
                    string(credentialsId: 'MSSQL_HOST', variable: 'MSSQL_HOST_VAR'),
                    string(credentialsId: 'MSSQL_USER', variable: 'MSSQL_USER_VAR'),
                    string(credentialsId: 'MSSQL_PWD', variable: 'MSSQL_PWD_VAR')
                ]) {
                    // SSH를 통해 배포 서버에 접속하여 Docker 컨테이너를 실행합니다.
                        sh """
                            # 기존 컨테이너가 있으면 중지하고 삭제합니다.
                            docker stop production-planning-app || true
                            docker rm production-planning-app || true



                            # 환경 변수를 주입하여 새 컨테이너를 실행합니다.
                            docker run -d --name production-planning-app -p 3838:3838 \
                                -e MYSQL_HOST="${MYSQL_HOST_VAR}" \
                                -e MYSQL_USER="${MYSQL_USER_VAR}" \
                                -e MYSQL_PWD="${MYSQL_PWD_VAR}" \
                                -e MSSQL_HOST="${MSSQL_HOST_VAR}" \
                                -e MSSQL_USER="${MSSQL_USER_VAR}" \
                                -e MSSQL_PWD="${MSSQL_PWD_VAR}" \
                                production-planning-app:latest
                        """
                }
            }
        }
    }
    

}
