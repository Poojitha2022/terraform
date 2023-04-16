pipeline {
  agent any
  tools {
       terraform 'terraform'
    }
  stages {
	stage('Git Checkout') {
      steps {
        sh 'git clone https://github.com/Poojitha2022/terraform.git'
      }
	}
    stage('terraform init') {
      steps {     
	    sh 'whoami'      
        sh ‘terraform init’
      }
    }
  }
}
