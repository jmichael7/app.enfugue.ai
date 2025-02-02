include makefile.env

############
## VARIABLES
############
ROOT_DIR=.
LICENSE=$(shell cat $(LICENSE_FILE))
ARCH=$(shell uname -m)

# Artifacts
WINDOWS_ARTIFACT=$(BUILD_DIR)/enfugue-server-$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)-win-$(ARTIFACT_SUFFIX)$(ARCH).zip
LINUX_ARTIFACT=$(BUILD_DIR)/enfugue-server-$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)-manylinux-$(ARTIFACT_SUFFIX)$(ARCH).tar.gz
MACOS_ARTIFACT=$(BUILD_DIR)/enfugue-server-$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)-macos-ventura-$(ARTIFACT_SUFFIX)$(ARCH).tar.gz

# Docker configs
SRC_DOCKERFILE=$(CONFIG_DIR)/$(DOCKERFILE).j2
SRC_DOCKERFILE_TENSORRT=$(CONFIG_DIR)/$(DOCKERFILE_TENSORRT).j2
BUILD_DOCKERFILE=$(BUILD_DIR)/$(DOCKERFILE)
BUILD_DOCKERFILE_TENSORRT=$(BUILD_DIR)/$(DOCKERFILE_TENSORRT)
BUILD_DOCKERFILE_BUILD=$(BUILD_DIR)/.$(DOCKERFILE).build
BUILD_DOCKERFILE_TENSORRT_BUILD=$(BUILD_DIR)/.$(DOCKERFILE_TENSORRT).build

# Default build is linux, we'll test in a moment
ARTIFACT=$(LINUX_ARTIFACT)
IS_WINDOWS=0
BUILD_TENSORRT=1

# Build tools
BUILD_NODE_PACKAGE=$(BUILD_DIR)/package.json
BUILD_PYTHON_DEPENDENCIES=$(BUILD_DIR)/.python_dependencies

PYTHON_IMPORTCHECK_SCRIPT=$(SCRIPT_DIR)/$(IMPORTCHECK_SCRIPT)
PYTHON_TEMPLATE_SCRIPT=$(SCRIPT_DIR)/$(TEMPLATE_SCRIPT)

# Vendor Paths and Directories
VENDOR_SCRIPTS=$(shell find $(VENDOR_DIR) -type f -name '*.sh')
BUILD_VENDOR_SCRIPTS=$(VENDOR_SCRIPTS:%=$(BUILD_DIR)/%)

# Images Paths and Directories
SRC_IMAGES_DIR=$(SRC_DIR)/img
BUILD_IMAGES_DIR=$(BUILD_DIR)/static/img
SRC_IMAGES=$(shell find $(SRC_IMAGES_DIR) -type f)
BUILD_IMAGES=$(patsubst $(SRC_IMAGES_DIR)/%,$(BUILD_IMAGES_DIR)/%,$(SRC_IMAGES))

# Templates (HTML) Paths and Directories
SRC_TEMPLATES_DIR=$(SRC_DIR)/html
BUILD_TEMPLATES_DIR=$(BUILD_DIR)/html
SRC_TEMPLATES=$(shell find $(SRC_TEMPLATES_DIR) -type f)
BUILD_TEMPLATES=$(patsubst $(SRC_TEMPLATES_DIR)/%,$(BUILD_TEMPLATES_DIR)/%,$(SRC_TEMPLATES))

# Javascript Paths and Directories
SRC_JS_DIR=$(SRC_DIR)/js
BUILD_JS_DIR=$(BUILD_DIR)/static/js
SRC_JS=$(shell find $(SRC_JS_DIR) -type f -name '*.mjs' -not -path '*/vendor/*')
BUILD_JS=$(patsubst $(SRC_JS_DIR)/%.mjs,$(BUILD_JS_DIR)/%.mjs,$(SRC_JS))
BUILD_TERSER=$(BUILD_DIR)/node_modules/.bin/terser

# CSS Paths and Directories
SRC_CSS_DIR=$(SRC_DIR)/css
BUILD_CSS_DIR=$(BUILD_DIR)/static/css
SRC_CSS=$(shell find $(SRC_CSS_DIR) -type f -name '*.css' -not -path '*/vendor/*')
BUILD_CSS=$(patsubst $(SRC_CSS_DIR)/%.css,$(BUILD_CSS_DIR)/%.min.css,$(SRC_CSS))
BUILD_CSS_MINIFY=$(BUILD_DIR)/node_modules/.bin/css-minify

