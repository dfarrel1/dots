// Tests for #1354: `work pickup` and `work release` wrote their governance
// record (docs/project/active-work/tracks/<name>.yaml resp.
// recently_completed/<name>.yaml) into the working tree and only printed a
// "remember to: git add ..." reminder, instead of staging it. An untracked
// record that a later `git pull` also wants to create aborts the
// fast-forward with "untracked working tree files would be overwritten by
// merge" — the reminder does not fix that if nobody runs it before the next
// pull.
//
// These tests need REAL git plumbing (`git add`, `git status`), unlike
// fakeRepo (per_track_files_test.go) which only drops a `.git/` marker
// directory — so they build an actual repo via `git init` (no commit needed),
// matching the pattern in release_cleanup_test.go / release_merge_check_test.go.
package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// realRepo creates an actual git repository (not just a .git/ marker) with
// an index on main, then chdirs into it. load()/save() + the new
// staging call all need working git plumbing, which a bare marker directory
// does not provide. Returns the abs path and a restore func.
func realRepo(t *testing.T) (string, func()) {
	t.Helper()
	dir := t.TempDir()
	mustGit(t, "", "init", "-b", "main", dir)
	mustGit(t, dir, "config", "user.email", "test@example.com")
	mustGit(t, dir, "config", "user.name", "Test")
	if err := os.WriteFile(filepath.Join(dir, "README.md"), []byte("seed\n"), 0o644); err != nil {
		t.Fatalf("write seed: %v", err)
	}
	mustGit(t, dir, "add", "README.md")

	prev, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	return dir, func() { _ = os.Chdir(prev) }
}

// gitStatusFor returns the raw `git status --porcelain -- <relPath>` line
// for relPath (e.g. "?? path" or "A  path"), or "" if git reports nothing
// for that path.
func gitStatusFor(t *testing.T, relPath string) string {
	t.Helper()
	out, err := exec.Command("git", "status", "--porcelain", "--", relPath).Output()
	if err != nil {
		t.Fatalf("git status --porcelain -- %s: %v", relPath, err)
	}
	return strings.TrimRight(string(out), "\n")
}

// TestPickup_StagesCreatedRecordFile pins the pickup half of #1354.
func TestPickup_StagesCreatedRecordFile(t *testing.T) {
	_, restore := realRepo(t)
	defer restore()

	if err := cmdPickup([]string{"demo-track", "--note", "fixture"}); err != nil {
		t.Fatalf("cmdPickup: %v", err)
	}

	relPath := "docs/project/active-work/tracks/demo-track.yaml"
	status := gitStatusFor(t, relPath)
	if status == "" {
		t.Fatalf("git status --porcelain shows nothing for %s — file was not even written", relPath)
	}
	if strings.HasPrefix(status, "??") {
		t.Errorf("record file left UNTRACKED after `work pickup` (status %q for %s) — "+
			"a later `git pull` that also wants to create this path will abort with "+
			"\"untracked working tree files would be overwritten by merge\" (#1354)", status, relPath)
	}
	if status[0] != 'A' {
		t.Errorf("expected the record staged as a new file (index status 'A'), got %q for %s", status, relPath)
	}
}

// TestRelease_StagesCreatedRecordFile pins the release half of #1354. The
// active track is planted directly (bypassing cmdPickup) so this test only
// exercises cmdRelease's own staging behavior.
func TestRelease_StagesCreatedRecordFile(t *testing.T) {
	_, restore := realRepo(t)
	defer restore()

	tracksDir, err := subdirPath(subdirTracks)
	if err != nil {
		t.Fatalf("subdirPath tracks: %v", err)
	}
	activeYAML := `name: demo-track
owner: tester@example.org
picked_up_at: 2026-10-20T13:00:00Z
last_activity_at: 2026-10-20T14:00:00Z
status: active
branch: track/demo-track
mode: master
`
	if err := os.WriteFile(filepath.Join(tracksDir, "demo-track.yaml"), []byte(activeYAML), 0o644); err != nil {
		t.Fatalf("plant active track: %v", err)
	}

	// Pickup already staged the active record; release must remove it from
	// the index as well as from disk, while leaving unrelated edits alone.
	activePath := "docs/project/active-work/tracks/demo-track.yaml"
	mustGit(t, "", "add", activePath)
	if err := os.WriteFile("unrelated.txt", []byte("leave untracked\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// --allow-unmerged short-circuits the merge-check git machinery (no
	// remote exists in this fixture) — same pattern as release_trim_test.go.
	if err := cmdRelease([]string{
		"demo-track",
		"--final-commit", "dead1234",
		"--allow-unmerged", "test fixture",
	}); err != nil {
		t.Fatalf("cmdRelease: %v", err)
	}

	out, err := exec.Command("git", "ls-files", "--", activePath).Output()
	if err != nil || len(out) != 0 {
		t.Fatalf("released track remains in index: %s (%v)", out, err)
	}
	if status := gitStatusFor(t, "unrelated.txt"); !strings.HasPrefix(status, "??") {
		t.Fatalf("unrelated file was staged: %s", status)
	}
	relPath := "docs/project/active-work/recently_completed/demo-track.yaml"
	status := gitStatusFor(t, relPath)
	if status == "" {
		t.Fatalf("git status --porcelain shows nothing for %s — file was not even written", relPath)
	}
	if strings.HasPrefix(status, "??") {
		t.Errorf("record file left UNTRACKED after `work release` (status %q for %s) — "+
			"a later `git pull` that also wants to create this path will abort with "+
			"\"untracked working tree files would be overwritten by merge\" (#1354)", status, relPath)
	}
	if status[0] != 'A' {
		t.Errorf("expected the record staged as a new file (index status 'A'), got %q for %s", status, relPath)
	}
}
