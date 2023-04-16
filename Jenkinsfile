pipeline {
  agent any
  stages {
	stage("Git Checkout") {
      steps {
        git 'https://github.com/Poojitha2022/terraform.git'
      }
	}
    stage("terraform init") {
      steps {     
	    sh 'whoami'      
        sh ‘terraform init’
      }
    }
  }
}
