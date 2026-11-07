package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestInferCanonicalWorktree_DetectsMatchingWorktree exercises the
// pickup-side inference: when called from master cwd with a canonical
// worktree already provisioned at `.claude/worktrees/<name>` with branch
// `track/<name>` checked out, inferCanonicalWorktree returns the relative
// path + branch.
func TestInferCanonicalWorktree_DetectsMatchingWorktree(t *testing.T) {
	master, wtRel, _ := setupRepoWithWorktree(t, "sample", "track/sample")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	gotPath, gotBranch, ok := inferCanonicalWorktree("sample")
	if !ok {
		t.Fatalf("expected ok=true; got false")
	}
	if gotPath != wtRel {
		t.Errorf("path: got %q want %q", gotPath, wtRel)
	}
	if gotBranch != "track/sample" {
		t.Errorf("branch: got %q want %q", gotBranch, "track/sample")
	}
}

// TestInferCanonicalWorktree_FalseWhenNoWorktree verifies the negative
// case — no worktree at the canonical path = (_, _, false).
func TestInferCanonicalWorktree_FalseWhenNoWorktree(t *testing.T) {
	// setupRepoWithWorktree creates ONE worktree; ask about a different name
	master, _, _ := setupRepoWithWorktree(t, "sample", "track/sample")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	_, _, ok := inferCanonicalWorktree("does-not-exist")
	if ok {
		t.Errorf("expected ok=false for non-existent track; got true")
	}
}

// TestInferCanonicalWorktree_FalseWhenBranchMismatch verifies that a worktree
// at the canonical path but with a different branch checked out is NOT
// matched — protects against accidentally claiming an unrelated worktree.
func TestInferCanonicalWorktree_FalseWhenBranchMismatch(t *testing.T) {
	master, _, _ := setupRepoWithWorktree(t, "sample", "feature/wrong-branch")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	_, _, ok := inferCanonicalWorktree("sample")
	if ok {
		t.Errorf("expected ok=false when worktree branch != track/<name>; got true")
	}
}

// TestUnmergedCommits_NoneOnFreshBranch verifies that a freshly-created
// branch with no commits past origin/main reports zero unmerged commits.
func TestUnmergedCommits_NoneOnFreshBranch(t *testing.T) {
	master, _, absWT := setupTestRepoWithRemote(t, "fresh", "track/fresh")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	got, _, err := unmergedCommits("track/fresh")
	if err != nil {
		t.Fatalf("unmergedCommits: %v", err)
	}
	if len(got) != 0 {
		t.Errorf("expected 0 unmerged commits; got %d: %v", len(got), got)
	}
	_ = absWT
}

// TestUnmergedCommits_DetectsUnmergedCommit verifies that an unpushed
// commit on a track branch is reported as unmerged against origin/main.
// regression — the wg-cp0-substrate-redesign-rca pattern.
func TestUnmergedCommits_DetectsUnmergedCommit(t *testing.T) {
	master, _, absWT := setupTestRepoWithRemote(t, "unmerged", "track/unmerged")

	// Author a substantive commit on the track branch
	if err := os.WriteFile(filepath.Join(absWT, "feature.md"), []byte("design\n"), 0o644); err != nil {
		t.Fatalf("write feature: %v", err)
	}
	mustGit(t, absWT, "add", "feature.md")
	mustGit(t, absWT, "commit", "-m", "feat: substantive design content")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	got, _, err := unmergedCommits("track/unmerged")
	if err != nil {
		t.Fatalf("unmergedCommits: %v", err)
	}
	if len(got) != 1 {
		t.Errorf("expected 1 unmerged commit; got %d: %v", len(got), got)
	}
	if len(got) > 0 && !strings.Contains(got[0], "substantive design content") {
		t.Errorf("expected subject in output; got %q", got[0])
	}
}

// TestUnmergedCommits_BranchNotFoundReturnsErr verifies a graceful error
// when the branch doesn't exist locally — release falls through to a
// merge-check-skipped warning rather than crashing.
func TestUnmergedCommits_BranchNotFoundReturnsErr(t *testing.T) {
	master, _, _ := setupTestRepoWithRemote(t, "fresh", "track/fresh")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	_, _, err := unmergedCommits("track/does-not-exist")
	if err == nil {
		t.Errorf("expected error for nonexistent branch; got nil")
	}
}

