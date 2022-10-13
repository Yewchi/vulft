#!/bin/bash

debug=$(grep "DEBUG =" lib_util/util.lua)
echo $debug
if [[ $debug =~ 'DEBUG = false' ]]; then
	echo "/VUL-FT/ DEBUG: OKAY"
else
	echo "/VUL-FT/ DEBUG: NOT RELEASABLE"
fi

active_workflow=$(find . -type f -name "*.sw*")
echo "open files:"
echo $active_workflow
if [[ $active_workflow =~ ^$ ]]; then
	echo '...'
	echo "/VUL-FT/ WORKFLOW CLOSED: OKAY"
else
	echo "/VUL-FT/ WORKFLOW CLOSED: NOT RELEASABLE"
fi
