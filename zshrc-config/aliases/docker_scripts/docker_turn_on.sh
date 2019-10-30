#!/bin/bash
sudo find . -name \*.pyc -print -delete \
&& cd $PROJECT_PATH \
&& ./docker/run.sh create \
&& ./docker/run.sh start core
