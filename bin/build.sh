#!/usr/bin/env bash
set -xe pipefail

helm package main/ -d docs/
helm repo index docs --url https://k-akari.github.io/myk8s
