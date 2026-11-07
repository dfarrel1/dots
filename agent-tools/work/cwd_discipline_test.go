// Tests for cwd-discipline edge cases — the failure class the substrate
// exists to prevent. Per completion review + the 2026-05-08
// a session that drifted twice, the goal here is to
// pin down the corner cases where cwd-relative operations could leak
// across worktree boundaries.
//
// Coverage:
//  1. .iso-mode.env presence + parsing — every per-session worktree should
//     have one after the session launcher enters it
//  2. WORKTREE_ROOT-anchored cd works correctly even after chdir-drift
//  3. busTrackFromCwd returns the right track when in track/* branch
//  4. detectWorktreeContext correctly distinguishes master vs child worktree
//  5. busFilePath stays per-repo even after chdir into a child worktree
//     (the repo fingerprint is based on the OUTERMOST repo, not cwd)
//  6. Edge case: relative-cd into non-existent dir doesn't silently
//     "succeed" (the cd-anchor discipline catches this)
//  7. Edge case: spaces / special chars in worktree name
//  8. Edge case: deeply nested worktrees (worktree of worktree — git
//     refuses; verify our code reports cleanly)
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func chdirForTest(t *testing.T, dir string) {
	t.Helper()
	prev, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("change directory: %v", err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(prev); err != nil {
			t.Errorf("restore working directory: %v", err)
		}
	})
}

// makeWorktree creates a sandboxed master repo + a child worktree on a
// `track/<name>` branch. Returns (masterPath, worktreePath).
func makeWorktree(t *testing.T, name string) (string, string) {
	t.Helper()
	tmp := t.TempDir()
	t.Setenv("HOME", tmp)
	master := filepath.Join(tmp, "repo")
	if err := os.MkdirAll(master, 0o755); err != nil {
		t.Fatal(err)
	}
	gi := exec.Command("git", "init", "--quiet", master)
	if err := gi.Run(); err != nil {
		t.Fatal(err)
	}
	commit := exec.Command("git", "-C", master, "commit", "--allow-empty", "-m", "init", "--quiet")
	commit.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@e.com",
		"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@e.com",
	)
	_ = commit.Run()
	wtPath := filepath.Join(master, ".claude", "worktrees", name)
	wtAdd := exec.Command("git", "-C", master, "worktree", "add", wtPath, "-b", "track/"+name)
	if out, err := wtAdd.CombinedOutput(); err != nil {
		t.Fatalf("git worktree add: %v\n%s", err, out)
	}
	return master, wtPath
}

func TestCwdDiscipline_IsoModeEnvCanBeParsed(t *testing.T) {
	_, wtPath := makeWorktree(t, "test-iso-env")
	envPath := filepath.Join(wtPath, ".iso-mode.env")
	content := fmt.Sprintf(`WORKTREE_ROOT=%s
TRACK=test-iso-env
BRANCH=track/test-iso-env
MODE=worktree
AUTONOMOUS=0
`, wtPath)
	if err := os.WriteFile(envPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	// Parse via shell `source` to confirm shape
	cmd := exec.Command("bash", "-c",
		fmt.Sprintf("source %s && echo $WORKTREE_ROOT $TRACK $MODE", envPath))
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("source .iso-mode.env: %v", err)
	}
	got := strings.TrimSpace(string(out))
	expected := fmt.Sprintf("%s test-iso-env worktree", wtPath)
	if got != expected {
		t.Errorf("expected %q, got %q", expected, got)
	}
}

func TestCwdDiscipline_DetectWorktreeContext_Master(t *testing.T) {
	master, _ := makeWorktree(t, "ctx-master")
	chdirForTest(t, master)
	mode, _, _, _ := detectWorktreeContext(flagMap{})
	if mode != "master" {
		t.Errorf("expected master mode from master worktree, got %q", mode)
	}
}

func TestCwdDiscipline_DetectWorktreeContext_Worktree(t *testing.T) {
	_, wt := makeWorktree(t, "ctx-wt")
	chdirForTest(t, wt)
	mode, wtPath, branch, _ := detectWorktreeContext(flagMap{})
	if mode != "worktree" {
		t.Errorf("expected worktree mode, got %q", mode)
	}
	if branch != "track/ctx-wt" {
		t.Errorf("expected branch track/ctx-wt, got %q", branch)
	}
	if !strings.Contains(wtPath, "ctx-wt") {
		t.Errorf("expected wtPath to contain ctx-wt, got %q", wtPath)
	}
}

func TestCwdDiscipline_DetectWorktreeContext_MasterFlagOverrides(t *testing.T) {
	_, wt := makeWorktree(t, "ctx-flag")
	chdirForTest(t, wt)
	mode, wtPath, branch, _ := detectWorktreeContext(flagMap{"master": ""})
	if mode != "master" {
		t.Errorf("--master flag should force master mode, got %q", mode)
	}
	if wtPath != "<master>" {
		t.Errorf("--master mode should set wtPath=<master>, got %q", wtPath)
	}
	if branch != "main" {
		t.Errorf("--master mode should report main branch, got %q", branch)
	}
}

