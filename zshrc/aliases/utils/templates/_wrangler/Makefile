#!/usr/bin/make -f

.ONESHELL:
.SHELL := /usr/bin/bash

AUTHOR := "noelruault"
PROJECTNAME := $(shell basename "$$(pwd)")
PROJECTPATH := $(shell pwd)

# Global variable for package manager (defaulting to "bun")
PACKAGE_MANAGER ?= bun

# Global variable for main JS file
MAIN_JS_FILE := src/index.js

# Function: require_command
# Description: This function checks if a specified command is installed on the system. If the command is not found, it displays an error message provided by the user and exits with a non-zero status code.
# Parameters:
#   - $1 (string): The name of the command to check for.
#   - $2 (string): The error message to display if the specified command is not found.
# Usage: require_command <command_name> <error_message>
# Example:
#   To ensure that 'wget' command is installed and display a custom error message if it's not found, you can use:
#     $(call require_command, wget, "wget is required to download files.")
#   This will check if 'wget' is installed, and if not, it will display the provided error message and exit with a non-zero status code.
#
define require_command
	@if ! command -v $(1) &> /dev/null; then\
		echo "$(1) not found. $(2)";\
		exit 1;\
	fi
endef

# Function: install_command
# Description: This function checks if a specified command is installed on the system. If the command is not found, it installs it using a provided installation command.
# Parameters:
#   - $1 (string): The name of the command to check for.
#   - $2 (string): The command to execute for installation if the specified command is not found.
# Usage: install_command <command_name> <installation_command>
# Example:
#   To ensure that 'wget' command is installed, you can use:
#     $(call install_command, wget, sudo apt-get install wget)
#   This will check if 'wget' is installed, and if not, it will execute 'sudo apt-get install wget' to install it.
#
define install_command
	@if ! command -v $(1) &> /dev/null; then\
		echo "$(1) not found, installing...";\
		$(2);\
	fi
endef

help:
	@echo "Usage: make [options] [arguments]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Ensure initialization is possible
	$(call require_command, $(PACKAGE_MANAGER), "Configure NodeJS and bun before running this program.")

deps: init ## Setup project
	$(call install_command, eslint, $(PACKAGE_MANAGER) install eslint --save-dev)
	$(call install_command, $(PACKAGE_MANAGER) wrangler, $(PACKAGE_MANAGER) install wrangler@latest --save-dev)
	$(PACKAGE_MANAGER) install --save-dev --verbose
	@echo "✔️ Project setup complete."

update: ## Update
	$(PACKAGE_MANAGER) install wrangler@latest --save-dev

serve-server: ## Start wrangler live server
	$(PACKAGE_MANAGER) wrangler dev $(MAIN_JS_FILE)

serve-static: ## Start wrangler live server
	live-server --entry-file=index.html

deploy: ## Deploy using wrangler
	@sed -i '' "s/compatibility_date = \"[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\"/compatibility_date = \"$(date +%Y-%m-%d)\"/" wrangler.toml
	# $(PACKAGE_MANAGER) wrangler login && $(PACKAGE_MANAGER) wrangler whoami
	$(PACKAGE_MANAGER) wrangler deploy
