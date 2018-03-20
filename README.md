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
```

Follow instructions here: [building tensorflow for iOS](https://github.com/tensorflow/tensorflow/tree/master/tensorflow/contrib/makefile#ios)
