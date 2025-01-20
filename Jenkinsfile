pipeline {
  agent any

  stages {
    stage('Terraform Init and Apply') {
      steps {
        sh 'terraform init'
        sh 'terraform apply -auto-approve'
      }
    }

    stage('Run Ansible Playbook') {
      steps {
        sh 'ansible-playbook -i <your-inventory-file> webserver.yml'
      }
    }
  }
}
