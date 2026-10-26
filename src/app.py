import json
import logging
import os
from pathlib import PurePosixPath

import boto3

import worker

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("app")


def main():
    bucket = os.environ["INPUT_BUCKET"]
    key = os.environ["INPUT_KEY"]
    model_dir = os.environ["MODEL_DIR"]

    s3 = boto3.client("s3")

    log.info("reading s3://%s/%s", bucket, key)
    text = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8")

    log.info("loading model from %s", model_dir)
    model = worker.load(model_dir)

    result = worker.process(model, text)

    out_key = f"output/{PurePosixPath(key).stem}{worker.OUTPUT_SUFFIX}"
    s3.put_object(
        Bucket=bucket,
        Key=out_key,
        Body=json.dumps(result).encode("utf-8"),
        ContentType="application/json",
    )
    log.info("wrote s3://%s/%s", bucket, out_key)


if __name__ == "__main__":
    main()
