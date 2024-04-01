#!/usr/bin/make -f

.ONESHELL:
.SHELL := /usr/bin/bash

AUTHOR := "noelruault"
PROJECTNAME := $(shell basename "$$(pwd)")
PROJECTPATH := $(shell pwd)

help:
	@echo "Usage: make [options] [arguments]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

setup: ## Setup project
	@if ! command -v npm &> /dev/null; then\
		echo "npm not found, configure NodeJS and npm before running this program";\
		exit 1;\
	fi
	@if ! command -v eslint &> /dev/null; then\
		echo "eslint could not be found, installing...";\
	else npm install eslint --save-dev;\
	fi
	@if ! command -v live-server &> /dev/null; then\
		echo "live-server could not be found, installing...";\
		npm install live-server -g;\
	fi

serve: ## Starts live server
	live-server