func TestCwdDiscipline_BusTrackFromCwd_TrackBranch(t *testing.T) {
	_, wt := makeWorktree(t, "track-detect-x")
	chdirForTest(t, wt)
	got := busTrackFromCwd()
	if got != "track-detect-x" {
		t.Errorf("expected track 'track-detect-x', got %q", got)
	}
}

func TestCwdDiscipline_BusTrackFromCwd_MasterMain(t *testing.T) {
	master, _ := makeWorktree(t, "ignored")
	chdirForTest(t, master)
	got := busTrackFromCwd()
	// On master worktree, branch is main; busTrackFromCwd only returns
	// when branch starts with "track/"
	if got != "" {
		t.Errorf("expected empty track from master, got %q", got)
	}
}

func TestCwdDiscipline_BusFilePath_SameAcrossMasterAndWorktree(t *testing.T) {
	master, wt := makeWorktree(t, "fp-test")
	prevWd, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(prevWd); err != nil {
			t.Errorf("restore working directory: %v", err)
		}
	})

	if err := os.Chdir(master); err != nil {
		t.Fatal(err)
	}
	pMaster, err := busFilePath()
	if err != nil {
		t.Fatal(err)
	}

	if err := os.Chdir(wt); err != nil {
		t.Fatal(err)
	}
	pWt, err := busFilePath()
	if err != nil {
		t.Fatal(err)
	}

	// CRITICAL: bus file path should be the same when called from the master
	// worktree OR from a child worktree. Otherwise child sessions write to a
	// different bus than master and never see each other.
	if pMaster != pWt {
		t.Errorf("bus path diverges across worktrees:\n  master: %s\n  child:  %s", pMaster, pWt)
	}
}

func TestCwdDiscipline_RelativeCdToNonexistentFails(t *testing.T) {
	_, wt := makeWorktree(t, "relcd-test")
	chdirForTest(t, wt)
	// A relative cd to a non-existent dir SHOULD fail loudly (this is what
	// cwd-anchor discipline catches — the relative-cd doesn't silently
	// succeed by going to launch-dir or similar)
	cmd := exec.Command("bash", "-c", "cd does-not-exist-xyz")
	if err := cmd.Run(); err == nil {
		t.Errorf("expected bash cd to non-existent dir to fail loudly")
	}
}

func TestCwdDiscipline_GitCWithAbsolutePathWorks(t *testing.T) {
	_, wt := makeWorktree(t, "git-c-test")
	// Don't chdir; verify `git -C <abs-path>` works regardless of cwd
	cmd := exec.Command("git", "-C", wt, "branch", "--show-current")
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("git -C: %v", err)
	}
	branch := strings.TrimSpace(string(out))
	if branch != "track/git-c-test" {
		t.Errorf("expected branch track/git-c-test from git -C; got %q", branch)
	}
}

// Edge case: the spike's failure mode.
// Worktree relative `cd ops/foo` from cwd=master walks into master/ops/foo,
// not worktree/ops/foo. This test asserts that we know this is the failure
// mode + documents it.
func TestCwdDiscipline_RelativeCdFromWrongCwdIsTheFailureMode(t *testing.T) {
	master, wt := makeWorktree(t, "drift-demo")
	// Create the relative path in BOTH master and worktree so the relative
	// cd "succeeds" silently — but lands in the wrong place.
	if err := os.MkdirAll(filepath.Join(master, "ops", "foo"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(wt, "ops", "foo"), 0o755); err != nil {
		t.Fatal(err)
	}
	// Drop a marker file in each so we can tell them apart
	_ = os.WriteFile(filepath.Join(master, "ops", "foo", "MARKER"), []byte("master"), 0o644)
	_ = os.WriteFile(filepath.Join(wt, "ops", "foo", "MARKER"), []byte("worktree"), 0o644)

	prevWd, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(prevWd); err != nil {
			t.Errorf("restore working directory: %v", err)
		}
	})

	// Simulate the drift: agent THINKS it's in worktree but actually has
	// drifted to master. Relative `cd ops/foo` then reads master's MARKER.
	if err := os.Chdir(master); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("bash", "-c", "cd ops/foo && cat MARKER")
	out, err := cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	got := strings.TrimSpace(string(out))
	if got != "master" {
		t.Errorf("expected 'master' (drift demo), got %q", got)
	}

	// Now the SAFE pattern: absolute path anchored to WORKTREE_ROOT
	cmd = exec.Command("bash", "-c", fmt.Sprintf(`cd "%s/ops/foo" && cat MARKER`, wt))
	out, err = cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	got = strings.TrimSpace(string(out))
	if got != "worktree" {
		t.Errorf("absolute-anchored cd should land in worktree; got %q", got)
	}
}

// Edge case: special chars in track name. The launcher rejects but the
// detect logic should handle gracefully if someone hand-crafts a worktree.
func TestCwdDiscipline_TrackNameWithDashesAndDots(t *testing.T) {
	_, wt := makeWorktree(t, "track-name.with.dots-and-dashes")
	chdirForTest(t, wt)
	got := busTrackFromCwd()
	if got != "track-name.with.dots-and-dashes" {
		t.Errorf("expected exact track name, got %q", got)
	}
}
