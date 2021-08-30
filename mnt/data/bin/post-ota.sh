#!/bin/sh
export LD_LIBRARY_PATH=/tmp
echo "OTA: copy log to TF."
log2tf.sh 
kill -9 1
