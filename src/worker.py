import os

from transformers import pipeline

MODEL_NAME = os.environ.get("MODEL_NAME", "t5-small")
OUTPUT_SUFFIX = "_summary.json"

CHUNK_WORDS = 300


def load(model_dir):
    return pipeline("summarization", model=model_dir, tokenizer=model_dir, device=-1)


def process(summarizer, text):
    words = text.split()
    if not words:
        raise ValueError("input document is empty")

    # t5-small has a 512-token window; summarize chunks so long contracts aren't truncated.
    chunks = [" ".join(words[i : i + CHUNK_WORDS]) for i in range(0, len(words), CHUNK_WORDS)]
    parts = summarizer(chunks, max_length=120, min_length=20, truncation=True)

    return {
        "status": "success",
        "model_used": MODEL_NAME,
        "summary": " ".join(p["summary_text"] for p in parts),
    }