# Python Paths and directories
PYTHON_SRC_DIR=$(SRC_DIR)/python
PYTHON_PACKAGES=$(shell find $(PYTHON_SRC_DIR) -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' -exec basename {} \;)
PYTHON_ARTIFACTS=$(PYTHON_PACKAGES:%=$(BUILD_DIR)/%-$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH).tar.gz)
PYTHON_SRC=$(shell find $(PYTHON_SRC_DIR) -type f -name "*.py" -not -path '*/.*' -not -path '*/test*' -not -path '*/sphinx*' -not -path '*/build*')
PYTHON_REQUIREMENTS=$(shell find $(PYTHON_SRC_DIR) -type f -name "requirements*.txt*")

PYTHON_BUILD_SRC=$(PYTHON_SRC:%=$(BUILD_DIR)/%)

# Touch'd files for testing
PYTHON_TEST_SRC=$(filter-out %setup.py %__main__.py %server.py %wholebody.py,$(PYTHON_SRC))
PYTHON_TEST_TYPE=$(PYTHON_TEST_SRC:%=$(BUILD_DIR)/%.typecheck)
PYTHON_TEST_IMPORT=$(PYTHON_TEST_SRC:%=$(BUILD_DIR)/%.importcheck)
PYTHON_TEST_UNIT=$(PYTHON_TEST_SRC:%=$(BUILD_DIR)/%.unittest)
PYTHON_TEST_INTEGRATION=$(PYTHON_PACKAGES:%=$(BUILD_DIR)/%.test)

# Everything else that's totally static
SRC_STATIC=$(shell find $(SRC_DIR) -type f -not -path '*/vendor/*' -not -path '*/js/*' -not -path '*/css/*' -not -path '*/python/*' -not -path '*/html/*' -not -name 'README*')
BUILD_STATIC=$(patsubst $(SRC_DIR)/%,$(BUILD_DIR)/static/%,$(SRC_STATIC))

###############
## PLATFORMS ##
###############
PYTHONPATH_PREFIX=
ifneq ($(findstring Windows,${OS}),)
  # WINDOWS
  IS_WINDOWS=1
  ARTIFACT=$(WINDOWS_ARTIFACT)
  PYINSTALLER_DEPENDENCIES=$(WINDOWS_PYINSTALLER_DEPENDENCIES)
  ifeq ($(findstring /cygwin/,$(SHELL)),)
    ifneq ($(findstring .exe,${SHELL}),.exe)
      ifneq (MINGW,$(findstring MINGW,$(shell uname)))
		# Python in Cygwin
		PYTHONPATH_PREFIX=/cygwin64
      endif
    endif
  endif
else
  ifeq ($(shell uname -s),Darwin)
    # MACOS
    ARTIFACT=$(MACOS_ARTIFACT)
  endif
endif

##################
## CAPABILITIES ##
##################
ifeq ($(shell $(PYTHON) -c "import tensorrt; import onnx_graphsurgeon" 2>&1),)
BUILD_TENSORRT=1
else
BUILD_TENSORRT=0
endif

ifneq ($(BUILD_TENSORRT),1)
PYTHON_TEST_SRC=$(filter-out %setup.py %__main__.py %server.py %wholebody.py $(SRC_DIR)/python/enfugue/diffusion/rt/%,$(PYTHON_SRC))
PYTHON_TEST_UNIT=$(PYTHON_TEST_SRC:%=$(BUILD_DIR)/%.unittest)
endif

#############
## TARGETS ##
#############

## OVERALL
##

## Builds artifact depending on platform
.PHONY: dist
dist: $(ARTIFACT)

