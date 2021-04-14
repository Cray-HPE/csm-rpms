pipeline {
    agent {
       node { label 'metal-gcp-builder' }
    }

    // Configuration options applicable to the entire job
    options {
        // Don't fill up the build server with unnecessary cruft
        buildDiscarder(logRotator(numToKeepStr: '5'))

        timestamps()
    }

    stages {
        stage('Setup Docker Cache') {
            steps {
                sh """
                    ./scripts/update-package-versions.sh --refresh --no-cache
                """
            }
        }

        stage('Validate cray-pre-install-toolkit packages') {
            steps {
                sh """
                    ./scripts/update-package-versions.sh -p packages/cray-pre-install-toolkit/base.packages --validate
                """
            }
        }
    }
}
