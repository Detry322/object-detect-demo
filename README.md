# object-detect-demo
A demo of object detection using faster-rcnn running in tensorflow on iOS and Android.

## Setup

First, download the needed model.

```
git submodule init
git submodule update
scripts/download_model.sh
scripts/fix_tensorflow.sh
```

Then, you need to compile tensorflow from source:

```
tensorflow/tensorflow/contrib/makefile/build_all_ios.sh 
```
