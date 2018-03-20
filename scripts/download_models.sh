#!/bin/bash

PROJECT_DIR="$(git rev-parse --show-toplevel)"
cd $PROJECT_DIR

MODEL_BASE=http://download.tensorflow.org/models/object_detection

for MODEL_ZIP in faster_rcnn_inception_v2_coco_2018_01_28.tar.gz faster_rcnn_resnet50_lowproposals_coco_2018_01_28.tar.gz
do
  curl -o ./assets/${MODEL_ZIP} ${MODEL_BASE}/${MODEL_ZIP}
  tar xvf ./assets/${MODEL_ZIP} -C ./assets
done
 
# cd ios/simple/data

# ln -s ../../../assets/faster_rcnn_inception_v2_coco_2018_01_28/frozen_inference_graph.pb faster-rcnn-inception.pb
# ln -s ../../../assets/faster_rcnn_resnet50_lowproposals_coco_2018_01_28/frozen_inference_graph.pb faster-rcnn-resnet50.pb

# cd ../../..
