# faster-rcnn-demo
A demo of faster-rcnn running in tensorflow on iOS and Android

## Setup

First, download the needed model.

```
git submodule init
git submodule update
scripts/download_model.sh
```

Then, you need to compile tensorflow from source:

```
cd tensorflow
tensorflow/contrib/makefile/build_all_ios.sh
cd ..
```
