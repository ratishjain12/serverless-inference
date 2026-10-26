import argparse
import tempfile
from pathlib import Path

import boto3
from huggingface_hub import snapshot_download

# Only what the container needs: config, tokenizer files, and safetensors weights.
ALLOW_PATTERNS = ["*.json", "spiece.model", "model.safetensors"]


def main():
    parser = argparse.ArgumentParser(description="Download a Hugging Face model and upload it to the model bucket.")
    parser.add_argument("--bucket", required=True, help="Model bucket (terraform output model_weights_bucket)")
    parser.add_argument("--model", default="t5-small", help="Hugging Face repo id; also the S3 prefix")
    args = parser.parse_args()

    s3 = boto3.client("s3")

    with tempfile.TemporaryDirectory() as tmp:
        local = Path(snapshot_download(args.model, local_dir=tmp, allow_patterns=ALLOW_PATTERNS))
        for path in sorted(p for p in local.rglob("*") if p.is_file() and ".cache" not in p.parts):
            key = f"{args.model}/{path.relative_to(local).as_posix()}"
            print(f"s3://{args.bucket}/{key}")
            s3.upload_file(str(path), args.bucket, key)


if __name__ == "__main__":
    main()
