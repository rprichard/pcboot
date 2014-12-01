#!/bin/sh
./configure --prefix=$PWD/out/rust-i686-unknown-linux-gnu --target=i686-unknown-linux-gnu
make -j8
make install
