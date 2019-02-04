#!/bin/bash

TAG=test

git tag --delete $TAG
git push --delete origin $TAG

git tag $TAG
git push origin $TAG
