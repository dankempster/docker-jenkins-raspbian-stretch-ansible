#!/usr/bin/env groovy

def GOSS_RELEASE = "v0.3.6"
def IMAGE_NAME = "dankempster/jenkins-raspbian-stretch-ansible"
def IMAGE_TAG = "build"

pipeline {

  agent {
    label 'raspberrypi'
  }

  stages {

    stage('Build') {
      steps {
        
        // Ensure we have the latest base docker image
        sh "docker pull \$(head -n 1 Dockerfile | cut -d \" \" -f 2)"

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
        
        // Build the image
        sh "docker build -f Dockerfile -t ${IMAGE_NAME}:${IMAGE_TAG} ."
      }
    }

    stage('Tests') {
      steps {
        sh '[ -d bin ] || mkdir bin'
        sh 'rm -fr build/*'
        sh '[ -d build/reports ] || mkdir -p build/reports'
        sh '[ -d build/raw-reports ] || mkdir -p build/raw-reports'

        // See https://github.com/aelsabbahy/goss/releases for release versions
        sh "curl -L https://github.com/aelsabbahy/goss/releases/download/${GOSS_RELEASE}/goss-linux-arm -o ./bin/goss"

        // dgoss docker wrapper (use 'master' for latest version)
        sh "curl -L https://raw.githubusercontent.com/aelsabbahy/goss/${GOSS_RELEASE}/extras/dgoss/dgoss -o ./bin/dgoss"
        
        sh "chmod +rx ./bin/{goss,dgoss}"

        // Run the tests  
        sh """
          export GOSS_PATH=\$(pwd)/bin/goss
          export GOSS_OPTS="--retry-timeout 180s --sleep 10s --format junit"

          ./bin/dgoss run --privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro ${IMAGE_NAME}:${IMAGE_TAG} | \\grep '<' > build/raw-reports/goss-output.txt
        """
      }
      post {
        always {
          sh """
            cd build/raw-reports

            awk '
            FNR==1 {
               path = namex = FILENAME;
               sub(/^.*\\//,   "", namex);
               sub(namex "\$", "", path );
               name = ext  = namex;
               sub(/\\.[^.]*\$/, "", name);
               sub("^" name,   "", ext );
            }
            /<\\?xml / {
               if (out) close(out);
               out = path name (++file) ext ;
               print "Spliting to " out " ...";
            }
            /<\\?xml /,/<\\/testsuite>/ {
               print \$0 > out
            }
            ' goss-output.txt

            mv goss-output\$(ls -l | grep -P goss-output[0-9]+\\.txt | wc -l).txt ../reports/goss-junit.xml
          """

          junit 'build/reports/**/*.xml'
        }
      }
    }

    stage('Ansible Test') {
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

    stage('Publish') {
      when {
        anyOf {
          branch 'develop'
          anyOf {
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
