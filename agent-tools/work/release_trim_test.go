// Test pins the bug surfaced 2026-05-21: cmdRelease previously trimmed
// in-memory t.RecentlyCompleted to the last 7 days. Under the per-track-
// files refactor, the syncSubdir GC step then DELETED the corresponding
// on-disk yaml files. Witnessed live: a release tried to remove 9
// unrelated old recently_completed yamls.
//
// The trim has been removed. This test asserts the property at the
// file-system level: an old recently_completed yaml that exists on disk
// before the release MUST still exist on disk after the release. The
// only writes are (a) the new release's yaml created, (b) the released
// track's yaml deleted from tracks/.
package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestRelease_PreservesOldRecentlyCompleted(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	// Plant an active track that we'll release.
	tracksDir, err := subdirPath(subdirTracks)
	if err != nil {
		t.Fatalf("subdirPath tracks: %v", err)
	}
	activeYAML := `name: track-being-released
owner: tester@example.org
picked_up_at: 2026-05-21T13:00:00Z
last_activity_at: 2026-05-21T14:00:00Z
status: active
branch: track/track-being-released
mode: master
`
	if err := os.WriteFile(filepath.Join(tracksDir, "track-being-released.yaml"), []byte(activeYAML), 0o644); err != nil {
		t.Fatalf("plant active track: %v", err)
	}

	// Plant TWO old recently_completed rows whose released_at is >7 days
	// ago — the pre-fix trim would have dropped these from t.RecentlyCompleted
	// and the GC pass would have deleted the on-disk yamls.
	rcDir, err := subdirPath(subdirRecentlyCompleted)
	if err != nil {
		t.Fatalf("subdirPath recently_completed: %v", err)
	}
	oldRow1 := `name: closed-3-weeks-ago
owner: tester@example.org
picked_up_at: 2026-04-25T12:00:00Z
released_at: 2026-04-25T18:00:00Z
final_commit: aaaa1111
summary: |
  An old closeout the operator wants to keep around as history.
`
	oldRow2 := `name: closed-2-months-ago
owner: tester@example.org
picked_up_at: 2026-03-15T12:00:00Z
released_at: 2026-03-15T18:00:00Z
final_commit: bbbb2222
summary: very old closeout
`
	oldFile1 := filepath.Join(rcDir, "closed-3-weeks-ago.yaml")
	oldFile2 := filepath.Join(rcDir, "closed-2-months-ago.yaml")
	if err := os.WriteFile(oldFile1, []byte(oldRow1), 0o644); err != nil {
		t.Fatalf("plant oldRow1: %v", err)
	}
	if err := os.WriteFile(oldFile2, []byte(oldRow2), 0o644); err != nil {
		t.Fatalf("plant oldRow2: %v", err)
	}

	// Run release. --allow-unmerged short-circuits the merge-check git
	// machinery so the fakeRepo (no remote) is enough.
	if err := cmdRelease([]string{
		"track-being-released",
		"--final-commit", "dead1234",
		"--allow-unmerged", "test fixture",
	}); err != nil {
		t.Fatalf("cmdRelease: %v", err)
	}

	// The two old recently_completed files must still exist on disk —
	// pre-fix, the trim+GC would have deleted them.
	if _, err := os.Stat(oldFile1); err != nil {
		t.Errorf("oldFile1 was deleted by release (regression): %v", err)
	}
	if _, err := os.Stat(oldFile2); err != nil {
		t.Errorf("oldFile2 was deleted by release (regression): %v", err)
	}

	// The released track must have a recently_completed entry on disk.
	newFile := filepath.Join(rcDir, "track-being-released.yaml")
	if _, err := os.Stat(newFile); err != nil {
		t.Errorf("released track was not written to recently_completed: %v", err)
	}

	// The original tracks/ entry must be gone.
	gone := filepath.Join(tracksDir, "track-being-released.yaml")
	if _, err := os.Stat(gone); !os.IsNotExist(err) {
		t.Errorf("released track was not removed from tracks/; stat err=%v", err)
	}

	// Sanity: load() sees all three recently_completed entries (the new
	// release + the two old preserved ones).
	got, _, err := load()
	if err != nil {
		t.Fatalf("post-release load: %v", err)
	}
	if len(got.RecentlyCompleted) != 3 {
		names := make([]string, 0, len(got.RecentlyCompleted))
		for _, rc := range got.RecentlyCompleted {
			names = append(names, rc.Name)
		}
		t.Errorf("expected 3 recently_completed rows, got %d: %v", len(got.RecentlyCompleted), names)
	}
	// Belt-and-suspenders: the old ReleasedAt dates are far enough back
	// that the now() at test time MUST be >7 days after them — this
	// confirms the test is actually exercising the previously-buggy path,
	// not accidentally landing inside the old 7-day window.
	for _, rc := range got.RecentlyCompleted {
		if rc.Name == "closed-3-weeks-ago" || rc.Name == "closed-2-months-ago" {
			age := time.Since(rc.ReleasedAt)
			if age <= 7*24*time.Hour {
				t.Errorf("test fixture is mis-dated — %s age %v is inside the old 7-day window, so the test isn't exercising the bug it claims to pin", rc.Name, age)
			}
		}
	}
}
