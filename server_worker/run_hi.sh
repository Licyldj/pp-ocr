#!/bin/bash

# 在/tmp 下创建个目录
mkdir -p /tmp/image-ocr-service-hi

docker compose -f docker-compose-hi.yaml down

docker compose -f docker-compose-hi.yaml up -d
