// Tests for the fail-closed behaviour around track files load() cannot read.
//
// The bug these pin down: readItemsAs deliberately SKIPS an unparseable file
// so one bad yaml cannot blind `work list` (). But a skipped item is
// absent from the in-memory slice, and syncSubdir's orphan GC deletes any
// on-disk .yaml no in-memory item names — so "skip on read" silently became
// "delete on write". An ACTIVE track carrying a handoff baton and
// operator-authorized destructive steps was lost to exactly that, via a
// duplicate `notes:` key.
//
// The contract asserted here: reads stay resilient, writes fail closed, and
// the file survives either way.
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// duplicateKeyTrack is a track file that is valid-looking to the eye and
// invalid to a strict yaml parser: `notes:` appears twice. This is the real
// shape that caused the loss — a handoff baton appended below an existing
// note — not a synthetic garbage string.
const duplicateKeyTrack = `name: budget-reconciliation
owner: someone@example.com
status: active
notes: self-block 10->100 first; then lifecycle classes
mode: master
notes: 'HANDOFF: read the tee-up doc first; deletion is operator-gated'
`

// writeTrackFile drops a raw file into active-work/tracks/ without going
// through save(), so the test controls the exact bytes on disk.
func writeTrackFile(t *testing.T, repo, name, body string) string {
	t.Helper()
	dir := filepath.Join(repo, "docs", "project", "active-work", "tracks")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir tracks: %v", err)
	}
	fp := filepath.Join(dir, name+".yaml")
	if err := os.WriteFile(fp, []byte(body), 0o644); err != nil {
		t.Fatalf("write %s: %v", fp, err)
	}
	return fp
}

// TestSaveRefusesWhenATrackFileIsUnparseable is the regression test proper:
// after loading a directory containing a duplicate-key track, save() must
// refuse, and the file must still be on disk afterwards.
func TestSaveRefusesWhenATrackFileIsUnparseable(t *testing.T) {
	repo, restore := fakeRepo(t)
	defer restore()

	bad := writeTrackFile(t, repo, "budget-reconciliation", duplicateKeyTrack)

	tr, dir, err := load()
	if err != nil {
		t.Fatalf("load() must tolerate an unparseable file, got: %v", err)
	}

	err = save(tr, dir)
	if err == nil {
		t.Fatal("save() returned nil after loading an unparseable track — it must refuse, " +
			"because syncSubdir would GC the file it never parsed")
	}

	// The message has to be actionable: name the file, quote the parse
	// error, and say what the operator should do about it.
	msg := err.Error()
	for _, want := range []string{
		"budget-reconciliation.yaml", // which file
		"already defined",            // the verbatim yaml parse error
		"DUPLICATE KEY",              // the usual cause, named
		"Merge the values",           // what to do instead of deleting one
	} {
		if !strings.Contains(msg, want) {
			t.Errorf("refusal message missing %q; got:\n%s", want, msg)
		}
	}

	// The whole point: the file is still there.
	if _, statErr := os.Stat(bad); statErr != nil {
		t.Fatalf("the unparseable track was deleted despite the refusal: %v", statErr)
	}
}

// TestUnparseableTrackSurvivesOrphanGC pins the belt-and-braces half. Even
// if a mutation path reaches syncSubdir directly, a file that failed to
// parse is not an orphan — its absence from the in-memory set proves
// nothing, because this process never saw its contents.
func TestUnparseableTrackSurvivesOrphanGC(t *testing.T) {
	repo, restore := fakeRepo(t)
	defer restore()

	bad := writeTrackFile(t, repo, "budget-reconciliation", duplicateKeyTrack)

	if _, _, err := load(); err != nil {
		t.Fatalf("load: %v", err)
	}

	// An empty item set names nothing, so every on-disk file looks like an
	// orphan to the GC. The protected set must save this one.
	if err := syncSubdir(subdirTracks, []Track{}, func(it Track) string { return it.Name }); err != nil {
		t.Fatalf("syncSubdir: %v", err)
	}
	if _, statErr := os.Stat(bad); statErr != nil {
		t.Fatalf("orphan GC deleted a track it never parsed: %v", statErr)
	}
}

// TestParseableTracksStillLoadAlongsideABadOne guards the property in
// the other direction: the refusal must not have turned reads brittle. One
// bad file cannot hide the good ones.
func TestParseableTracksStillLoadAlongsideABadOne(t *testing.T) {
	repo, restore := fakeRepo(t)
	defer restore()

	writeTrackFile(t, repo, "budget-reconciliation", duplicateKeyTrack)
	writeTrackFile(t, repo, "healthy-track", "name: healthy-track\nowner: a@b.c\nstatus: active\n")

	tr, _, err := load()
	if err != nil {
		t.Fatalf("load() must not fail on a mixed directory: %v", err)
	}
	var found bool
	for _, tk := range tr.Tracks {
		if tk.Name == "healthy-track" {
			found = true
		}
	}
	if !found {
		t.Error("the parseable track was not loaded — one bad file must not blind reads")
	}
}

// TestSaveSucceedsOnACleanDirectory is the control. Without it, a save()
// that refused unconditionally would pass every test above.
func TestSaveSucceedsOnACleanDirectory(t *testing.T) {
	repo, restore := fakeRepo(t)
	defer restore()

	writeTrackFile(t, repo, "healthy-track", "name: healthy-track\nowner: a@b.c\nstatus: active\n")

	tr, dir, err := load()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if err := save(tr, dir); err != nil {
		t.Fatalf("save() must succeed when every file parsed: %v", err)
	}
	if _, statErr := os.Stat(filepath.Join(
		repo, "docs", "project", "active-work", "tracks", "healthy-track.yaml",
	)); statErr != nil {
		t.Fatalf("clean save lost a track: %v", statErr)
	}
}