## Windows build
$(WINDOWS_ARTIFACT): $(PYTHON_ARTIFACTS)
	rm -rf $(BUILD_DIR)/dist
	mkdir $(BUILD_DIR)/dist
	pip install pyinstaller $(WINDOWS_PYINSTALLER_DEPENDENCIES)
	pip install $<
	pyinstaller $(CONFIG_DIR)/$(PYINSTALLER_SPEC) --distpath $(BUILD_DIR)/dist
	if [ '$(MINIMAL_BUILD)' = '1' ]; then \
		7z a -tzip -v$(ARCHIVE_SIZE) -sdel $@ ./$(BUILD_DIR)/dist/*; \
	else \
		7z a -tzip -v$(ARCHIVE_SIZE) $@ ./$(BUILD_DIR)/dist/*; \
	fi;

## Linux build
$(LINUX_ARTIFACT): $(PYTHON_ARTIFACTS)
	rm -rf $(BUILD_DIR)/dist
	mkdir $(BUILD_DIR)/dist
	pip install $<
	pyinstaller $(CONFIG_DIR)/$(PYINSTALLER_SPEC) --distpath $(BUILD_DIR)/dist
	cp $(SCRIPT_DIR)/$(LINUX_RUN_SCRIPT) $(BUILD_DIR)/dist/$(PYINSTALLER_NAME)/
	@if [ '$(MINIMAL_BUILD)' != '1' ]; then \
		tar -cvzf $@ -C $(BUILD_DIR)/dist/ .; \
	else \
		tar -cvzf $@ --remove-files -C $(BUILD_DIR)/dist/ .; \
	fi;

## MacOS build
$(MACOS_ARTIFACT): $(PYTHON_ARTIFACTS)
	rm -rf $(BUILD_DIR)/dist
	mkdir $(BUILD_DIR)/dist
	pip install $<
	pyinstaller $(CONFIG_DIR)/$(PYINSTALLER_SPEC) --distpath $(BUILD_DIR)/dist
	cp $(SCRIPT_DIR)/$(LINUX_RUN_SCRIPT) $(BUILD_DIR)/dist/$(PYINSTALLER_NAME)/
	cp $(SCRIPT_DIR)/$(MACOS_UNQUARANTINE_SCRIPT) $(BUILD_DIR)/dist/$(PYINSTALLER_NAME)/
	tar -cvzf $@ -C $(BUILD_DIR)/dist/$(PYINSTALLER_NAME)/ .; \

## Docker build
.PHONY: docker
docker: $(BUILD_DOCKERFILE_BUILD)
$(BUILD_DOCKERFILE_BUILD): $(BUILD_DOCKERFILE)
	cd $(BUILD_DIR) && $(DOCKER) build -f $(shell basename $(BUILD_DOCKERFILE)) -t enfugue .
	@touch $@

.PHONY: dockerfile
dockerfile: $(BUILD_DOCKERFILE)
$(BUILD_DOCKERFILE): $(SRC_DOCKERFILE) $(PYTHON_ARTIFACTS)
	cp $(SRC_DOCKERFILE) $@
	$(eval SDIST=$(patsubst $(BUILD_DIR)/%,%,$(PYTHON_ARTIFACTS)))
	$(PYTHON) -m pibble.scripts.templatefiles $@ --version_major "$(VERSION_MAJOR)" --version_minor "$(VERSION_MINOR)" --version_patch "$(VERSION_PATCH)" $(SDIST:%=--sdist %) --docker_container "$(DOCKER_CONTAINER)" --docker_username "$(DOCKER_USERNAME)"

## Docker TensorRT build
.PHONY: docker-tensorrt
docker-tensorrt: $(BUILD_DOCKERFILE_TENSORRT_BUILD)
$(BUILD_DOCKERFILE_TENSORRT_BUILD): $(BUILD_DOCKERFILE_TENSORRT)
	cd $(BUILD_DIR) && $(DOCKER) build -f $(shell basename $(BUILD_DOCKERFILE_TENSORRT)) -t enfugue-tensorrt .
	@touch $@

.PHONY: dockerfile-tensorrt
dockerfile-tensorrt: $(BUILD_DOCKERFILE_TENSORRT)
$(BUILD_DOCKERFILE_TENSORRT): $(SRC_DOCKERFILE_TENSORRT) $(PYTHON_ARTIFACTS)
	cp $(SRC_DOCKERFILE_TENSORRT) $@
	$(eval SDIST=$(patsubst $(BUILD_DIR)/%,%,$(PYTHON_ARTIFACTS)))
	$(PYTHON) -m pibble.scripts.templatefiles $@ --version_major "$(VERSION_MAJOR)" --version_minor "$(VERSION_MINOR)" --version_patch "$(VERSION_PATCH)" $(SDIST:%=--sdist %) --docker_container "$(DOCKER_CONTAINER_TENSORRT)" --docker_username "$(DOCKER_USERNAME)"

## Split on Linux
.PHONY: split
split:
	split -b $(ARCHIVE_SIZE) -a 1 -d $(ARTIFACT) $(shell basename $(ARTIFACT)).
	rm $(ARTIFACT)

## Deletes build directory
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	@find $(ROOT_DIR) -type d -name "__pycache__" -exec rm -rf {} + 2>&1 > /dev/null
	@find $(ROOT_DIR) -type d -name ".mypy_cache" -exec rm -rf {} + 2>&1 > /dev/null
	@find $(ROOT_DIR) -type d -name "*.egg-info" -exec rm -rf {} + 2>&1 > /dev/null
	@find $(SRC_DIR) -type d -name "build" -exec rm -rf {} + 2>&1 > /dev/null

## BUILD TOOLS
##

## Node
.PHONY: node
node: $(BUILD_NODE_PACKAGE)
$(BUILD_NODE_PACKAGE): $(CONFIG_DIR)/$(NODE_PACKAGE)
	@mkdir -p $(shell dirname $@)
	cp $< $@
	cd $(BUILD_DIR) && npm install

## PYTHON SOURCE
##

## Package source distributions
.PHONY: sdist
sdist: $(PYTHON_ARTIFACTS)
$(PYTHON_ARTIFACTS): $(PYTHON_BUILD_SRC) $(BUILD_TEMPLATES) $(BUILD_CSS) $(BUILD_JS) $(BUILD_VENDOR_SCRIPTS) $(BUILD_IMAGES)
	$(eval PACKAGE=$(patsubst %-$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH).tar.gz,%,$(patsubst $(BUILD_DIR)/%,%,$@)))
	$(eval SETUP_SRC_PATH=$(PACKAGE:%=$(SRC_DIR)/python/%/setup.py))
	$(eval VERSION_SRC_PATH=$(PACKAGE:%=$(SRC_DIR)/python/%/version.txt))
	$(eval SETUP_BUILD_PATH=$(abspath $(BUILD_DIR)/$(SETUP_SRC_PATH)))
	$(eval VERSION_BUILD_PATH=$(abspath $(BUILD_DIR)/$(VERSION_SRC_PATH)))
	mkdir -p $(BUILD_DIR)/package/$(PACKAGE)/config/
	cp $(VERSION_SRC_PATH) $(VERSION_BUILD_PATH)
	$(PYTHON) -m pibble.scripts.templatefiles $(VERSION_BUILD_PATH) --version_major "$(VERSION_MAJOR)" --version_minor "$(VERSION_MINOR)" --version_patch "$(VERSION_PATCH)"
	cp -r $(shell dirname $(SETUP_BUILD_PATH)) $(BUILD_DIR)/package/
	cp -r $(BUILD_DIR)/static $(BUILD_DIR)/package/$(PACKAGE)/
	cp -r $(BUILD_DIR)/html $(BUILD_DIR)/package/$(PACKAGE)/static/
	cp $(ROOT_DIR)/config/production/* $(BUILD_DIR)/package/$(PACKAGE)/config/
	mv $(BUILD_DIR)/package/$(PACKAGE)/setup.py $(BUILD_DIR)/package/
	$(PYTHON) -m pibble.scripts.templatefiles $(BUILD_DIR)/package/setup.py --version_major "$(VERSION_MAJOR)" --version_minor "$(VERSION_MINOR)" --version_patch "$(VERSION_PATCH)"
	cd $(BUILD_DIR)/package/ && $(PYTHON) setup.py sdist -d .
	mv $(BUILD_DIR)/package/$(PACKAGE)-$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH).tar.gz $@
	rm -rf $(BUILD_DIR)/package

## Copy source files
$(PYTHON_BUILD_SRC): $(PYTHON_TEST_TYPE) $(PYTHON_TEST_IMPORT) $(PYTHON_TEST_UNIT) $(PYTHON_TEST_INTEGRATION)
	@mkdir -p $(shell dirname $@)
	cat $(patsubst $(BUILD_DIR)%,.%,$@) >> $@

## Run black
.PHONY: format
format: $(PYTHON_SRC)
	$(PYTHON) -m black --line-length 120 $?

## Run mypy
.PHONY: typecheck
typecheck: $(PYTHON_TEST_TYPE)
$(PYTHON_TEST_TYPE): $(PYTHON_TEST_SRC) 
	$(eval SRC_FILE=$(patsubst %.typecheck,%,$(patsubst $(BUILD_DIR)%,.%,$@)))
	@mkdir -p $(shell dirname $@)
	@if [ '$(RUN_TYPE_CHECK)' != '0' ]; then \
		echo "Running type check on $(SRC_FILE)"; \
		$(PYTHON) -m mypy $(SRC_FILE); \
	fi;
	@touch $@

## Run importcheck
.PHONY: importcheck
importcheck: $(PYTHON_TEST_IMPORT)
$(PYTHON_TEST_IMPORT): $(PYTHON_TEST_SRC) 
	$(eval SRC_FILE=$(patsubst %.importcheck,%,$(patsubst $(BUILD_DIR)%,.%,$@)))
	@mkdir -p $(shell dirname $@)
	@if [ '$(RUN_IMPORT_CHECK)' != '0' ]; then \
		echo "Running import check on $(SRC_FILE)"; \
		$(PYTHON) -m pibble.scripts.importcheck $(SRC_FILE); \
	fi;
	@touch $@

## Run doctest
.PHONY: unittest
unittest: $(PYTHON_TEST_UNIT)
$(PYTHON_TEST_UNIT): $(PYTHON_TEST_SRC)
	$(eval SRC_FILE=$(patsubst %.unittest,%,$(patsubst $(BUILD_DIR)%,.%,$@)))
	@mkdir -p $(shell dirname $@)
	@if [ '$(RUN_UNIT_TEST)' != '0' ]; then \
		echo "Running doctest on $(SRC_FILE)"; \
		PYTHONPATH=${PYTHONPATH_PREFIX}$(realpath $(SRC_DIR))/python $(PYTHON) -m doctest $(SRC_FILE); \
	fi;
	@touch $@

## Run integration tests
.PHONY: test
test: $(PYTHON_TEST_INTEGRATION)
$(PYTHON_TEST_INTEGRATION):
	@mkdir -p $(shell dirname $@)
	@if [ '$(RUN_INTEGRATION_TEST)' != '0' ]; then \
		echo "Running integration tests"; \
		PYTHONPATH=${PYTHONPATH_PREFIX}$(realpath $(SRC_DIR))/python $(PYTHON) -m $(patsubst %.test,%,$(patsubst $(BUILD_DIR)/%,%,$@)).test.run; \
	fi;
	@touch $@

## STATIC FILES
##

## Fetch vendor resources
.PHONY: vendor
vendor: $(BUILD_VENDOR_SCRIPTS)
$(BUILD_VENDOR_SCRIPTS): $(VENDOR_SCRIPTS)
	$(eval SRC_SCRIPT=$(patsubst $(BUILD_DIR)/%,%,$@))
	@mkdir -p $(shell dirname $@)
	cp $(SRC_SCRIPT) $@
	bash $@ $(abspath $(BUILD_DIR))/static/
	rm $@

## Minify javascript
.PHONY: js
js: $(BUILD_JS)
$(BUILD_JS): $(BUILD_NODE_PACKAGE)
	$(eval SRC_JS_FILE=$(patsubst $(BUILD_JS_DIR)/%.mjs,$(SRC_JS_DIR)/%.mjs,$@))
	$(eval JS_SHEBANG=$(shell head -n 1 $(SRC_JS_FILE)))
	@mkdir -p $(shell dirname $@)
	@if [ '$(JS_SHEBANG)' = '/** NOCOMPRESS */' ]; then \
		echo "Copying $(SRC_JS_FILE) with no compression"; \
		$(abspath $(BUILD_TERSER)) -- $(SRC_JS_FILE) > $@; \
	elif [ '$(JS_SHEBANG)' = '/** NOMANGLE */' ]; then \
		echo "Compressing $(SRC_JS_FILE)"; \
		$(abspath $(BUILD_TERSER)) --compress -- $(SRC_JS_FILE) > $@; \
	else \
		echo "Compressing and mangling $(SRC_JS_FILE)"; \
		$(abspath $(BUILD_TERSER)) --compress --mangle -- $(SRC_JS_FILE) > $@; \
	fi;

