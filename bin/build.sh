#!/usr/bin/env bash
set -xe pipefail

for d in $(\ls -1F | grep '/$' | grep -v docs/ | grep -v bin/); do
  helm package $d -d docs/
done

helm repo index docs \
  --url https://k-akari.github.io/myk8s
