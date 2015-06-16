#!/bin/bash
# Need to be in the directory before scripts
pushd ./CFME
  zip -r ../automate.zip *
popd
