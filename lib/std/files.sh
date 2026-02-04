#!/usr/bin/env bash

files.file.exists() { [[ -f "$1" ]] }

files.dir.exists() { [[ -d "$1" ]] }