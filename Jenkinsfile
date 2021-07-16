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


  parameters {
    booleanParam(name: 'dev', defaultValue: "${env.BRANCH_NAME}" ==~ /release\/.*/ ? false : true, description: 'Allow unsigned packages and pull from mainline (defaults to false for release branches)')
  }

  environment {
    SUFFIX = "${env.JOB_BASE_NAME.replaceAll("%2F","-").toLowerCase()}-${env.BUILD_NUMBER}"
    DEV    = "${params.dev}"
  }

  stages {
    stage('Setup Docker Cache') {
      steps {
        sh """
          ./scripts/update-package-versions.sh --refresh --no-cache --suffix ${env.SUFFIX}
        """
      }
    }

    stage('Validate cray-pre-install-toolkit packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/cray-pre-install-toolkit/base.packages --validate --suffix ${env.SUFFIX}
          ./scripts/update-package-versions.sh -p packages/cray-pre-install-toolkit/metal.packages --validate --suffix ${env.SUFFIX}
          ./scripts/update-package-versions.sh -p packages/cray-pre-install-toolkit/firmware.packages --validate --suffix ${env.SUFFIX}
        """
      }
    }

    stage('Validate node-image-non-compute-common packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages --validate --suffix ${env.SUFFIX}
          ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/metal.packages --validate --suffix ${env.SUFFIX}
        """
      }
    }

    stage('Validate node-image-kubernetes packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/node-image-kubernetes/base.packages --validate --suffix ${env.SUFFIX}
          ./scripts/update-package-versions.sh -p packages/node-image-kubernetes/metal.packages --validate --suffix ${env.SUFFIX}
          ./scripts/update-package-versions.sh -p packages/node-image-kubernetes/google.packages --validate --suffix ${env.SUFFIX}
        """
      }
    }

    stage('Validate node-image-storage-ceph packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/node-image-storage-ceph/base.packages --validate --suffix ${env.SUFFIX}
          ./scripts/update-package-versions.sh -p packages/node-image-storage-ceph/metal.packages --validate --suffix ${env.SUFFIX}
        """
      }
    }

  }
}
