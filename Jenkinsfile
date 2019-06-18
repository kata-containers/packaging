pipeline {
  agent {
    node {
      label 'ubuntu-lts-latest-azure'
    }

  }
  stages {
    stage('Setup') {
      steps {
        sh '''echo "Setup"
#.ci/setup.sh
'''
      }
    }
  }
}