// setupTestRepoWithRemote builds a master repo with a fake `origin` remote
// (also a local repo) so `git cherry origin/main <branch>` has something to
// compare against. Mirrors setupRepoWithWorktree but adds the remote.
func setupTestRepoWithRemote(t *testing.T, name, branchName string) (string, string, string) {
	t.Helper()
	tmp := t.TempDir()
	remote := filepath.Join(tmp, "remote.git")
	master := filepath.Join(tmp, "master")

	// Create bare remote
	mustGit(t, "", "init", "--bare", "-b", "main", remote)

	mustGit(t, "", "init", "-b", "main", master)
	mustGit(t, master, "config", "user.email", "test@example.com")
	mustGit(t, master, "config", "user.name", "Test")
	mustGit(t, master, "remote", "add", "origin", remote)

	if err := os.WriteFile(filepath.Join(master, "README.md"), []byte("seed\n"), 0o644); err != nil {
		t.Fatalf("write seed: %v", err)
	}
	mustGit(t, master, "add", "README.md")
	mustGit(t, master, "commit", "-m", "seed")
	mustGit(t, master, "push", "-u", "origin", "main")

	wt := ".claude/worktrees/" + name
	mustGit(t, master, "worktree", "add", "-b", branchName, wt)

	// Make origin/main pointer available locally — `git push` above already updated
	// origin/main since we pushed; verify it exists for the cherry check.
	if _, err := exec.Command("git", "-C", master, "rev-parse", "origin/main").Output(); err != nil {
		t.Fatalf("origin/main not visible after push: %v", err)
	}

	absWT := filepath.Join(master, wt)
	return master, wt, absWT
}

// TestMergeVerdict_SquashAware pins the decision table: a branch
// that git-cherry reports as "unmerged" (squash-merge defeats the
// patch-id match) must still PASS when a merged PR exists, rather than
// forcing the operator onto --allow-unmerged.
func TestMergeVerdict_SquashAware(t *testing.T) {
	cases := []struct {
		name          string
		unmergedCount int
		mergedViaPR   bool
		allowReason   string
		want          mergeAction
	}{
		{"cherry-clean passes", 0, false, "", mergePass},
		{"squash-merge: cherry unhappy but PR merged passes", 6, true, "", mergePass},
		{"genuinely unmerged, no override refuses", 6, false, "", mergeRefuse},
		{"genuinely unmerged, operator override allows", 6, false, "abandoned: superseded", mergeAllowUnmerged},
		{"merged PR wins even if override also given", 6, true, "whatever", mergePass},
		{"cherry-clean wins regardless of inputs", 0, false, "reason", mergePass},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := mergeVerdict(c.unmergedCount, c.mergedViaPR, c.allowReason)
			if got != c.want {
				t.Errorf("mergeVerdict(%d, %v, %q) = %d; want %d",
					c.unmergedCount, c.mergedViaPR, c.allowReason, got, c.want)
			}
		})
	}
}

// setupTwoRemoteRepo builds the shape that actually broke: a clone whose
// `origin` is a STALE MIRROR and whose second remote (`primary`) is the
// PRIMARY where work really merges. The track branch's commit is pushed to
// the primary's main and NOT to the mirror, so a check that only consults
// origin/main reports it unmerged.
//
// Returns the master worktree path and the track branch name.
func setupTwoRemoteRepo(t *testing.T, name, branchName string) (string, string) {
	t.Helper()
	tmp := t.TempDir()
	mirror := filepath.Join(tmp, "mirror.git")
	primary := filepath.Join(tmp, "primary.git")
	master := filepath.Join(tmp, "master")

	mustGit(t, "", "init", "--bare", "-b", "main", mirror)
	mustGit(t, "", "init", "--bare", "-b", "main", primary)

	mustGit(t, "", "init", "-b", "main", master)
	mustGit(t, master, "config", "user.email", "test@example.com")
	mustGit(t, master, "config", "user.name", "Test")
	mustGit(t, master, "remote", "add", "origin", mirror)
	mustGit(t, master, "remote", "add", "primary", primary)

	if err := os.WriteFile(filepath.Join(master, "README.md"), []byte("seed\n"), 0o644); err != nil {
		t.Fatalf("write seed: %v", err)
	}
	mustGit(t, master, "add", "README.md")
	mustGit(t, master, "commit", "-m", "seed")
	// Both remotes start level.
	mustGit(t, master, "push", "origin", "main")
	mustGit(t, master, "push", "primary", "main")

	// Track branch with one commit — the "work".
	mustGit(t, master, "checkout", "-b", branchName)
	if err := os.WriteFile(filepath.Join(master, "work.txt"), []byte("the work\n"), 0o644); err != nil {
		t.Fatalf("write work: %v", err)
	}
	mustGit(t, master, "add", "work.txt")
	mustGit(t, master, "commit", "-m", "the work")

	// It lands on the PRIMARY's main only. The mirror stays behind — exactly
	// the production state (measured 2026-09-08: mirror 320 commits behind).
	mustGit(t, master, "push", "primary", branchName+":main")
	mustGit(t, master, "checkout", "main")
	mustGit(t, master, "fetch", "primary")

	return master, branchName
}

