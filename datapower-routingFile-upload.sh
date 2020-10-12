pipeline {
    agent { label 'master' }
    environment {
        
          DATAPOWER_CREDENTIALS = credentials("${DATAPOWER_CREDENTIALS_NAME}")
          domain = "${DATAPOWER_DOMAIN}"
          
    }

    stages {
       stage('Checkout') {
         steps {
           script {
           // git credentialsId: '07a1290b-7d34-4da2-9805-b323b47c06e0', url: 'ssh://git@bitbucket-agl.absa.co.za:7999/ci/dp_int_security_services_routing.git'
           // Do a ls -lart to view all the files are cloned. It will be clonned. This is just for you to be sure about it.
           sh "ls -lart ./*" 
           // List all branches in your repo. 
           // sh "git branch -a"
           // Checkout to a specific branch in your repo.
           // sh "git checkout master"
          }
         }
       }
        stage('Encoding routing.xml to base64') {
          steps {
             sh 'file=$(base64 routing.xml)'
          }
        }
        stage('Generating request.xml payload') {
          steps {
             sh '''
             requestmsg="<?xml version='1.0' encoding='UTF-8'?><soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/'><soapenv:Body><dp:request domain='${domain}'  xmlns:dp='http://www.datapower.com/schemas/management'><dp:set-file name='local:///Infrastructure/routing.xml'>${file}</dp:set-file></dp:request></soapenv:Body></soapenv:Envelope>"
             printf "%s" "$requestmsg" > request.xml
             '''
          }
        }
        stage('Executing routing update') {
          steps {
             sh '''
             while IFS="" read -r p || [ -n "$p" ]
             do
                res=$(curl -s \
                -X 'POST' \
                -d @request.xml \
                -u ${DATAPOWER_CREDENTIALS} \
                 -k \
                echo $p )

                status=$(printf '%s\n' "$res" |
                /var/jenkins_home/utilities/xmllint --xpath "/*[local-name() = 'Envelope']/*[local-name() = 'Body']/*[local-name() = 'response']/*[local-name() = 'result']/text()" -)

                if [ "$status" != "OK" ]; then 
                    printf '\n ##########################\nDeploy Failed to [%s] with error [%s]\n ##########################\n' "$p" "$status"
                    #success="false"
                    exit 1
                fi

             done < dpservers.list 
             printf 'Deploy completed successfully'
             '''
          }
       }
    }
}
