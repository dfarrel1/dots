#!/bin/bash
git commit --amend --no-edit && git push origin `git rev-parse --abbrev-ref HEAD` --force