#!/usr/bin/env bash

git tag $1
git archive --format=tar --prefix=service-testing-$1/ $1 | gzip > $1.tgz