## Minify css
.PHONY: css
css: $(BUILD_CSS)
$(BUILD_CSS): $(BUILD_NODE_PACKAGE)
	$(eval SRC_CSS_FILE=$(patsubst $(BUILD_CSS_DIR)/%.min.css,$(SRC_CSS_DIR)/%.css,$@))
	mkdir -p $(shell dirname $@)
	cd $(BUILD_DIR) && $(abspath $(BUILD_CSS_MINIFY)) --file ../$(SRC_CSS_FILE) --output ../$(shell dirname $@)

## Copy templates
.phony: html
html: $(BUILD_TEMPLATES)
$(BUILD_TEMPLATES): $(SRC_TEMPLATES)
	@mkdir -p $(shell dirname $@)
	$(eval SRC_TEMPLATE=$(patsubst $(BUILD_TEMPLATES_DIR)/%,$(SRC_TEMPLATES_DIR)/%,$@))
	cp $(SRC_TEMPLATE) $@

## Copy images
.phony: img
img: $(BUILD_IMAGES)
$(BUILD_IMAGES): $(SRC_IMAGES)
	@mkdir -p $(shell dirname $@)
	$(eval SRC_IMAGE=$(patsubst $(BUILD_IMAGES_DIR)/%,$(SRC_IMAGES_DIR)/%,$@))
	cp $(SRC_IMAGE) $@

## Output version
.phony: version
version:
	@echo "$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)"
