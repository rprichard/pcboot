#!/bin/sh
rm -f BUILD_LOG
date >> BUILD_LOG
time ./configure --prefix=$PWD/out/rust-i686-unknown-linux-gnu --target=i686-unknown-linux-gnu >> BUILD_LOG 2>&1
time make -j8 >> BUILD_LOG 2>&1
time make install >> BUILD_LOG 2>&1
date >> BUILD_LOG
