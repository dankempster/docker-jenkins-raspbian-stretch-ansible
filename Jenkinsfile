#!/usr/bin/env groovy

def GOSS_RELEASE = "v0.3.6"
def IMAGE_NAME = "dankempster/jenkins-raspbian-stretch-ansible"
def SED_IMAGE_NAME = "dankempster\\/jenkins-raspbian-stretch-ansible"
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
      parallel {
        stage('Goss') {
          steps {

            // Prepare build directory
            sh 'rm -fr build/*'
            sh '[ -d build/reports ] || mkdir -p build/reports'
            sh '[ -d build/raw-reports ] || mkdir -p build/raw-reports'

            // Install Goss & dgoss
            sh '[ -d bin ] || mkdir bin'
            // -- See https://github.com/aelsabbahy/goss/releases for release versions
            sh "curl -L https://github.com/aelsabbahy/goss/releases/download/${GOSS_RELEASE}/goss-linux-arm -o ./bin/goss"
            // -- dgoss docker wrapper (use 'master' for latest version)
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
              // The following is required to extract the last junit report
              // from Goss output.
              // This is required because
              //  - goss outputs the junit format to STDOUT, with other output.
              //  - goss prints out junit for each "retry", so the final output
              //      is multiple junit reports. One for each "try" during the
              //      tests.
              //  - I have to use the goss' retry feature so it "waits" for
              //      Jenkins to load.
              //
              sh """
                cd build/raw-reports

                # split Goss output into multiple files numbered sequentially.
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

                # use the highest numbered file as Goss' final junit report
                mv goss-output\$(ls -l | grep -P goss-output[0-9]+\\.txt | wc -l).txt ../reports/goss-junit.xml
              """

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

    // stage('UATs') {
    //   parallel {
        stage('UAT: jenkins-config') {
          steps {
            sh '[ -d build/uats/jenkins-config ] || mkdir -p build/uats/jenkins-config'

            dir("build/uats/jenkins-config") {
              git(
                branch: 'feature/install-git-by-default',
                changelog: false,
                credentialsId: 'com.github.dankempster.user',
                poll: false,
                url: 'https://github.com/dankempster/ansible-role-jenkins-config.git'
              )

              ansiColor('xterm') {
                sh "sed -i 's/^MOLECULE_IMAGE:.*/MOLECULE_IMAGE: ${SED_IMAGE_NAME}:${IMAGE_TAG}/g' ./molecule/raspbian_stretch_env.yml"

                script {
                  try {
                    sh '''
                      virtualenv virtenv
                      source virtenv/bin/activate
                      pip install --upgrade ansible molecule docker jmespath xmlunittest

                      molecule -e ./molecule/raspbian_stretch_env.yml converge
                      molecule -e ./molecule/raspbian_stretch_env.yml verify
                    '''
                  } catch (Exception e) {
                    currentBuild.result = 'UNSTABLE'
                  }
                }
              }
            }
          }
          post {
            always {
              dir("build/uats/jenkins-config") {
                script {
                  try {
                    ansiColor('xterm') {
                      sh '''
                        virtualenv virtenv
                        source virtenv/bin/activate

                        molecule -e ./molecule/raspbian_stretch_env.yml destroy
                      '''
                    }
                  } catch (Exception e) {
                  }
                }
              }
            }
          }
        }
    //   }
    // }

    stage('Publish') {
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
