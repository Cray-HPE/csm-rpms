FILES_REPOS = $(shell ./list-files.sh repos)
FILES_REPOS_COMPUTE = $(shell ./list-files.sh compute-repos)
FILES_PACKAGES = $(shell ./list-files.sh pkgs)
FILES_PACKAGES_COMPUTE = $(shell ./list-files.sh compute-pkgs)

all: index.yaml index-compute.yaml

zypper-download.log: $(FILES_PACKAGES) resolve-packages.sh $(FILES_REPOS)
	cat $(FILES_PACKAGES) | ./resolve-packages.sh $@ $(FILES_REPOS)

zypper-download-compute.log: $(FILES_PACKAGES_COMPUTE) resolve-packages.sh $(FILES_REPOS_COMPUTE)
	cat $(FILES_PACKAGES_COMPUTE) | ./resolve-packages.sh $@ $(FILES_REPOS_COMPUTE)

index.yaml: zypper-download.log create-index.sh $(FILES_REPOS)
	./create-index.sh $@ $(FILES_REPOS) < $<

index-compute.yaml: zypper-download-compute.log create-index.sh $(FILES_REPOS_COMPUTE)
	./create-index.sh $@ $(FILES_REPOS_COMPUTE) < $<

.PHONY: clean

clean:
	$(RM) zypper-download.log zypper-download-compute.log index.yaml index-compute.yaml
