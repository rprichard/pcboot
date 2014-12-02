#!/bin/sh
# Compile all of stage1 -- rustc and libraries.
# I suspect this is necessary if the src/libcore/macros.rs macros have changed.
make -j8 rustc-stage1
