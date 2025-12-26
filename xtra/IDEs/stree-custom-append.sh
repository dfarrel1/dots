#!/bin/bash
# needs recent git version (brew upgrade git)
git commit --amend --no-edit && git push origin `git rev-parse --abbrev-ref HEAD` --force