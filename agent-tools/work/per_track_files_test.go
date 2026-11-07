// Tests for the per-track-files layout — load() globs subdirs, save()
// writes per-item with byte-skip-on-unchanged + orphan removal.
//
// These tests use a temp dir as the repo root by setting cwd; load() +
// save() walk up looking for a .git/ marker, so each test creates one.
package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	yaml "gopkg.in/yaml.v3"
)

// fakeRepo creates a directory with a .git/ marker so repoRoot() resolves
// it, plus the active-work directory pre-created. Returns the abs path
// and a chdir restore.
func fakeRepo(t *testing.T) (string, func()) {
	t.Helper()
	dir, err := os.MkdirTemp("", "work-pertrack-")
	if err != nil {
		t.Fatalf("mkdtemp: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(dir, ".git"), 0o755); err != nil {
		t.Fatalf("mkdir .git: %v", err)
	}
	prev, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	return dir, func() {
		_ = os.Chdir(prev)
		_ = os.RemoveAll(dir)
	}
}

func TestPerTrackFiles_SaveLoadRoundTrip(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	in := &Tracker{
		SchemaVersion: currentSchemaVersion,
		Tracks: []Track{{
			Name:           "alpha",
			Owner:          "a@example.org",
			PickedUpAt:     time.Date(2026, 5, 16, 10, 0, 0, 0, time.UTC),
			LastActivityAt: time.Date(2026, 5, 16, 10, 0, 0, 0, time.UTC),
			Status:         "active",
			Notes:          "first",
		}},
		RecentlyCompleted: []Completed{{
			Name:        "beta",
			Owner:       "b@example.org",
			PickedUpAt:  time.Date(2026, 5, 15, 0, 0, 0, 0, time.UTC),
			ReleasedAt:  time.Date(2026, 5, 15, 1, 0, 0, 0, time.UTC),
			FinalCommit: "deadbeef",
			Summary:     "did a thing.",
		}},
		Queued: []QueuedItem{{
			Name: "gamma",
			Why:  "later",
		}},
	}
	if err := save(in, ""); err != nil {
		t.Fatalf("save: %v", err)
	}
	got, _, err := load()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if len(got.Tracks) != 1 || got.Tracks[0].Name != "alpha" || got.Tracks[0].Notes != "first" {
		t.Errorf("track round-trip mismatch: %+v", got.Tracks)
	}
	if len(got.RecentlyCompleted) != 1 || got.RecentlyCompleted[0].Name != "beta" || got.RecentlyCompleted[0].Summary != "did a thing." {
		t.Errorf("completed round-trip mismatch: %+v", got.RecentlyCompleted)
	}
	if len(got.Queued) != 1 || got.Queued[0].Name != "gamma" {
		t.Errorf("queued round-trip mismatch: %+v", got.Queued)
	}
}

// TestPerTrackFiles_OrphanRemoval verifies that an item removed from the
// Tracker has its on-disk file deleted on next save.
func TestPerTrackFiles_OrphanRemoval(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	first := &Tracker{Tracks: []Track{
		{Name: "alpha", Owner: "a@example.org", PickedUpAt: time.Now().UTC(), LastActivityAt: time.Now().UTC(), Status: "active"},
		{Name: "beta", Owner: "b@example.org", PickedUpAt: time.Now().UTC(), LastActivityAt: time.Now().UTC(), Status: "active"},
	}}
	if err := save(first, ""); err != nil {
		t.Fatalf("first save: %v", err)
	}
	if _, err := os.Stat(filepath.Join("docs/project/active-work/tracks", "alpha.yaml")); err != nil {
		t.Fatalf("alpha not on disk: %v", err)
	}

	// Now drop alpha and re-save.
	second := &Tracker{Tracks: []Track{first.Tracks[1]}}
	if err := save(second, ""); err != nil {
		t.Fatalf("second save: %v", err)
	}
	if _, err := os.Stat(filepath.Join("docs/project/active-work/tracks", "alpha.yaml")); !os.IsNotExist(err) {
		t.Errorf("alpha.yaml should have been removed; stat err=%v", err)
	}
	if _, err := os.Stat(filepath.Join("docs/project/active-work/tracks", "beta.yaml")); err != nil {
		t.Errorf("beta.yaml should still exist: %v", err)
	}
}

// TestPerTrackFiles_NoChurnOnRepeatedSave is the load-bearing property: if
// nothing changed in memory, repeated saves must not rewrite files. This
// is what kills the merge-conflict class — concurrent PRs touching
// different tracks produce non-overlapping diffs.
func TestPerTrackFiles_NoChurnOnRepeatedSave(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	in := &Tracker{Tracks: []Track{{
		Name: "alpha", Owner: "a@example.org",
		PickedUpAt: time.Date(2026, 5, 16, 10, 0, 0, 0, time.UTC),
		Status:     "active",
	}}}
	if err := save(in, ""); err != nil {
		t.Fatalf("first save: %v", err)
	}
	fp := filepath.Join("docs/project/active-work/tracks", "alpha.yaml")
	st1, err := os.Stat(fp)
	if err != nil {
		t.Fatalf("stat #1: %v", err)
	}
	// Sleep so any mtime change would be observable.
	time.Sleep(20 * time.Millisecond)

	// Reload + save unchanged.
	got, _, err := load()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if err := save(got, ""); err != nil {
		t.Fatalf("second save: %v", err)
	}
	st2, err := os.Stat(fp)
	if err != nil {
		t.Fatalf("stat #2: %v", err)
	}
	if !st1.ModTime().Equal(st2.ModTime()) {
		t.Errorf("unchanged item was rewritten — would cause spurious git diff (mtime %v -> %v)",
			st1.ModTime(), st2.ModTime())
	}
}

// TestPerTrackFiles_FileClaimHashIsStable pins fileClaimKey: same path
// always maps to same filename. Two different paths must produce different
// filenames (collision check is a sanity ceiling, not exhaustive).
func TestPerTrackFiles_FileClaimHashIsStable(t *testing.T) {
	fc1 := FileClaim{Path: "ops/work/main.go"}
	fc2 := FileClaim{Path: "ops/work/main.go"}
	fc3 := FileClaim{Path: "ops/work/other.go"}
	if fileClaimKey(fc1) != fileClaimKey(fc2) {
		t.Errorf("same path produced different keys: %q vs %q", fileClaimKey(fc1), fileClaimKey(fc2))
	}
	if fileClaimKey(fc1) == fileClaimKey(fc3) {
		t.Errorf("different paths collided: both %q", fileClaimKey(fc1))
	}
	// Sanity: key contains the basename so a human can find it.
	if !contains(fileClaimKey(fc1), "main.go") {
		t.Errorf("key %q does not contain basename", fileClaimKey(fc1))
	}
}

// TestPerTrackFiles_LegacyMonolithBlocksLoad asserts the safety guard:
// if active-work.yaml still exists alongside active-work/, load() refuses
// rather than risk a partial migration silently being overwritten.
func TestPerTrackFiles_LegacyMonolithBlocksLoad(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	// Plant both shapes.
	if err := os.MkdirAll("docs/project", 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("docs/project/active-work.yaml", []byte("tracks: []\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := subdirPath(subdirTracks); err != nil {
		t.Fatal(err)
	}
	_, _, err := load()
	if err == nil {
		t.Fatal("load() should have refused but returned nil error")
	}
	if !contains(err.Error(), "legacy") {
		t.Errorf("load() error should mention legacy migration; got: %v", err)
	}
}

// TestPerTrackFiles_MigrateIsIdempotent verifies running migrate twice is
// a no-op on the second run.
func TestPerTrackFiles_MigrateIsIdempotent(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	src := `tracks:
  - name: only-track
    owner: x@example.org
    picked_up_at: 2026-05-16T00:00:00Z
    last_activity_at: 2026-05-16T00:00:00Z
    status: active
recently_completed: []
`
	if err := os.MkdirAll("docs/project", 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("docs/project/active-work.yaml", []byte(src), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := cmdMigrate(nil); err != nil {
		t.Fatalf("first migrate: %v", err)
	}
	if _, err := os.Stat("docs/project/active-work.yaml"); !os.IsNotExist(err) {
		t.Fatalf("legacy file should be removed: stat err=%v", err)
	}
	// Re-run: nothing to migrate; should not error.
	if err := cmdMigrate(nil); err != nil {
		t.Errorf("second migrate (no-op) errored: %v", err)
	}
}

func contains(s, substr string) bool {
	for i := 0; i+len(substr) <= len(s); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// Ensure the yaml package is imported even when test bodies don't use it.
var _ = yaml.Marshal

// TestLoad_SkipsMalformedFileLoudly: a single unparseable yaml in a
// subdir must NOT abort load() (and thus `work list` / every command) —
// the valid items still load and the bad file is skipped. Regression for
// the malformed queued yaml that exit-1'd `work list` and broke the
// ops-go bats gate when it landed via a docs-path PR (). The skip
// is loud (stderr warning), never silent ().
func TestLoad_SkipsMalformedFileLoudly(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	// One valid track on disk via the normal save path.
	in := &Tracker{Tracks: []Track{{
		Name: "alpha", Owner: "a@example.org",
		PickedUpAt: time.Now().UTC(), LastActivityAt: time.Now().UTC(), Status: "active",
	}}}
	if err := save(in, ""); err != nil {
		t.Fatalf("save: %v", err)
	}

	// Drop a malformed yaml into queued/ ("a: b: c" → "mapping values
	// are not allowed in this context", a reliable yaml.v3 parse error).
	qdir := filepath.Join("docs/project/active-work/queued")
	if err := os.MkdirAll(qdir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(qdir, "broken.yaml"), []byte("a: b: c\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	got, _, err := load()
	if err != nil {
		t.Fatalf("load() must not fail on one malformed file; got: %v", err)
	}
	if len(got.Tracks) != 1 || got.Tracks[0].Name != "alpha" {
		t.Errorf("valid track should still load past the bad file; got %+v", got.Tracks)
	}
	for _, q := range got.Queued {
		if q.Name == "broken" {
			t.Errorf("malformed file should be skipped, not loaded as a phantom item: %+v", q)
		}
	}
}
