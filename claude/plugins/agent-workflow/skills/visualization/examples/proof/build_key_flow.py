#!/usr/bin/env python3
"""Proof of the first-round fix: a NEW figure on a topic not in any library, started from the nearest pattern.
Topic: how a key moves from a grant to a reader. Nearest pattern: process_line (an ordered sequence with one
bracketed span). Rounds are logged in critique-log.md. usage: python3 build_key_flow.py -> out/key-flow.svg"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(os.path.dirname(HERE))
sys.path[:0] = [os.path.join(SKILL, "scripts"), os.path.join(SKILL, "patterns")]
from patterns import process_line
from figkit import page

f = process_line(
    "Only the named reader can ever open the key",
    "The owner grants access; the key service wraps the data key to the reader's public key; the wrapped key is stored beside the data; the reader fetches it and unwraps it with a private key that never leaves the reader's device, then decrypts the data",
    steps=[("Grant", "names the reader"), ("Wrap", "to reader's key"), ("Store", "beside the data"),
           ("Fetch", "by the reader"), ("Unwrap", "with private key"), ("Open", "the data")],
    bracket=(1, 4, "the key is never in the clear"),
    closing="never leaves the reader's device, so a copy of the stored key opens nothing.",
    closing_lead="The private key")
svg = f.save(os.path.join(HERE, "out", "key-flow.svg"))
page([svg], "Key flow", out=os.path.join(HERE, "out", "key-flow.html"),
     captions=["A stolen copy of the stored key is useless without the reader's private key."])
print("out/key-flow.svg", f.height)
