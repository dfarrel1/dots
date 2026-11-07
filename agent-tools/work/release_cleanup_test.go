package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// TestCleanupWorktree_RefusesWhenInsideWorktree exercises the safety check that
// prevents cleanupWorktree from removing the worktree the operator is currently
// standing in. Asserts via side-effect: worktree dir still exists after the call.
func TestCleanupWorktree_RefusesWhenInsideWorktree(t *testing.T) {
	master, wt, absWT := setupRepoWithWorktree(t, "sample", "track/sample")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(absWT); err != nil {
		t.Fatalf("chdir into worktree: %v", err)
	}

	cleanupWorktree(wt)

	if _, err := os.Stat(absWT); err != nil {
		t.Errorf("worktree should still exist when refused (cwd inside): %v", err)
	}
	_ = master
}

// TestCleanupWorktree_RemovesCleanWorktree verifies the happy path:
// cleanupWorktree successfully removes a clean worktree from outside.
func TestCleanupWorktree_RemovesCleanWorktree(t *testing.T) {
	master, wt, absWT := setupRepoWithWorktree(t, "clean", "track/clean")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	cleanupWorktree(wt)

	if _, err := os.Stat(absWT); !os.IsNotExist(err) {
		t.Errorf("worktree should have been removed; stat err=%v", err)
	}
}

// TestCleanupWorktree_DirtyWorktreeNotForceRemoved verifies that a dirty
// worktree is preserved (cleanupWorktree does NOT --force) so operator can
// decide whether to keep or force-remove.
func TestCleanupWorktree_DirtyWorktreeNotForceRemoved(t *testing.T) {
	master, wt, absWT := setupRepoWithWorktree(t, "dirty", "track/dirty")

	if err := os.WriteFile(filepath.Join(absWT, "scratch.txt"), []byte("uncommitted\n"), 0o644); err != nil {
		t.Fatalf("dirty worktree: %v", err)
	}

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	cleanupWorktree(wt)

	if _, err := os.Stat(absWT); err != nil {
		t.Errorf("worktree should still exist (no --force on dirty): %v", err)
	}
}

// TestCleanupWorktree_NoOpOnEmptyPath verifies the early-exit guard.
func TestCleanupWorktree_NoOpOnEmptyPath(t *testing.T) {
	cleanupWorktree("")
	// No panic, no side-effect = pass.
}

// setupRepoWithWorktree builds a master git repo with one seed commit on main,
// and a child worktree at .claude/worktrees/<name> on branch <branchName>.
// Returns (masterAbsPath, worktreeRelPath, worktreeAbsPath). Each test gets
// its own t.TempDir(), so they're trivially parallelizable.
func setupRepoWithWorktree(t *testing.T, name, branchName string) (string, string, string) {
	t.Helper()
	tmp := t.TempDir()
	master := filepath.Join(tmp, "master")

	mustGit(t, "", "init", "-b", "main", master)
	mustGit(t, master, "config", "user.email", "test@example.com")
	mustGit(t, master, "config", "user.name", "Test")
	if err := os.WriteFile(filepath.Join(master, "README.md"), []byte("seed\n"), 0o644); err != nil {
		t.Fatalf("write seed: %v", err)
	}
	mustGit(t, master, "add", "README.md")
	mustGit(t, master, "commit", "-m", "seed")

	wt := ".claude/worktrees/" + name
	mustGit(t, master, "worktree", "add", "-b", branchName, wt)
	absWT := filepath.Join(master, wt)
	return master, wt, absWT
}

func mustGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	if dir != "" {
		cmd.Dir = dir
	}
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v failed: %v\n%s", args, err, out)
	}
}
