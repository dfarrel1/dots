// Tests that pin the work-CLI mass-rewrite bug surfaced 2026-05-21:
// `work pickup <new-track>` dirtied 23 unrelated sibling yamls because
// save() re-emits every loaded item via the Go yaml encoder, which
// doesn't preserve hand-authored styling (single vs double quotes,
// block-folded `>` vs literal `|`, blank-line separators inside
// multi-line scalars, field order, dropped unknown fields).
//
// The fix: load() snapshots the canonical-encoder form of each item it
// reads. writeItem() compares the current marshal of an item against
// that snapshot; if they match, the on-disk bytes are left untouched.
// Effect: only the items a command actually mutates get re-emitted.
//
// These tests pin the property at the file-byte level — distinct from
// field_preservation_test.go which only pins that schema fields survive
// marshal+unmarshal (a layer below file-byte preservation).
package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// quirkyYAML is a recently_completed row with the exact stylistic
// patterns that the Go yaml encoder mangles on re-emit: single-quoted
// strings, a block-folded `>` scalar with a blank line inside, and
// field order that differs from the struct definition. This is what
// hand-authored operator yaml looks like in practice — every release
// row in <tracker_dir>/recently_completed/ has at least
// one of these patterns.
const quirkyYAML = `name: handcrafted-release
owner: someone@example.org
picked_up_at: 2026-05-20T17:56:44Z
released_at: 2026-05-20T18:03:30Z
final_commit: 540faa07
notes: 'colon-laden: bump viewer_image past the parser fix. Released via --allow-unmerged.'
summary: >
  Bumped the viewer''s deployed image so the dashboard picks up
  four merged-but-undeployed changes — most importantly the parser fix.

  Deploy ledger appended with the new SHA; the previous image stays as
  the one-step rollback target.
`

// TestMassRewrite_UntouchedFilesStayByteIdentical pins the bug: after
// `work pickup` (or any other command) writes a new track, sibling
// yamls that the command did not mutate must be byte-identical on disk
// to what they were before. Pre-fix this test would have failed
// because save() re-emitted every loaded item.
func TestMassRewrite_UntouchedFilesStayByteIdentical(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	// Plant the hand-authored quirky yaml under recently_completed/.
	rcDir, err := subdirPath(subdirRecentlyCompleted)
	if err != nil {
		t.Fatalf("subdirPath: %v", err)
	}
	rcFile := filepath.Join(rcDir, "handcrafted-release.yaml")
	if err := os.WriteFile(rcFile, []byte(quirkyYAML), 0o644); err != nil {
		t.Fatalf("plant quirky yaml: %v", err)
	}
	originalBytes, err := os.ReadFile(rcFile)
	if err != nil {
		t.Fatalf("read original: %v", err)
	}

	// Load (which snapshots the canonical form of every loaded item),
	// then mutate a different list (add a new active track), then save.
	tr, _, err := load()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	// Sanity: load found the planted release.
	if len(tr.RecentlyCompleted) != 1 || tr.RecentlyCompleted[0].Name != "handcrafted-release" {
		t.Fatalf("load did not surface planted release: got %+v", tr.RecentlyCompleted)
	}
	// Sanity: the planted Summary survived load → no schema regression.
	if tr.RecentlyCompleted[0].Summary == "" {
		t.Fatalf("Summary was dropped on load — schema field missing")
	}

	tr.Tracks = append(tr.Tracks, Track{
		Name:           "new-pickup",
		Owner:          "operator@example.org",
		PickedUpAt:     time.Date(2026, 5, 21, 13, 0, 0, 0, time.UTC),
		LastActivityAt: time.Date(2026, 5, 21, 13, 0, 0, 0, time.UTC),
		Status:         "active",
	})
	if err := save(tr, ""); err != nil {
		t.Fatalf("save: %v", err)
	}

	// The untouched file must be byte-identical.
	afterBytes, err := os.ReadFile(rcFile)
	if err != nil {
		t.Fatalf("read after save: %v", err)
	}
	if !bytes.Equal(originalBytes, afterBytes) {
		t.Errorf("untouched recently_completed file was rewritten by save()"+
			"\n--- original ---\n%s\n--- after ---\n%s",
			originalBytes, afterBytes)
	}

	// The new track must have been written.
	newTrackFp := filepath.Join("docs/project/active-work/tracks", "new-pickup.yaml")
	if _, err := os.Stat(newTrackFp); err != nil {
		t.Errorf("new track was not written: %v", err)
	}
}

// TestMassRewrite_MutatedItemStillGetsWritten guards the inverse: a
// load-time snapshot must not suppress a write when the item was
// actually mutated in memory.
func TestMassRewrite_MutatedItemStillGetsWritten(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	rcDir, err := subdirPath(subdirRecentlyCompleted)
	if err != nil {
		t.Fatalf("subdirPath: %v", err)
	}
	rcFile := filepath.Join(rcDir, "handcrafted-release.yaml")
	if err := os.WriteFile(rcFile, []byte(quirkyYAML), 0o644); err != nil {
		t.Fatalf("plant quirky yaml: %v", err)
	}

	tr, _, err := load()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	// Actually mutate the release row's Notes — this must reach disk.
	tr.RecentlyCompleted[0].Notes = "post-merge correction"
	if err := save(tr, ""); err != nil {
		t.Fatalf("save: %v", err)
	}

	got, err := os.ReadFile(rcFile)
	if err != nil {
		t.Fatalf("read after save: %v", err)
	}
	if !bytes.Contains(got, []byte("post-merge correction")) {
		t.Errorf("mutation was silently suppressed; file:\n%s", got)
	}
}

// TestMassRewrite_NewItemWrittenCleanly guards that an item that did
// not exist at load time still gets written on save — the snapshot
// map only suppresses re-writes for items that WERE loaded and remain
// byte-identical.
func TestMassRewrite_NewItemWrittenCleanly(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()

	tr := &Tracker{
		SchemaVersion: currentSchemaVersion,
		Tracks: []Track{{
			Name:           "fresh",
			Owner:          "operator@example.org",
			PickedUpAt:     time.Date(2026, 5, 21, 13, 0, 0, 0, time.UTC),
			LastActivityAt: time.Date(2026, 5, 21, 13, 0, 0, 0, time.UTC),
			Status:         "active",
		}},
	}
	if err := save(tr, ""); err != nil {
		t.Fatalf("save: %v", err)
	}
	if _, err := os.Stat(filepath.Join("docs/project/active-work/tracks", "fresh.yaml")); err != nil {
		t.Errorf("fresh track not written: %v", err)
	}
}
