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

    stage('Validate node-image-non-compute-common packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/base.packages --validate
          ./scripts/update-package-versions.sh -p packages/node-image-non-compute-common/metal.packages --validate
        """
      }
    }

    stage('Validate node-image-kubernetes packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/node-image-kubernetes/base.packages --validate
          ./scripts/update-package-versions.sh -p packages/node-image-kubernetes/metal.packages --validate
          ./scripts/update-package-versions.sh -p packages/node-image-kubernetes/google.packages --validate
        """
      }
    }

    stage('Validate node-image-storage-ceph packages') {
      steps {
        sh """
          ./scripts/update-package-versions.sh -p packages/node-image-storage-ceph/base.packages --validate
          ./scripts/update-package-versions.sh -p packages/node-image-storage-ceph/metal.packages --validate
        """
      }
    }

  }
}