// TestUnmergedCommits_MergedOnPrimaryNotMirror is the regression gate for the
// origin-hardcoding. The work is merged on the primary and absent from the
// mirror; unmergedCommits must report ZERO. Before the fix it consulted only
// `origin/main` and reported the commit as unmerged, which pushed the release
// onto --allow-unmerged and stamped "abandoned" onto merged work.
func TestUnmergedCommits_MergedOnPrimaryNotMirror(t *testing.T) {
	master, branch := setupTwoRemoteRepo(t, "twin", "track/twin")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	// Guard the premise: origin/main really is behind, so this test would
	// fail against the old origin-only implementation rather than pass by luck.
	out, err := exec.Command("git", "cherry", "origin/main", branch).Output()
	if err != nil {
		t.Fatalf("premise check failed: %v", err)
	}
	if !strings.Contains(string(out), "+ ") {
		t.Fatalf("premise broken: origin/main is not behind; got %q", out)
	}

	got, gotRemote, err := unmergedCommits(branch)
	if err != nil {
		t.Fatalf("unmergedCommits: %v", err)
	}
	if len(got) != 0 {
		t.Errorf("merged on the primary must count as merged; got %d unmerged: %v", len(got), got)
	}
	// The reported remote must be the one that actually matched. Crediting
	// origin here would be the unverified claim the multi-remote change exists
	// to remove.
	if gotRemote != "primary" {
		t.Errorf("matched remote: got %q want %q", gotRemote, "primary")
	}
}

// TestRemotesWithMain_ListsBothAndPrefersOrigin pins the ordering contract:
// every remote carrying a main ref is returned, origin first.
func TestRemotesWithMain_ListsBothAndPrefersOrigin(t *testing.T) {
	master, _ := setupTwoRemoteRepo(t, "twin2", "track/twin2")

	origCwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(origCwd) }()
	if err := os.Chdir(master); err != nil {
		t.Fatalf("chdir master: %v", err)
	}

	got := remotesWithMain()
	if len(got) != 2 {
		t.Fatalf("expected both remotes; got %v", got)
	}
	if got[0] != "origin" {
		t.Errorf("origin must be probed first; got %v", got)
	}
}

// TestRemoteSlug_URLForms pins slug extraction across the URL shapes this
// repo actually uses. A wrong slug means `gh --repo` asks the wrong repo,
// which is the whole bug.
func TestRemoteSlug_URLForms(t *testing.T) {
	cases := []struct{ url, want string }{
		{"ssh://git@gh-alias/example-org/project.git", "example-org/project"},
		{"ssh://git@github.com/mirror-org/project-mirror.git", "mirror-org/project-mirror"},
		{"git@github.com:example-org/project.git", "example-org/project"},
		{"https://github.com/example-org/project", "example-org/project"},
		{"https://github.com/example-org/project/", "example-org/project"},
	}
	for _, c := range cases {
		tmp := t.TempDir()
		mustGit(t, "", "init", "-b", "main", tmp)
		mustGit(t, tmp, "remote", "add", "probe", c.url)

		origCwd, _ := os.Getwd()
		if err := os.Chdir(tmp); err != nil {
			t.Fatalf("chdir: %v", err)
		}
		got := remoteSlug("probe")
		_ = os.Chdir(origCwd)

		if got != c.want {
			t.Errorf("remoteSlug(%q) = %q; want %q", c.url, got, c.want)
		}
	}
}
