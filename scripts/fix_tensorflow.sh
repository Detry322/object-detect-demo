#!/bin/bash

PROJECT_DIR="$(git rev-parse --show-toplevel)"
cd $PROJECT_DIR

cp assets/Fixed_Makefile tensorflow/tensorflow/contrib/makefile/Makefile
cp assets/fixed_build_all_ios.sh tensorflow/tensorflow/contrib/makefile/build_all_ios.sh
