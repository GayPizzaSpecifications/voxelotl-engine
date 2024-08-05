#!/bin/sh
set -e

brew install cmake
cmake -B .. -G Xcode -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=3FQW5YTQR8 ../..
