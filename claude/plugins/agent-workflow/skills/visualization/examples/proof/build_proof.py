#!/usr/bin/env python3
"""Proof set, built only with the skill (patterns, figkit, tokens). usage: python3 build_proof.py
Writes out/:
  onboard-process.svg    rebuild of a shipped process figure, from patterns.process_line
  growth-comparison.svg  rebuild of a shipped comparison figure, from patterns.hub_vs_mesh
  ds-default.html        the comparison figure under the bundled default design system
  ds-provided.html       the same figure under a PROVIDED system (provided/style.css), measured with its own fonts
  proof-doc.html         a one-page document carrying the figures, for the PDF gate
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(os.path.dirname(HERE))
sys.path[:0] = [os.path.join(SKILL, "scripts"), os.path.join(SKILL, "patterns")]
import figkit
from figkit import page
from patterns import process_line, hub_vs_mesh

OUT = os.path.join(HERE, "out")
VIZ = os.path.join(SKILL, "templates", "viz.css")
PROVIDED = os.path.join(HERE, "provided", "style.css")


def onboard():
    return process_line(
        "One path for every person: nothing is issued until two people approve",
        "A person joins in five steps: a sponsor invites, the person applies, the sponsor vouches, an administrator approves, and credentials are issued automatically in about 30 seconds",
        steps=[("Sponsor invites", "single-use link"), ("Person applies", "their own details"), ("Sponsor vouches", "for them"),
               ("Administrator approves", "the second check"), ("Credentials issued", "in about 30 seconds")],
        bracket=(2, 3, "the two approvals"),
        closing="are enrolled by a vetted custodian, each with its own certificate and access.",
        closing_lead="Machines")


def growth():
    return hub_vs_mesh("Pair-by-pair links grow much faster than the systems",
                       "Linking six systems pair by pair needs fifteen links; connecting each once to a shared hub needs six connections",
                       6, left="Pair by pair", right="Through one shared hub", hub="Hub",
                       note="Pair by pair, 20 systems need 190 links and 50 need 1,225. Through one hub: 20 and 50.")


def main():
    figkit.use_metrics()                                   # the default stack's metrics
    a = onboard().save(os.path.join(OUT, "onboard-process.svg"))
    b = growth().save(os.path.join(OUT, "growth-comparison.svg"))
    page([b], "Default design system", css=[VIZ], out=os.path.join(OUT, "ds-default.html"),
         captions=["Bundled default: role tokens from templates/tokens-default.json, PDF-safe offline font stack."])
    # A provided system: its tokens map 1:1 onto the roles (provided/map.json, from tokens.py detect), and its
    # font stack differs, so the figure is re-measured with metrics taken across THAT stack before layout.
    figkit.use_metrics(os.path.join(HERE, "provided", "font-metrics.json"))
    c = growth().save(os.path.join(OUT, "growth-comparison-provided.svg"))
    page([c], "Provided design system", css=[PROVIDED], out=os.path.join(OUT, "ds-provided.html"),
         captions=["Provided system: its own tokens and font stack; the figure was re-measured for that stack."])
    figkit.use_metrics()
    page([a, b], "Proof document", css=[VIZ], out=os.path.join(OUT, "proof-doc.html"),
         captions=["Two approvals stand between an invitation and a credential.",
                   "The gap widens with every system added: at 20 systems it is 190 links against 20 connections."])
    print("built:", ", ".join(sorted(f for f in os.listdir(OUT) if f.endswith((".svg", ".html")))))


if __name__ == "__main__":
    main()
