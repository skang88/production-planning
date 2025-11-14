// Jenkinsfile
pipeline {
    // Jenkins 에이전트에 Docker가 설치되어 있다고 가정합니다.
    agent any

    environment {
        // Docker Hub 사용자 이름 또는 레지스트리 주소를 설정합니다.
        DOCKER_REGISTRY = 'your-docker-registry' 
        // Docker Hub 또는 프라이빗 레지스트리의 Credential ID를 설정합니다.
        DOCKER_CREDENTIALS_ID = 'your-docker-credentials-id'
        // 배포 서버의 SSH Credential ID를 설정합니다.
        DEPLOY_SERVER_CREDENTIALS_ID = 'your-deploy-server-credentials'
        // 배포 서버의 주소와 사용자 이름을 설정합니다.
        DEPLOY_SERVER = 'user@your-deploy-server.com'
    }

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

        stage('Push to Docker Registry') {
            steps {
                // Jenkins Credential을 사용하여 Docker 레지스트리에 로그인하고 이미지를 푸시합니다.
                // 이 단계는 Docker 레지스트리를 사용할 경우에만 필요합니다.
                withCredentials([string(credentialsId: DOCKER_CREDENTIALS_ID, variable: 'DOCKER_PASSWORD')]) {
                    sh "echo ${env.DOCKER_PASSWORD} | docker login ${env.DOCKER_REGISTRY} -u your-docker-username --password-stdin"
                    sh "docker tag production-planning-app:latest ${env.DOCKER_REGISTRY}/production-planning-app:latest"
                    sh "docker push ${env.DOCKER_REGISTRY}/production-planning-app:latest"
                }
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
                    withCredentials([sshUserPrivateKey(credentialsId: DEPLOY_SERVER_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY')]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \\
${SSH_KEY} ${env.DEPLOY_SERVER} << 'EOF'
                                # 기존 컨테이너가 있으면 중지하고 삭제합니다.
                                docker stop production-planning-app || true
                                docker rm production-planning-app || true

                                # Docker 레지스트리에서 최신 이미지를 가져옵니다.
                                docker pull ${env.DOCKER_REGISTRY}/production-planning-app:latest

                                # 환경 변수를 주입하여 새 컨테이너를 실행합니다.
                                docker run -d --name production-planning-app -p 3838:3838 \
                                    -e MYSQL_HOST="\\${MYSQL_HOST_VAR}" \
                                    -e MYSQL_USER="\\${MYSQL_USER_VAR}" \
                                    -e MYSQL_PWD="\\${MYSQL_PWD_VAR}" \
                                    -e MSSQL_HOST="\\${MSSQL_HOST_VAR}" \
                                    -e MSSQL_USER="\\${MSSQL_USER_VAR}" \
                                    -e MSSQL_PWD="\\${MSSQL_PWD_VAR}" \
                                    ${env.DOCKER_REGISTRY}/production-planning-app:latest
                            EOF
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            // 빌드 후 정리 작업 (예: Docker 로그아웃)
            sh 'docker logout'
        }
    }
}
