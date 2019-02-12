#!/usr/bin/env groovy

def IMAGE_NAME = "dankempster/jenkins-raspbian-stretch-ansible" 
def IMAGE_TAG = "build"

pipeline {

  agent {
    label 'raspberrypi'
  }

  stages {

    stage('Build') {
      steps {
        // Work out the correct tag to use
        script { 
          if (env.BRANCH_NAME == 'develop') {
            IMAGE_TAG = 'develop'
          }
          else if (env.BRANCH_NAME == 'master') {
            IMAGE_TAG = 'latest'
          }
          else {
            IMAGE_TAG = 'build'
          }
        }
        
        ansiColor('xterm') {
          withAnt(installation: 'System') {
            sh "ant -Dimage.tag=${IMAGE_TAG} build"
          }
        }
      }
    }

    stage('Tests') {
      parallel {
        stage('Goss') {
          steps {
            ansiColor('xterm') {
              withAnt(installation: 'System') {
                sh "ant -Dimage.tag=${IMAGE_TAG} goss-junit"
              }
            }
          }
          post {
            always {
              junit 'build/reports/**/*.xml'
            }
          }
        }

        stage('Ansible\'s Version') {
          steps {
            script {
              CONTAINER_ID = sh(
                script: "docker run --detach --privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro ${IMAGE_NAME}:${IMAGE_TAG}",
                returnStdout: true
              ).trim()
            }
            
            sh "docker exec --tty ${CONTAINER_ID} env TERM=xterm ansible --version"

            sh """
              docker stop ${CONTAINER_ID}
              docker rm ${CONTAINER_ID}
            """
          }
        }
      }
    }

    stage('Publish') {
      parallel {
        stage('Docker Hub') {
          when {
            anyOf {
              branch 'develop'
              allOf {
                expression {
                  currentBuild.result != 'UNSTABLE'
                }
                branch 'master'
              }
            }
          }
          steps {
            withDockerRegistry([credentialsId: "com.docker.hub.dankempster", url: ""]) {
              sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
            }
          }
        }
      }
    }
  }
}
