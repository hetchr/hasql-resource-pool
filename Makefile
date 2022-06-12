
PROJECT_NAME            := hasql-resource-pool

# https://www.gnu.org/software/make/manual/html_node/Special-Variables.html
# https://ftp.gnu.org/old-gnu/Manuals/make-3.80/html_node/make_17.html
PROJECT_MKFILE_PATH     := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
PROJECT_MKFILE_DIR      := $(shell cd $(shell dirname $(PROJECT_MKFILE_PATH)); pwd)

PROJECT_ROOT            := $(PROJECT_MKFILE_DIR)
LOCAL_UNTRACK_DIR       := $(PROJECT_MKFILE_DIR)/.local
CABAL_BUILD_DIR			:= $(CABAL_DIR)
DISTRIBUTIONS           := $(CABAL_BUILD_DIR)/sdist


$(PROJECT_ROOT)/cabal.project.local:
	$(MAKE) update-local


.PHONY: update-local
update-local:
	cabal v2-update 	--builddir $(CABAL_BUILD_DIR)
	cabal v2-configure	--builddir $(CABAL_BUILD_DIR)


.PHONY: build-local
build-local:	$(PROJECT_ROOT)/library					\
				$(PROJECT_ROOT)/$(PROJECT_NAME).cabal	\
				$(PROJECT_ROOT)/cabal.project.local
	cabal v2-build all --builddir $(CABAL_BUILD_DIR)


.PHONY: repl
repl:	build-local
	cabal v2-repl hasql-resource-pool --builddir $(CABAL_BUILD_DIR)


.PHONY: run
run:
	cabal v2-run -- --help

.PHONY: run-example
run-example:
	echo "done"


.PHONY: distribute
distribute:
	cabal v2-sdist --builddir $(CABAL_BUILD_DIR)


.PHONY: publish
publish: | cleanall distribute
	cabal upload $(DISTRIBUTIONS)/$(PROJECT_NAME)-*.tar.gz


.PHONY: release
release:
	cabal upload $(DISTRIBUTIONS)/$(PROJECT_NAME)-*.tar.gz --publish


.PHONY: cleanall
cleanall:
	rm -r $(DISTRIBUTIONS)
