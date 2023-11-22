#!/bin/sh
REGISTRY_ID=crpopg6s1lst7qelv4ie
docker build -t "bingo:latest" ../bingo/
docker tag bingo:latest "cr.yandex/$REGISTRY_ID/bingo:latest"
docker push "cr.yandex/$REGISTRY_ID/bingo:latest"