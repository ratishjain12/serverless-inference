#!/bin/sh
set -eu

: "${MODEL_BUCKET:?MODEL_BUCKET is required}"
: "${INPUT_BUCKET:?INPUT_BUCKET is required}"
: "${INPUT_KEY:?INPUT_KEY is required}"

MODEL_NAME="${MODEL_NAME:-t5-small}"
export MODEL_DIR="${MODEL_DIR:-/models/${MODEL_NAME}}"

mkdir -p "$MODEL_DIR"
s5cmd --numworkers "${S5CMD_WORKERS:-64}" cp "s3://${MODEL_BUCKET}/${MODEL_NAME}/*" "${MODEL_DIR}/"

exec python app.py
