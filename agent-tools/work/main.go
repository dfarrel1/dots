// work — concurrency-governance CLI for the active-work tracker.
//
// Paths come from the repo's .claude/agent-workflow.yaml (config.go); with no
// marker, or no key, the defaults are docs/project/active-work for the
// tracker, ops/work/roles for role prompts and .claude/worktrees for
// per-session worktrees. README.md beside this file is end-to-end usage.
//
// Track subcommands (per-actor work):
//
//	work pickup <track> [--scope ...] [--eta ...] [--note ...] [--cluster ...]
//	work update <track> [--status ...] [--scope ...] [--note ...] [--cluster ...]
//	work release <track> [--final-commit <sha>]
//	work list [--owner <s>] [--status <s>] [--cluster <s>]
//	work check-stale [--threshold <dur>]
//	work whoami
//	work commit <track> -m <msg> [-- <git args>]
//
// Cluster subcommands (multi-track captaincy, ):
//
//	work cluster register <name> --captain <agent_id> --scope <blocks>
//	                              [--kickoff-memo <path>] [--note ...]
//	work cluster status <name>           Rollup: cluster metadata + linked tracks.
//	work cluster list                    All registered clusters.
//	work cluster update <name> [--status ...] [--note ...] [--scope ...]
//	work cluster release <name>
//
// Role subcommands (load role-prompts at agent boot):
//
//	work role list                       Available role-prompts in the roles dir.
//	work role load <role>                Print role-prompt content to stdout.
//
// File-claim subcommands (file-grain conflict avoidance complementing track-grain):
//
//	work file claim <path> --until <when> [--note ...] [--track ...]
//	work file release <path>
//	work file list
//
// Decision subcommands (cross-cluster decision-deduplication, design §6.5b):
//
//	work decisions pending               List open decisions across clusters.
//	work decisions raise --summary <s> [--cluster ...] [--options "a,b,c"]
//	work decisions resolve <id> --resolution <s>
//
// All commands operate on the tracker directory relative to the nearest
// ancestor directory containing a .git marker (the repo root), so the CLI is
// invocable from anywhere inside the worktree.
//
// Role-prompts live at <roles_dir>/<name>.md. The directory may not exist;
// `work role list` then returns "(no role-prompts)" rather than failing.

package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const (
	// The tracker directory, its legacy monolithic file (<tracker_dir>.yaml,
	// kept as a sentinel: `load()` refuses to start while it exists) and the
	// roles directory come from the repo's config (config.go).

	// Subdirectory names under the tracker directory. Each subdirectory holds
	// one yaml file per item — no list wrapping. Concurrent edits to
	// different items touch different files = no merge conflicts.
	subdirTracks            = "tracks"
	subdirRecentlyCompleted = "recently_completed"
	subdirQueued            = "queued"
	subdirClusters          = "clusters"
	subdirFileClaims        = "file_claims"
	subdirPendingDecisions  = "pending_decisions"

	// Schema-version sentinel. Plain text (not yaml) so it can't pick up
	// stray fields. Bump on incompatible layout changes.
	schemaVersionFile    = "_schema_version"
	currentSchemaVersion = 2
)

// ----------------------------------------------------------------------
// schema

type SweepEntry struct {
	Commit     string `yaml:"commit"`
	Annotation string `yaml:"annotation,omitempty"`
	Direction  string `yaml:"direction,omitempty"`
	Note       string `yaml:"note,omitempty"`
}

type Track struct {
	Name           string       `yaml:"name"`
	Owner          string       `yaml:"owner"`
	PickedUpAt     time.Time    `yaml:"picked_up_at"`
	LastActivityAt time.Time    `yaml:"last_activity_at"`
	Scope          []string     `yaml:"scope,omitempty"`
	Status         string       `yaml:"status"`
	ETA            string       `yaml:"eta,omitempty"`
	Notes          string       `yaml:"notes,omitempty"`
	CrossRefs      []string     `yaml:"cross_refs,omitempty"`
	Cluster        string       `yaml:"cluster,omitempty"`
	CommitsSwept   []SweepEntry `yaml:"commits_swept,omitempty"`
	// Session isolation: mode + worktree/branch/host
	// fields auto-detected at pickup time; expose where the work is happening
	// to other concurrent sessions. All optional + omitempty so legacy tracks
	// stay valid without a schema migration.
	Mode         string `yaml:"mode,omitempty"`          // "worktree" | "master" — empty = legacy/unknown
	WorktreePath string `yaml:"worktree_path,omitempty"` // relative to repo root for child; "<master>" sentinel for master
	Branch       string `yaml:"branch,omitempty"`        // branch the work is on (e.g. "track/<name>" or "main")
	Host         string `yaml:"host,omitempty"`          // hostname where the work is happening
}

type Completed struct {
	Name         string    `yaml:"name"`
	Owner        string    `yaml:"owner"`
	PickedUpAt   time.Time `yaml:"picked_up_at"`
	ReleasedAt   time.Time `yaml:"released_at"`
	FinalCommit  string    `yaml:"final_commit,omitempty"`
	FinalCommits []string  `yaml:"final_commits,omitempty"` // plural form when a release spans multiple commits
	Notes        string    `yaml:"notes,omitempty"`
	// Summary is the closeout narrative — plain-English goal/work/result per
	// CLAUDE.md concurrency-governance §"On release, fill the summary field".
	// Schema gap surfaced 2026-05-13: prior versions of this struct dropped
	// the field on every pickup re-serialize, silently clobbering operator
	// closeout text. Round-trip preservation covered by
	// field_preservation_test.go.
	Summary      string       `yaml:"summary,omitempty"`
	Cluster      string       `yaml:"cluster,omitempty"`
	CommitsSwept []SweepEntry `yaml:"commits_swept,omitempty"`
}

type Cluster struct {
	Name           string    `yaml:"name"`
	Captain        string    `yaml:"captain"`
	Scope          []string  `yaml:"scope,omitempty"`
	Status         string    `yaml:"status"`
	PickedUpAt     time.Time `yaml:"picked_up_at"`
	LastActivityAt time.Time `yaml:"last_activity_at"`
	KickoffMemo    string    `yaml:"kickoff_memo,omitempty"`
	Notes          string    `yaml:"notes,omitempty"`
}

type FileClaim struct {
	Path      string    `yaml:"path"`
	Owner     string    `yaml:"owner"`
	ClaimedAt time.Time `yaml:"claimed_at"`
	Until     time.Time `yaml:"until"`
	Track     string    `yaml:"track,omitempty"`
	Note      string    `yaml:"note,omitempty"`
}

type PendingDecision struct {
	ID         string    `yaml:"id"`
	Summary    string    `yaml:"summary"`
	RaisedBy   string    `yaml:"raised_by,omitempty"`
	Cluster    string    `yaml:"cluster,omitempty"`
	Options    []string  `yaml:"options,omitempty"`
	RaisedAt   time.Time `yaml:"raised_at"`
	Status     string    `yaml:"status"`
	Resolution string    `yaml:"resolution,omitempty"`
	ResolvedAt time.Time `yaml:"resolved_at,omitempty"`
}

type QueuedItem struct {
	Name       string    `yaml:"name"`
	Why        string    `yaml:"why,omitempty"`
	Source     string    `yaml:"source,omitempty"`
	GatedOn    string    `yaml:"gated_on,omitempty"`
	Notes      string    `yaml:"notes,omitempty"`
	SurfacedAt time.Time `yaml:"surfaced_at,omitempty"`
}

type Tracker struct {
	SchemaVersion     int               `yaml:"schema_version"`
	Tracks            []Track           `yaml:"tracks"`
	Queued            []QueuedItem      `yaml:"queued,omitempty"`
	Clusters          []Cluster         `yaml:"clusters,omitempty"`
	FileClaims        []FileClaim       `yaml:"file_claims,omitempty"`
	PendingDecisions  []PendingDecision `yaml:"pending_decisions,omitempty"`
	RecentlyCompleted []Completed       `yaml:"recently_completed"`
}

// ----------------------------------------------------------------------
// load / save

// loadedItemCanonical caches the canonical marshaled form of each item as
// it appeared on disk at load() time, keyed by "sub/name". writeItem
// consults this map: if the current marshal of an item equals its
// load-time marshal, the file is left untouched on disk. Without this,
// every command rewrites every yaml in active-work/ because the Go yaml
// encoder doesn't reproduce hand-authored styling (quote style, > vs |,
// blank-line separators, field order on round-trip) — turning a one-item
// mutation into a 23-file dirty working tree.
//
// Reset on every load() so test isolation holds.
var loadedItemCanonical = map[string][]byte{}

// unreadableItem records a file under the tracker dir that load() could not
// turn into an item — either unreadable or unparseable yaml.
type unreadableItem struct {
	path string // full path, for a message a human can act on
	err  error  // the read or parse error, verbatim
}

// unreadableItems collects those files, keyed by subdir.
//
// WHY THIS EXISTS. readItemsAs deliberately skips a file it cannot parse
// rather than aborting: showed that one malformed queued file
// exit-1'd every command and blinded `work list` for unrelated PRs. But a
// skipped file is absent from the in-memory slice, and syncSubdir's orphan
// GC deletes any on-disk .yaml that no in-memory item names — so "skip on
// read" silently became "delete on write". That is not hypothetical: a
// duplicate `notes:` key in an ACTIVE track carrying a handoff baton and
// operator-authorized destructive steps made every pickup and release drop
// it from the concurrency-governance surface.
//
// Skipping is still right for read-only commands, so this map keeps both
// properties: reads stay resilient, and save() consults it to refuse
// outright rather than persist a directory it could not fully read.
// syncSubdir additionally treats these names as protected, so even a future
// mutation path that bypasses the refusal cannot GC a file it never parsed.
//
// Reset on every load() so test isolation holds.
var unreadableItems = map[string][]unreadableItem{}

// marshalItem produces the canonical yaml bytes for an item using the
// 2-space-indent encoder. Used at load time (to snapshot the form each
// loaded item would take on re-emission) and at write time (to compare
// against that snapshot). The two callers MUST use byte-identical encoder
// settings or the snapshot comparison would always fail.
func marshalItem(item any) ([]byte, error) {
	var buf bytes.Buffer
	enc := yaml.NewEncoder(&buf)
	enc.SetIndent(2)
	if err := enc.Encode(item); err != nil {
		return nil, errors.Join(err, enc.Close())
	}
	if err := enc.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func repoRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for d := cwd; ; {
		if _, err := os.Stat(filepath.Join(d, ".git")); err == nil {
			return d, nil
		}
		parent := filepath.Dir(d)
		if parent == d {
			return "", fmt.Errorf("not inside a git worktree (no .git/ ancestor of %s)", cwd)
		}
		d = parent
	}
}

func trackerPath() (string, error) {
	root, err := repoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, cfg().legacyTrackerRelPath()), nil
}

// trackerDir returns the per-track-files directory (the source of truth).
func trackerDir() (string, error) {
	root, err := repoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, cfg().TrackerDir), nil
}

// subdirPath returns trackerDir + sub, ensuring the directory exists.
// Pickup/release commands call this lazily; tests + migration use it too.
func subdirPath(sub string) (string, error) {
	dir, err := trackerDir()
	if err != nil {
		return "", err
	}
	p := filepath.Join(dir, sub)
	if err := os.MkdirAll(p, 0o755); err != nil {
		return "", fmt.Errorf("mkdir %s: %w", p, err)
	}
	return p, nil
}

// itemFilename sanitizes an item name into a filename. Names are already
// kebab-case by convention; this enforces the invariant + protects against
// path traversal (no '/', no '..').
func itemFilename(name string) (string, error) {
	if name == "" {
		return "", fmt.Errorf("empty item name")
	}
	if strings.ContainsAny(name, "/\\\x00") || name == "." || name == ".." {
		return "", fmt.Errorf("invalid item name %q", name)
	}
	return name + ".yaml", nil
}

// readItemsAs globs trackerDir/sub and unmarshals each yaml file into a
// fresh T. Returns the slice sorted by filename for stable ordering.
// Files starting with "_" (e.g. _schema_version) are skipped.
func readItemsAs[T any](sub string) ([]T, error) {
	dir, err := trackerDir()
	if err != nil {
		return nil, err
	}
	p := filepath.Join(dir, sub)
	entries, err := os.ReadDir(p)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("readdir %s: %w", p, err)
	}
	var out []T
	for _, e := range entries {
		if e.IsDir() || strings.HasPrefix(e.Name(), "_") || !strings.HasSuffix(e.Name(), ".yaml") {
			continue
		}
		fp := filepath.Join(p, e.Name())
		b, err := os.ReadFile(fp)
		if err != nil {
			// One unreadable file must not blind the whole command —
			// list/pickup/release operate on OTHER items. Surface it
			// LOUDLY (not a silent skip —) and carry on. Recorded
			// so save() refuses rather than GC'ing what it never read.
			fmt.Fprintf(os.Stderr, "  warning: skipping unreadable %s: %v\n", fp, err)
			unreadableItems[sub] = append(unreadableItems[sub], unreadableItem{path: fp, err: err})
			continue
		}
		var item T
		if err := yaml.Unmarshal(b, &item); err != nil {
			// A single malformed yaml (e.g. a hand-edited track with a
			// typo) used to abort load() and exit-1 the whole command —
			// one bad queued file blinded `work list` and broke the
			// ops-go bats gate for unrelated PRs ( surfaced this).
			// Skip it loudly and keep listing everything parseable.
			// Recorded so save() refuses: skipping keeps READS working,
			// but persisting after a skip would let syncSubdir's orphan
			// GC delete a track this process never managed to parse.
			fmt.Fprintf(os.Stderr, "  warning: skipping unparseable %s: %v\n", fp, err)
			unreadableItems[sub] = append(unreadableItems[sub], unreadableItem{path: fp, err: err})
			continue
		}
		// Snapshot the canonical (encoder-2-space) form of the item as it
		// appeared on load. writeItem compares against this to leave the
		// on-disk bytes alone when the in-memory item is unchanged.
		if canon, mErr := marshalItem(item); mErr == nil {
			name := strings.TrimSuffix(e.Name(), ".yaml")
			loadedItemCanonical[sub+"/"+name] = canon
		}
		out = append(out, item)
	}
	return out, nil
}

// writeItem marshals a single item to trackerDir/sub/<name>.yaml. Writes
// only when bytes change vs disk — concurrent PRs editing different items
// produce zero git churn on unchanged items.
func writeItem(sub, name string, item any) error {
	fname, err := itemFilename(name)
	if err != nil {
		return err
	}
	subDir, err := subdirPath(sub)
	if err != nil {
		return err
	}
	// Encoder pinned to 2-space indent (matches hand-authored convention).
	// See marshalItem doc for why load + write MUST share encoder settings.
	out, err := marshalItem(item)
	if err != nil {
		return fmt.Errorf("marshal %s/%s: %w", sub, name, err)
	}
	// Load-time snapshot check: if the in-memory item still produces the
	// same canonical bytes as it did when read from disk, the command did
	// not semantically mutate this item — leave on-disk bytes untouched so
	// hand-authored yaml styling (quote style, > vs |, blank-line
	// separators) survives. Closes the mass-rewrite bug where every
	// command rewrote every yaml because Go's yaml encoder doesn't
	// reproduce hand-authored styling. (Diagnosed 2026-05-21 when `work
	// pickup` of a single new track dirtied 23 sibling yamls.)
	if canon, ok := loadedItemCanonical[sub+"/"+name]; ok && bytesEqual(canon, out) {
		return nil // item unchanged since load — preserve on-disk bytes
	}
	fp := filepath.Join(subDir, fname)
	if existing, err := os.ReadFile(fp); err == nil && bytesEqual(existing, out) {
		return nil // unchanged — skip the write so file mtime + git see no churn
	}
	return os.WriteFile(fp, out, 0o644)
}

// deleteItem removes trackerDir/sub/<name>.yaml. No-op if missing.
func deleteItem(sub, name string) error {
	fname, err := itemFilename(name)
	if err != nil {
		return err
	}
	dir, err := trackerDir()
	if err != nil {
		return err
	}
	fp := filepath.Join(dir, sub, fname)
	if err := os.Remove(fp); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("rm %s: %w", fp, err)
	}
	return nil
}

func bytesEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// itemFilePath returns the absolute path trackerDir/sub/<name>.yaml — the
// exact file writeItem/deleteItem act on for a single item. Used by
// stageRecordOrWarn to know precisely what to `git add`.
func itemFilePath(sub, name string) (string, error) {
	fname, err := itemFilename(name)
	if err != nil {
		return "", err
	}
	dir, err := trackerDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, sub, fname), nil
}

// gitAddPath stages exactly one file via `git add -- <path>`. Never a glob
// or directory — scoping to a single known path is what keeps this safe
// under a shared working tree: multiple agent
// sessions share one .git/index, and a sweeping `git add` pattern silently
// scoops up other sessions' in-flight files. Adding a single path this
// process just wrote (or just deleted — git stages the removal too, for a
// path already tracked) cannot do that.
func gitAddPath(path string) error {
	cmd := exec.Command("git", "add", "--", path)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

// stageRecordOrWarn runs `git add` on the governance record this command
// just wrote (trackerDir/sub/<name>.yaml). Fixes #1354: `work pickup` and
// `work release` used to only print "remember to: git add ..." after
// writing the record, never actually staging it. An untracked record that
// origin/main's history also wants to create aborts a later `git pull` with
// "untracked working tree files would be overwritten by merge" — and worse,
// a governance record nobody committed is not a durable record at all (see
// the #2773 recovery the issue cites). Staging only — the commit itself is
// still the operator's/caller's step, same as the existing `work commit
// --paths` flow.
//
// Best-effort: a staging failure (e.g. git unavailable) must not fail the
// command whose real job already succeeded — it falls back to the old
// "remember to" reminder so the operator isn't left silently stranded.
func stageRecordOrWarn(sub, name, verb string) {
	fp, err := itemFilePath(sub, name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: could not resolve %s record path to stage: %v\n", verb, err)
		return
	}
	if err := gitAddPath(fp); err != nil {
		fmt.Fprintf(os.Stderr, "warning: could not stage %s (%v)\n", fp, err)
		fmt.Fprintln(os.Stderr, "  remember to: git add", fp, "&& git commit -m \"chore(work):", verb, name+"\"")
		return
	}
	fmt.Fprintln(os.Stderr, "staged (git add):", fp)
	fmt.Fprintln(os.Stderr, "  remember to: git commit -m \"chore(work):", verb, name+"\"")
}

// The completed record replaces the active record. Stage the deletion too,
// but only if Git already tracks this exact path; never stage sibling records.
func stageReleasedTrackDeletionOrWarn(name string) {
	fp, err := itemFilePath(subdirTracks, name)
	if err == nil {
		var tracked []byte
		tracked, err = exec.Command("git", "ls-files", "-z", "--", fp).Output()
		if err == nil && len(tracked) == 0 {
			return
		}
		if err == nil {
			err = gitAddPath(fp)
		}
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: could not stage released track deletion: %v; stage the deletion of track %q before committing\n", err, name)
	}
}

func rolesDir() (string, error) {
	root, err := repoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, cfg().RolesDir), nil
}

// load assembles the Tracker from per-item yaml files under trackerDir.
// Returns the Tracker plus the trackerDir path (the second return is kept
// in the signature for compatibility — callers use it only as the "where"
// reference in error messages).
//
// If the legacy monolithic file still exists, load refuses to proceed and
// prints the migration command. This catches half-migrated checkouts before
// a save() wipes the legacy file.
func load() (*Tracker, string, error) {
	// Reset the load-time snapshot map. Tests run multiple load() calls
	// in the same process; without this a previous test's snapshot could
	// suppress a legitimate write in the next test. Production CLI is
	// short-lived (one load per process), so the reset is free.
	loadedItemCanonical = map[string][]byte{}
	unreadableItems = map[string][]unreadableItem{}

	dir, err := trackerDir()
	if err != nil {
		return nil, "", err
	}
	if legacy, lerr := trackerPath(); lerr == nil {
		if _, sterr := os.Stat(legacy); sterr == nil {
			return nil, dir, fmt.Errorf(
				"legacy monolithic %s still present alongside per-track-files dir %s — "+
					"run `work migrate` to split it (one-time, idempotent), then `rm %s`",
				legacy, dir, legacy)
		}
	}

	t := &Tracker{SchemaVersion: currentSchemaVersion}

	// Schema-version sentinel — read if present, else default to current.
	if vb, err := os.ReadFile(filepath.Join(dir, schemaVersionFile)); err == nil {
		v := strings.TrimSpace(string(vb))
		if v == "1" {
			t.SchemaVersion = 1
		} else if v == "2" {
			t.SchemaVersion = 2
		}
	}

	if tracks, err := readItemsAs[Track](subdirTracks); err == nil {
		t.Tracks = tracks
	} else {
		return nil, dir, err
	}
	if completed, err := readItemsAs[Completed](subdirRecentlyCompleted); err == nil {
		t.RecentlyCompleted = completed
	} else {
		return nil, dir, err
	}
	if queued, err := readItemsAs[QueuedItem](subdirQueued); err == nil {
		t.Queued = queued
	} else {
		return nil, dir, err
	}
	if clusters, err := readItemsAs[Cluster](subdirClusters); err == nil {
		t.Clusters = clusters
	} else {
		return nil, dir, err
	}
	if claims, err := readItemsAs[FileClaim](subdirFileClaims); err == nil {
		t.FileClaims = claims
	} else {
		return nil, dir, err
	}
	if decisions, err := readItemsAs[PendingDecision](subdirPendingDecisions); err == nil {
		t.PendingDecisions = decisions
	} else {
		return nil, dir, err
	}
	return t, dir, nil
}

// save writes each item to its own file under trackerDir. Items present
// in the Tracker but missing on disk are created; items present on disk
// but missing in the Tracker are deleted. Unchanged items are skipped
// (byte-identical content → no write → no git churn → no merge conflict
// for concurrent edits to different items).
//
// The `path` argument is unused but retained in the signature so the
// dozens of existing callers don't need to be touched.
// errUnreadableItems builds the refusal save() returns when load() could not
// read or parse everything under the tracker dir. It names every offending
// file and its verbatim error, because "something is malformed" is not a
// message anyone can act on.
func errUnreadableItems() error {
	var b strings.Builder
	b.WriteString("refusing to write active-work: this process could not read every track file.\n\n")
	for _, sub := range []string{
		subdirTracks, subdirRecentlyCompleted, subdirQueued,
		subdirClusters, subdirFileClaims, subdirPendingDecisions,
	} {
		for _, u := range unreadableItems[sub] {
			fmt.Fprintf(&b, "  %s\n      %v\n", u.path, u.err)
		}
	}
	b.WriteString("\nWriting now would DELETE the file(s) above. Items are written from the\n")
	b.WriteString("in-memory set and any on-disk .yaml that set does not name is garbage-\n")
	b.WriteString("collected as an orphan — so a file skipped at read time is removed at\n")
	b.WriteString("write time. An active track has been lost to exactly this before.\n\n")
	b.WriteString("Fix the file(s) and re-run. The usual cause is a DUPLICATE KEY (yaml\n")
	b.WriteString("rejects a mapping key defined twice) — often a second `notes:` added by\n")
	b.WriteString("a handoff on top of an original. Merge the values into one key rather\n")
	b.WriteString("than deleting either.\n\n")
	b.WriteString("Read-only commands (`work list`, `work bus`) still run: they skip the\n")
	b.WriteString("file loudly and show you everything else.")
	return fmt.Errorf("%s", b.String())
}

func save(t *Tracker, _ string) error {
	// FAIL CLOSED on anything load() could not read. Reads tolerate a bad
	// file (); writes must not, because syncSubdir's orphan GC would
	// delete it. See unreadableItems for the incident this prevents.
	for _, us := range unreadableItems {
		if len(us) > 0 {
			return errUnreadableItems()
		}
	}

	// Ensure all subdirs exist (lazy mkdir for first-time use).
	for _, sub := range []string{
		subdirTracks, subdirRecentlyCompleted, subdirQueued,
		subdirClusters, subdirFileClaims, subdirPendingDecisions,
	} {
		if _, err := subdirPath(sub); err != nil {
			return err
		}
	}

	// Schema version sentinel (rare write; only changes on layout bumps).
	dir, err := trackerDir()
	if err != nil {
		return err
	}
	if err := os.WriteFile(
		filepath.Join(dir, schemaVersionFile),
		[]byte(fmt.Sprintf("%d\n", currentSchemaVersion)),
		0o644,
	); err != nil {
		return err
	}

	// Write each item, then delete any per-subdir orphans not in t.
	if err := syncSubdir(subdirTracks, t.Tracks, func(it Track) string { return it.Name }); err != nil {
		return err
	}
	if err := syncSubdir(subdirRecentlyCompleted, t.RecentlyCompleted, func(it Completed) string { return it.Name }); err != nil {
		return err
	}
	if err := syncSubdir(subdirQueued, t.Queued, func(it QueuedItem) string { return it.Name }); err != nil {
		return err
	}
	if err := syncSubdir(subdirClusters, t.Clusters, func(it Cluster) string { return it.Name }); err != nil {
		return err
	}
	if err := syncSubdir(subdirFileClaims, t.FileClaims, fileClaimKey); err != nil {
		return err
	}
	if err := syncSubdir(subdirPendingDecisions, t.PendingDecisions, func(it PendingDecision) string { return it.ID }); err != nil {
		return err
	}
	return nil
}

// syncSubdir writes each item under sub/ using nameOf(item) as the filename
// stem, then removes any pre-existing .yaml file in sub/ that isn't named
// by some item in the slice. Both halves are skip-on-no-change.
func syncSubdir[T any](sub string, items []T, nameOf func(T) string) error {
	wanted := map[string]struct{}{}
	for _, it := range items {
		n := nameOf(it)
		if n == "" {
			continue
		}
		if err := writeItem(sub, n, it); err != nil {
			return err
		}
		wanted[n] = struct{}{}
	}
	// Garbage-collect orphans.
	dir, err := subdirPath(sub)
	if err != nil {
		return err
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	// A file load() could not read is NOT an orphan — it is a file whose
	// contents this process never saw. Absence from `wanted` proves nothing
	// about it. save() already refuses outright in that case; this is the
	// belt to that braces, so no future mutation path can delete a track by
	// failing to parse it.
	protected := map[string]struct{}{}
	for _, u := range unreadableItems[sub] {
		protected[strings.TrimSuffix(filepath.Base(u.path), ".yaml")] = struct{}{}
	}
	for _, e := range entries {
		if e.IsDir() || strings.HasPrefix(e.Name(), "_") || !strings.HasSuffix(e.Name(), ".yaml") {
			continue
		}
		name := strings.TrimSuffix(e.Name(), ".yaml")
		if _, skip := protected[name]; skip {
			continue
		}
		if _, keep := wanted[name]; !keep {
			if err := os.Remove(filepath.Join(dir, e.Name())); err != nil {
				return err
			}
		}
	}
	return nil
}

// fileClaimKey turns a FileClaim.Path into a deterministic filename stem.
// Paths contain slashes; hash the full path and prefix with the basename
// so a human scanning the directory can still recognize the claim.
func fileClaimKey(fc FileClaim) string {
	h := sha256.Sum256([]byte(fc.Path))
	short := hex.EncodeToString(h[:4])
	base := filepath.Base(fc.Path)
	// Sanitize base — strip anything that's not a-zA-Z0-9._-
	clean := make([]byte, 0, len(base))
	for i := 0; i < len(base); i++ {
		c := base[i]
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-' {
			clean = append(clean, c)
		} else {
			clean = append(clean, '_')
		}
	}
	return short + "__" + string(clean)
}

// ----------------------------------------------------------------------
// owner helpers

func gitConfig(key string) string {
	out, err := exec.Command("git", "config", "--get", key).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// handleFromEmail reduces an address to its local part, which is what the rest
// of the repo means by an operator handle (ops/operators/<env>/<handle>.yml).
// "ada.lovelace@example.com" -> "ada.lovelace". A value with no "@" is already
// a handle and is returned unchanged.
func handleFromEmail(v string) string {
	if i := strings.IndexByte(v, '@'); i > 0 {
		return v[:i]
	}
	return v
}

// whoami answers "who holds this track". The answer is written into TRACKED
// YAML (docs/project/active-work/**), so it must not be a personal email
// address: measured 66 files in the working tree carrying third-party
// addresses, 25 of them generated here, which meant any PII scrub of this repo
// regenerated on the next `work pickup`.
//
// The fix is to record a HANDLE, which is the vocabulary the rest of the repo
// already uses and which answers the question better than an address does. The
// CLAUDE_SESSION_ID branch has always returned a non-email value, so nothing
// downstream ever assumed an address.
//
// Set WORK_LEGACY_EMAIL_OWNER=1 to restore the old behaviour for one command if
// some consumer turns out to need the full address; if you reach for it, that
// consumer is the bug.
func whoami() string {
	if v := os.Getenv("WORK_OWNER"); v != "" {
		return v
	}
	if v := os.Getenv("CLAUDE_SESSION_ID"); v != "" {
		return "claude:" + v
	}
	if e := gitConfig("user.email"); e != "" {
		if os.Getenv("WORK_LEGACY_EMAIL_OWNER") != "" {
			return e
		}
		return handleFromEmail(e)
	}
	if u, err := os.Hostname(); err == nil {
		return u
	}
	return "unknown"
}

// ----------------------------------------------------------------------
// arg helpers

type flagMap map[string]string

func parseFlags(args []string) (flagMap, []string) {
	flags := flagMap{}
	var positional []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--":
			positional = append(positional, args[i+1:]...)
			return flags, positional
		case strings.HasPrefix(a, "--") || (strings.HasPrefix(a, "-") && len(a) > 1):
			// `-m` and `--m` are equivalent — the README documents both
			// forms (`-m "msg"`, `--note "..."`), so the parser accepts
			// both. No combined short-flag form (`-abc`) — we don't need it.
			name := strings.TrimLeft(a, "-")
			val := ""
			if eq := strings.Index(name, "="); eq >= 0 {
				val = name[eq+1:]
				name = name[:eq]
			} else if i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
				val = args[i+1]
				i++
			} else {
				val = "true"
			}
			flags[name] = val
		default:
			positional = append(positional, a)
		}
	}
	return flags, positional
}

func splitCSV(s string) []string {
	if s == "" {
		return nil
	}
	out := []string{}
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func now() time.Time { return time.Now().UTC().Truncate(time.Second) }

// parseUntil accepts either an absolute RFC3339 timestamp or a relative
// duration like "2h" / "30m" / "1d". "1d" is interpreted as 24h.
func parseUntil(s string) (time.Time, error) {
	if s == "" {
		return time.Time{}, fmt.Errorf("--until required")
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.UTC(), nil
	}
	// Allow "1d" / "2d" since time.ParseDuration doesn't know "d".
	if strings.HasSuffix(s, "d") {
		n := strings.TrimSuffix(s, "d")
		var days int
		if _, err := fmt.Sscanf(n, "%d", &days); err == nil && days > 0 {
			return now().Add(time.Duration(days) * 24 * time.Hour), nil
		}
	}
	if d, err := time.ParseDuration(s); err == nil {
		return now().Add(d), nil
	}
	return time.Time{}, fmt.Errorf("--until %q: not RFC3339 timestamp or duration (e.g. 2h, 30m, 1d)", s)
}

// ----------------------------------------------------------------------
// track subcommands (existing behavior preserved)

func cmdPickup(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work pickup <track> [--scope p1,p2,...] [--eta 2h] [--note ...] [--cluster ...] [--master]")
	}
	name := pos[0]
	t, p, err := load()
	if err != nil {
		return err
	}
	for _, tr := range t.Tracks {
		if tr.Name == name {
			return fmt.Errorf("track %q already active (owner=%s, picked_up_at=%s)", name, tr.Owner, tr.PickedUpAt.Format(time.RFC3339))
		}
	}
	cluster := flags["cluster"]
	if cluster != "" {
		found := false
		for _, c := range t.Clusters {
			if c.Name == cluster {
				found = true
				break
			}
		}
		if !found {
			fmt.Fprintf(os.Stderr, "warning: --cluster %q is not a registered cluster (use `work cluster register` first)\n", cluster)
		}
	}
	// Auto-detect mode + worktree_path + branch + host from cwd.
	// --master flag forces master mode; otherwise infer from git-dir vs git-common-dir.
	mode, worktreePath, branch, host := detectWorktreeContext(flags)
	// if pickup is invoked from master cwd but a per-session worktree
	// already exists at the canonical path `.claude/worktrees/<track-name>` with
	// matching branch `track/<name>` checked out, the work is going to happen
	// in that worktree; record that so cleanup-on-release fires correctly at
	// release time. The iso skill creates the worktree before calling pickup,
	// so this is the common path. Operator can still force master via --master.
	if mode == "master" {
		if inferredPath, inferredBranch, ok := inferCanonicalWorktree(name); ok {
			mode = "worktree"
			worktreePath = inferredPath
			branch = inferredBranch
		}
	}
	tr := Track{
		Name:           name,
		Owner:          whoami(),
		PickedUpAt:     now(),
		LastActivityAt: now(),
		Scope:          splitCSV(flags["scope"]),
		Status:         "active",
		ETA:            flags["eta"],
		Notes:          flags["note"],
		CrossRefs:      splitCSV(flags["cross-refs"]),
		Cluster:        cluster,
		Mode:           mode,
		WorktreePath:   worktreePath,
		Branch:         branch,
		Host:           host,
	}
	t.Tracks = append(t.Tracks, tr)
	if err := save(t, p); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "appended track %q (owner=%s) to %s\n", name, tr.Owner, p)
	if mode != "" {
		fmt.Fprintf(os.Stderr, "  mode=%s", mode)
		if worktreePath != "" {
			fmt.Fprintf(os.Stderr, " worktree=%s", worktreePath)
		}
		if branch != "" {
			fmt.Fprintf(os.Stderr, " branch=%s", branch)
		}
		if host != "" {
			fmt.Fprintf(os.Stderr, " host=%s", host)
		}
		fmt.Fprintln(os.Stderr)
	}
	stageRecordOrWarn(subdirTracks, name, "pickup")
	return nil
}

// detectWorktreeContext infers (mode, worktree_path, branch, host) from the
// current working directory + `git worktree` state + hostname. Best-effort —
// returns empty strings if git isn't reachable so legacy / non-git invocations
// still register tracks.
func detectWorktreeContext(flags flagMap) (mode, worktreePath, branch, host string) {
	host, _ = os.Hostname() //nolint:errcheck // host metadata is optional

	// --master flag forces master mode without inspection
	if _, masterFlagSet := flags["master"]; masterFlagSet {
		mode = "master"
		worktreePath = "<master>"
		branch = cfg().Trunk
		return
	}

	// Detect master vs child worktree via git-dir == git-common-dir
	gitDir, err := runGitOutput("rev-parse", "--git-dir")
	if err != nil {
		return // not in a git repo; leave fields empty
	}
	commonDir, err := runGitOutput("rev-parse", "--git-common-dir")
	if err != nil {
		return
	}
	gitDirAbs := absPath(gitDir)
	commonDirAbs := absPath(commonDir)

	// Branch (best-effort)
	branchOut, _ := runGitOutput("symbolic-ref", "--quiet", "--short", "HEAD") //nolint:errcheck // detached or unavailable branch metadata is optional
	branch = branchOut

	if gitDirAbs == commonDirAbs {
		mode = "master"
		worktreePath = "<master>"
		return
	}
	mode = "worktree"
	// worktree_path = git rev-parse --show-toplevel relative to common-dir's repo root
	topLevel, err := runGitOutput("rev-parse", "--show-toplevel")
	if err == nil {
		// commonDir is typically <repo>/.git for the master worktree;
		// strip /.git suffix to get the master repo root
		repoRoot := commonDirAbs
		if strings.HasSuffix(repoRoot, "/.git") {
			repoRoot = strings.TrimSuffix(repoRoot, "/.git")
		}
		if rel, err := filepath.Rel(repoRoot, topLevel); err == nil {
			worktreePath = rel
		} else {
			worktreePath = topLevel
		}
	}
	return
}

// runGitOutput executes a git subcommand and returns its trimmed stdout.
func runGitOutput(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

// inferCanonicalWorktree checks whether a per-session worktree exists at
// `.claude/worktrees/<track-name>` with branch `track/<name>` checked out.
// Returns (worktreePath relative to repo root, full branch name, true) on
// match; ("", "", false) otherwise. lets pickup invoked
// from master cwd correctly record where the work is going to happen when
// the iso skill (or equivalent) has already provisioned the worktree.
func inferCanonicalWorktree(trackName string) (string, string, bool) {
	root, err := repoRoot()
	if err != nil {
		return "", "", false
	}
	rel := filepath.Join(cfg().WorktreesDir, trackName)
	abs := filepath.Join(root, rel)
	if _, err := os.Stat(abs); err != nil {
		return "", "", false
	}
	branch := "track/" + trackName
	cmd := exec.Command("git", "-C", abs, "symbolic-ref", "--quiet", "--short", "HEAD")
	out, err := cmd.Output()
	if err != nil {
		return "", "", false
	}
	if strings.TrimSpace(string(out)) != branch {
		return "", "", false
	}
	return rel, branch, true
}

// absPath returns the absolute path of p, or p unchanged on error.
func absPath(p string) string {
	if a, err := filepath.Abs(p); err == nil {
		return a
	}
	return p
}

func cmdUpdate(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work update <track> [--status active|blocked:R|review|done] [--scope ...] [--note ...] [--eta ...] [--cluster ...]")
	}
	name := pos[0]
	t, p, err := load()
	if err != nil {
		return err
	}
	for i := range t.Tracks {
		if t.Tracks[i].Name != name {
			continue
		}
		t.Tracks[i].LastActivityAt = now()
		if v := flags["status"]; v != "" {
			t.Tracks[i].Status = v
		}
		if v := flags["scope"]; v != "" {
			t.Tracks[i].Scope = splitCSV(v)
		}
		if v := flags["note"]; v != "" {
			t.Tracks[i].Notes = v
		}
		if v := flags["eta"]; v != "" {
			t.Tracks[i].ETA = v
		}
		if v, ok := flags["cluster"]; ok {
			t.Tracks[i].Cluster = v
		}
		if err := save(t, p); err != nil {
			return err
		}
		fmt.Fprintf(os.Stderr, "updated %q (status=%s)\n", name, t.Tracks[i].Status)
		return nil
	}
	return fmt.Errorf("no active track named %q", name)
}

func cmdRelease(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work release <track> [--final-commit <sha>] [--keep-worktree] [--allow-unmerged <reason>]")
	}
	name := pos[0]
	keepWorktree := flags["keep-worktree"] == "true" || flags["keep-worktree"] == "1"
	allowUnmergedReason := flags["allow-unmerged"]
	t, p, err := load()
	if err != nil {
		return err
	}
	for i, tr := range t.Tracks {
		if tr.Name != name {
			continue
		}

		// Verify branch content reached a remote trunk before marking
		// the track completed. The track's recorded Branch (set at pickup) is
		// the canonical reference; fall back to "track/<name>" if empty.
		// Skipped only when --allow-unmerged is passed with a reason string
		// (intentional abandonment is captured in the Notes field).
		branch := tr.Branch
		if branch == "" {
			branch = "track/" + name
		}
		notesAddendum := ""
		unmerged, mergeRemote, mergeCheckErr := unmergedCommits(branch)
		if mergeCheckErr != nil {
			fmt.Fprintf(os.Stderr, "  merge-check: skipped (%v)\n", mergeCheckErr)
		} else {
			//: when git-cherry (patch-id) reports unmerged commits,
			// double-check for a merged PR — a squash-merge defeats the
			// patch-id match even though the work is on main. Only query
			// gh when cherry is unhappy, to avoid a network call on the
			// common fast path.
			mergedViaPR := len(unmerged) > 0 && branchMergedViaPR(branch)
			switch mergeVerdict(len(unmerged), mergedViaPR, allowUnmergedReason) {
			case mergePass:
				if len(unmerged) == 0 {
					fmt.Fprintf(os.Stderr, "  merge-check: PASS — branch %s reachable from %s/%s\n", branch, mergeRemote, cfg().Trunk)
				} else {
					fmt.Fprintf(os.Stderr, "  merge-check: PASS — branch %s has a merged PR; %d commit(s) invisible to git-cherry (squash-merge)\n", branch, len(unmerged))
				}
			case mergeRefuse:
				return fmt.Errorf(
					"refuse: branch %q has %d commit(s) not on origin/main and no merged PR found:\n%s\n"+
						"options:\n"+
						"  - push the branch and merge to main, then re-run `work release`\n"+
						"  - if the work was intentionally abandoned: `work release %s --allow-unmerged \"<reason>\"`\n"+
						"  (squash-merged work is auto-detected via its merged PR)",
					branch, len(unmerged), strings.Join(unmerged, "\n"), name)
			case mergeAllowUnmerged:
				notesAddendum = fmt.Sprintf("[released --allow-unmerged: %s; %d commit(s) abandoned on %s]", allowUnmergedReason, len(unmerged), branch)
				fmt.Fprintf(os.Stderr, "  merge-check: ALLOW-UNMERGED — %d commit(s) on %s not on origin/main; reason: %s\n", len(unmerged), branch, allowUnmergedReason)
			}
		}

		notes := tr.Notes
		if notesAddendum != "" {
			if notes != "" {
				notes = notes + " " + notesAddendum
			} else {
				notes = notesAddendum
			}
		}
		finalCommit := flags["final-commit"]
		if finalCommit == "" && allowUnmergedReason != "" {
			finalCommit = "(none — abandoned)"
		}

		c := Completed{
			Name:        tr.Name,
			Owner:       tr.Owner,
			PickedUpAt:  tr.PickedUpAt,
			ReleasedAt:  now(),
			FinalCommit: finalCommit,
			Notes:       notes,
			Cluster:     tr.Cluster,
		}
		releasedTrack := tr // capture for post-save cleanup
		t.Tracks = append(t.Tracks[:i], t.Tracks[i+1:]...)
		t.RecentlyCompleted = append([]Completed{c}, t.RecentlyCompleted...)
		// NOTE: an earlier version trimmed t.RecentlyCompleted to the last 7
		// days here. That made sense under the monolithic active-work.yaml
		// layout (kept the file short) but became a silent file-DELETE under
		// the per-track-files refactor: any item dropped from the in-memory
		// list gets GC'd off disk by syncSubdir on the next save. Surfaced
		// 2026-05-21 when a release would have deleted 9 unrelated
		// recently_completed yamls. The trim has been removed; if the
		// recently_completed/ directory ever grows unwieldy, address it with
		// a separate explicit archive pass — not as a side effect of release.
		if err := save(t, p); err != nil {
			return err
		}
		fmt.Fprintf(os.Stderr, "released %q\n", name)
		stageRecordOrWarn(subdirRecentlyCompleted, name, "release")
		stageReleasedTrackDeletionOrWarn(name)

		// cleanup-on-release — auto-remove the per-session worktree
		// for tracks with mode=worktree. Refuses if cwd is inside the worktree
		// (you can't remove the worktree you're standing in).
		if !keepWorktree && releasedTrack.Mode == "worktree" && releasedTrack.WorktreePath != "" {
			cleanupWorktree(releasedTrack.WorktreePath)
		} else if !keepWorktree {
			// orphan check. Even if metadata says mode!=worktree
			// (stale pickup, --master, legacy track), look for a canonical
			// worktree leftover at `.claude/worktrees/<name>` and surface it.
			if orphanRel, orphanBranch, ok := inferCanonicalWorktree(name); ok {
				fmt.Fprintf(os.Stderr, "  cleanup-on-release: ORPHAN worktree detected at %s (branch %s)\n", orphanRel, orphanBranch)
				fmt.Fprintf(os.Stderr, "  metadata recorded mode=%q (not 'worktree') so auto-cleanup did NOT fire.\n", releasedTrack.Mode)
				fmt.Fprintf(os.Stderr, "  to remove: git worktree remove --force %s && git branch -D %s\n", orphanRel, orphanBranch)
			}
		}
		return nil
	}
	return fmt.Errorf("no active track named %q", name)
}

// remotesWithMain lists every remote that has the trunk branch (config
// `trunk`, default main), in a stable order with `origin` first when present.
//
// Every remote, not just origin: a clone can carry several remotes that are
// views of one history (a primary and a mirror, a fork and its upstream), and
// work merged on any of them is merged. A check that only consults
// origin/<trunk> reports merged work as unmerged whenever origin is not where
// it merged, and then offers --allow-unmerged, writing "abandoned" onto merged
// work. The remote names come from `git remote`; none is assumed.
func remotesWithMain() []string {
	trunk := cfg().Trunk
	out, err := runGitOutput("remote")
	if err != nil || out == "" {
		return []string{"origin"}
	}
	var withMain []string
	for _, r := range strings.Fields(out) {
		if _, err := runGitOutput("rev-parse", "--verify", "--quiet", r+"/"+trunk); err == nil {
			withMain = append(withMain, r)
		}
	}
	if len(withMain) == 0 {
		return []string{"origin"}
	}
	// origin first — usually right, and the cheap hit.
	for i, r := range withMain {
		if r == "origin" && i != 0 {
			withMain[0], withMain[i] = withMain[i], withMain[0]
			break
		}
	}
	return withMain
}

// remoteSlug returns the `owner/repo` slug for a remote, for `gh --repo`.
// Without it `gh` resolves the repo from the cwd's default remote, which may
// not be the one the work merged on. Handles ssh://, scp-style and https URLs, with or
// without a trailing `.git`.
func remoteSlug(remote string) string {
	url, err := runGitOutput("remote", "get-url", remote)
	if err != nil || url == "" {
		return ""
	}
	url = strings.TrimSuffix(strings.TrimRight(url, "/"), ".git")
	parts := strings.Split(url, "/")
	if len(parts) < 2 {
		return ""
	}
	owner, repo := parts[len(parts)-2], parts[len(parts)-1]
	// scp-style `git@host:owner/repo` leaves the host on the owner segment.
	if i := strings.LastIndex(owner, ":"); i >= 0 {
		owner = owner[i+1:]
	}
	if owner == "" || repo == "" {
		return ""
	}
	return owner + "/" + repo
}

// unmergedCommits returns the list of one-line commit summaries reachable
// from `branch` but not from any remote's trunk, by `git cherry`
// (patch-id-based so squash-merges and rebases don't produce false
// positives). Returns nil (no unmerged commits) when the branch is fully
// reachable from at least one remote's main..
//
// Checks EVERY remote and keeps the SMALLEST result, because merged on any
// remote is merged (see remotesWithMain). Also returns the remote that
// produced that result, so the caller names it rather than assuming origin.
// Returns (nil, "", err) when git is unreachable or the branch doesn't
// exist — callers surface the warning and proceed (best-effort).
func unmergedCommits(branch string) ([]string, string, error) {
	// Verify branch exists locally
	if _, err := runGitOutput("rev-parse", "--verify", "--quiet", branch); err != nil {
		return nil, "", fmt.Errorf("branch %s not found locally", branch)
	}
	var best []string
	var bestRemote string
	var firstErr error
	found := false
	trunk := cfg().Trunk
	for _, remote := range remotesWithMain() {
		// `git cherry <remote>/<trunk> <branch>` outputs '+ <sha>' for unmerged
		// commits (by patch-id) and '- <sha>' for commits already on main.
		cmd := exec.Command("git", "cherry", remote+"/"+trunk, branch)
		out, err := cmd.Output()
		if err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("git cherry failed: %w", err)
			}
			continue
		}
		var unmerged []string
		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			if !strings.HasPrefix(line, "+ ") {
				continue
			}
			sha := strings.TrimPrefix(line, "+ ")
			// Annotate with subject line for the diagnostic
			subj, _ := runGitOutput("log", "-1", "--format=%h %s", sha) //nolint:errcheck // diagnostic falls back to the commit SHA
			if subj == "" {
				subj = sha
			}
			unmerged = append(unmerged, "    "+subj)
		}
		if !found || len(unmerged) < len(best) {
			best, bestRemote, found = unmerged, remote, true
		}
		if len(best) == 0 {
			break // fully merged somewhere; nothing cheaper to find
		}
	}
	if !found {
		return nil, "", firstErr
	}
	return best, bestRemote, nil
}

// branchMergedViaPR reports whether a MERGED GitHub PR exists for this
// branch. This is the squash-aware merge signal (): a squash-merge
// collapses a branch's commits into one combined patch, so the patch-id
// based `git cherry` check in unmergedCommits reports every commit as
// unmerged even though the work is on main. A merged PR for the branch
// is authoritative proof the work landed. Best-effort: returns false on
// any gh error (not installed, not authenticated, offline) so the
// release degrades to the cherry check + --allow-unmerged path rather
// than failing.
func branchMergedViaPR(branch string) bool {
	// Ask EVERY remote by explicit slug. Without --repo, gh resolves the repo
	// from the cwd's default remote, so a PR merged on another remote reads as
	// "not merged" — exactly when this squash-aware check is needed.
	for _, remote := range remotesWithMain() {
		slug := remoteSlug(remote)
		if slug == "" {
			continue
		}
		cmd := exec.Command("gh", "pr", "list", "--repo", slug, "--head", branch,
			"--state", "merged", "--json", "number", "--jq", "length")
		out, err := cmd.Output()
		if err != nil {
			continue // best-effort: gh missing/unauthenticated/offline
		}
		if n := strings.TrimSpace(string(out)); n != "" && n != "0" {
			return true
		}
	}
	return false
}

// mergeAction is the release merge-check decision.
type mergeAction int

const (
	mergePass mergeAction = iota
	mergeRefuse
	mergeAllowUnmerged
)

// mergeVerdict decides the release merge-check outcome, isolating the
// squash-aware rule so it is unit-testable without shelling to
// git/gh. Inputs: `unmergedCount` from the patch-id `git cherry` check,
// `mergedViaPR` from branchMergedViaPR, and the operator's
// `--allow-unmerged` reason (empty = not passed). The caller handles the
// cherry-errored case (skip) before calling this.
//
//   - cherry says all patches are on main         → Pass
//   - cherry says some aren't, but a PR merged it  → Pass (squash-merge)
//   - genuinely unmerged, no override             → Refuse
//   - genuinely unmerged, operator overrode        → AllowUnmerged
func mergeVerdict(unmergedCount int, mergedViaPR bool, allowReason string) mergeAction {
	if unmergedCount == 0 {
		return mergePass
	}
	if mergedViaPR {
		return mergePass
	}
	if allowReason == "" {
		return mergeRefuse
	}
	return mergeAllowUnmerged
}

// cleanupWorktree attempts to remove the per-session worktree for a released
// track. Best-effort: prints actionable guidance on failure rather than erroring
// the whole release. Refuses to remove a worktree the operator is currently
// standing in (would yank state from under their cwd).
//
// Resolves master via `git rev-parse --git-common-dir` (NOT --show-toplevel,
// which returns the *child* worktree's root when called from inside a child
// worktree, breaking the cwd-inside-worktree refusal check).
//
// (2026-05-13): All skip paths emit stderr diagnostics rather than
// returning silently. Silent skip was the root cause of the block-79 worktree
// staying on disk after release.
func cleanupWorktree(worktreePath string) {
	if worktreePath == "" {
		return
	}
	commonDir, err := exec.Command("git", "rev-parse", "--git-common-dir").Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "  cleanup-on-release: skipping (could not resolve --git-common-dir: %v)\n", err)
		return
	}
	// commonDir is something like "/path/to/master/.git" or just ".git" in
	// master worktree. Strip trailing /.git to get the master worktree root.
	masterRoot := strings.TrimSuffix(strings.TrimSpace(string(commonDir)), "/.git")
	masterRoot = strings.TrimSuffix(masterRoot, ".git")
	if !strings.HasPrefix(masterRoot, "/") {
		// Was a relative path (called from master worktree); resolve to abs.
		if abs, absErr := filepath.Abs(masterRoot); absErr == nil {
			masterRoot = abs
		}
	}
	masterRoot = strings.TrimSuffix(masterRoot, "/")
	// Resolve symlinks so macOS /private/var vs /var/folders comparison works.
	if resolved, rErr := filepath.EvalSymlinks(masterRoot); rErr == nil {
		masterRoot = resolved
	}
	absWorktree := masterRoot + "/" + worktreePath

	cwd, err := os.Getwd()
	if err == nil {
		if resolved, rErr := filepath.EvalSymlinks(cwd); rErr == nil {
			cwd = resolved
		}
		probe := cwd
		for probe != "/" && probe != "" {
			if probe == absWorktree {
				fmt.Fprintf(os.Stderr, "  cleanup-on-release: SKIPPED — current cwd is inside %s.\n", worktreePath)
				fmt.Fprintf(os.Stderr, "  cd out of the worktree, then run: git worktree remove %s\n", worktreePath)
				return
			}
			idx := strings.LastIndex(probe, "/")
			if idx <= 0 {
				break
			}
			probe = probe[:idx]
		}
	}

	cmd := exec.Command("git", "worktree", "remove", worktreePath)
	cmd.Dir = masterRoot
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "  cleanup-on-release: %s\n", strings.TrimSpace(string(out)))
		fmt.Fprintf(os.Stderr, "  to remove: git worktree remove --force %s\n", worktreePath)
		fmt.Fprintf(os.Stderr, "  to keep:   re-run release with --keep-worktree\n")
		return
	}
	fmt.Fprintf(os.Stderr, "  cleanup-on-release: removed worktree %s\n", worktreePath)
}

func cmdList(args []string) error {
	flags, _ := parseFlags(args)
	t, _, err := load()
	if err != nil {
		return err
	}
	wantOwner := flags["owner"]
	wantStatus := flags["status"]
	wantCluster := flags["cluster"]
	if len(t.Tracks) == 0 {
		fmt.Println("(no active tracks)")
		return nil
	}
	sort.Slice(t.Tracks, func(i, j int) bool { return t.Tracks[i].PickedUpAt.Before(t.Tracks[j].PickedUpAt) })
	w := bufio.NewWriter(os.Stdout)
	fmt.Fprintln(w, "TRACK\tOWNER\tSTATUS\tCLUSTER\tPICKED_UP\tLAST_ACTIVITY\tETA\tSCOPE")
	for _, tr := range t.Tracks {
		if wantOwner != "" && tr.Owner != wantOwner {
			continue
		}
		if wantStatus != "" && !strings.HasPrefix(tr.Status, wantStatus) {
			continue
		}
		if wantCluster != "" && tr.Cluster != wantCluster {
			continue
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
			tr.Name, tr.Owner, tr.Status, tr.Cluster,
			tr.PickedUpAt.Format(time.RFC3339),
			tr.LastActivityAt.Format(time.RFC3339),
			tr.ETA,
			strings.Join(tr.Scope, ","),
		)
	}
	return w.Flush()
}

func cmdQueued(args []string) error {
	t, _, err := load()
	if err != nil {
		return err
	}
	if len(t.Queued) == 0 {
		fmt.Println("(no queued items)")
		return nil
	}
	w := bufio.NewWriter(os.Stdout)
	fmt.Fprintln(w, "ITEM\tGATED_ON\tSOURCE\tSURFACED\tWHY")
	for _, q := range t.Queued {
		surfaced := ""
		if !q.SurfacedAt.IsZero() {
			surfaced = q.SurfacedAt.Format("2006-01-02")
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n",
			q.Name, q.GatedOn, q.Source, surfaced, q.Why)
	}
	return w.Flush()
}

func cmdCheckStale(args []string) error {
	flags, _ := parseFlags(args)
	threshold := 24 * time.Hour
	if v := flags["threshold"]; v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			return fmt.Errorf("bad --threshold %q: %w", v, err)
		}
		threshold = d
	}
	t, _, err := load()
	if err != nil {
		return err
	}
	cutoff := now().Add(-threshold)
	stale := 0
	for _, tr := range t.Tracks {
		if tr.LastActivityAt.Before(cutoff) {
			fmt.Printf("STALE: %s\towner=%s\tlast_activity=%s (%.1fh ago)\n",
				tr.Name, tr.Owner, tr.LastActivityAt.Format(time.RFC3339),
				now().Sub(tr.LastActivityAt).Hours())
			stale++
		}
	}
	if stale > 0 {
		os.Exit(1)
	}
	return nil
}

func cmdWhoami(_ []string) error {
	fmt.Println(whoami())
	return nil
}

func cmdCommit(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work commit <track> -m <msg> --paths <comma-separated-paths> [extra git-commit args]\n\n" +
			"--paths is REQUIRED. The CLI uses `git commit -- <paths>` semantics so cross-session\n" +
			"staged files in the shared .git/index cannot be scooped into this commit.\n\n" +
			"Workflow:\n" +
			"  1. git status -s                                          # verify shared-index state\n" +
			"  2. git add <paths>                                        # stage your files explicitly\n" +
			"  3. work commit <track> -m <msg> --paths <comma-paths>     # commit only your paths\n\n" +
			"To bypass the path restriction (NOT recommended; reproduces the pre-fix behavior),\n" +
			"pass --allow-shared-index. Use only when you have verified the shared index is empty\n" +
			"of cross-session staged files via `git status -s`.")
	}
	name := pos[0]
	msg := flags["m"]
	if msg == "" {
		return fmt.Errorf("--m or -m required")
	}
	paths := splitCSV(flags["paths"])
	allowSharedIndex := flags["allow-shared-index"] != ""

	if len(paths) == 0 && !allowSharedIndex {
		stagedFiles, err := exec.Command("git", "diff", "--cached", "--name-only").Output()
		if err != nil {
			return fmt.Errorf("list staged files: %w", err)
		}
		untracked, err := exec.Command("git", "ls-files", "--others", "--exclude-standard").Output()
		if err != nil {
			return fmt.Errorf("list untracked files: %w", err)
		}
		return errors.New("--paths is required (shared-index hazard guard).\n\n" +
			"Currently staged in the shared .git/index:\n" +
			indent(string(stagedFiles), "  ") +
			"\nCurrently untracked (not staged):\n" +
			indent(string(untracked), "  ") +
			"\nRe-invoke with --paths <comma-separated-paths> listing only YOUR files,\n" +
			"or pass --allow-shared-index to bypass (only after verifying no other session\n" +
			"has staged files via `git status -s`).")
	}

	t, _, err := load()
	if err != nil {
		return err
	}
	known := false
	for i, tr := range t.Tracks {
		if tr.Name == name {
			known = true
			t.Tracks[i].LastActivityAt = now()
			break
		}
	}
	if !known {
		fmt.Fprintf(os.Stderr, "warning: %q is not an active track\n", name)
	}
	full := msg + "\n\n[track: " + name + "]\n"
	gitArgs := []string{"commit", "-m", full}
	gitArgs = append(gitArgs, pos[1:]...)
	if len(paths) > 0 {
		// `git commit -- <paths>` commits ONLY these paths from the index, leaving any
		// cross-session staged files untouched. This is the load-bearing isolation.
		gitArgs = append(gitArgs, "--")
		gitArgs = append(gitArgs, paths...)
	} else {
		// --allow-shared-index path: commit everything in the index (legacy behavior).
		// Print what's about to be committed so the operator sees it.
		stagedFiles, err := exec.Command("git", "diff", "--cached", "--name-only").Output()
		if err != nil {
			return fmt.Errorf("list staged files: %w", err)
		}
		fmt.Fprintln(os.Stderr, "--allow-shared-index: committing ALL staged files in the shared index:")
		fmt.Fprint(os.Stderr, indent(string(stagedFiles), "  "))
	}
	cmd := exec.Command("git", gitArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		return err
	}
	if known {
		// re-save to bump last_activity
		p, err := trackerPath()
		if err != nil {
			return fmt.Errorf("commit succeeded but the tracker could not be located: %w", err)
		}
		if err := save(t, p); err != nil {
			return fmt.Errorf("commit succeeded but track activity could not be updated: %w", err)
		}
	}
	return nil
}

// indent prefixes every non-empty line of s with prefix.
func indent(s, prefix string) string {
	if s == "" {
		return ""
	}
	out := ""
	for _, line := range strings.Split(s, "\n") {
		if line == "" {
			out += "\n"
		} else {
			out += prefix + line + "\n"
		}
	}
	return out
}

// ----------------------------------------------------------------------
// cluster subcommands

func cmdClusterRegister(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work cluster register <name> --captain <agent_id> [--scope blocks] [--kickoff-memo <path>] [--note ...]")
	}
	name := pos[0]
	captain := flags["captain"]
	if captain == "" {
		return fmt.Errorf("--captain required")
	}
	t, p, err := load()
	if err != nil {
		return err
	}
	for _, c := range t.Clusters {
		if c.Name == name {
			return fmt.Errorf("cluster %q already registered (captain=%s, picked_up_at=%s)", name, c.Captain, c.PickedUpAt.Format(time.RFC3339))
		}
	}
	c := Cluster{
		Name:           name,
		Captain:        captain,
		Scope:          splitCSV(flags["scope"]),
		Status:         "active",
		PickedUpAt:     now(),
		LastActivityAt: now(),
		KickoffMemo:    flags["kickoff-memo"],
		Notes:          flags["note"],
	}
	t.Clusters = append(t.Clusters, c)
	if err := save(t, p); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "registered cluster %q (captain=%s) to %s\n", name, captain, p)
	if c.KickoffMemo != "" {
		fmt.Fprintf(os.Stderr, "  kickoff memo: %s\n", c.KickoffMemo)
	}
	fmt.Fprintln(os.Stderr, "remember to: git add", p, "&& git commit -m \"chore(work): register cluster", name+"\"")
	return nil
}

func cmdClusterStatus(args []string) error {
	_, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work cluster status <name>")
	}
	name := pos[0]
	t, _, err := load()
	if err != nil {
		return err
	}
	var c *Cluster
	for i := range t.Clusters {
		if t.Clusters[i].Name == name {
			c = &t.Clusters[i]
			break
		}
	}
	if c == nil {
		return fmt.Errorf("no cluster named %q (use `work cluster list` to see registered clusters)", name)
	}
	fmt.Printf("cluster: %s\n", c.Name)
	fmt.Printf("captain: %s\n", c.Captain)
	fmt.Printf("status:  %s\n", c.Status)
	fmt.Printf("scope:   %s\n", strings.Join(c.Scope, ", "))
	fmt.Printf("picked_up_at:    %s\n", c.PickedUpAt.Format(time.RFC3339))
	fmt.Printf("last_activity:   %s\n", c.LastActivityAt.Format(time.RFC3339))
	if c.KickoffMemo != "" {
		fmt.Printf("kickoff_memo:    %s\n", c.KickoffMemo)
	}
	if c.Notes != "" {
		fmt.Printf("notes: %s\n", c.Notes)
	}
	fmt.Println()

	// Active tracks under this cluster
	var active []Track
	for _, tr := range t.Tracks {
		if tr.Cluster == name {
			active = append(active, tr)
		}
	}
	if len(active) == 0 {
		fmt.Println("active tracks: (none)")
	} else {
		fmt.Println("active tracks:")
		w := bufio.NewWriter(os.Stdout)
		fmt.Fprintln(w, "  TRACK\tOWNER\tSTATUS\tPICKED_UP\tLAST_ACTIVITY\tETA")
		sort.Slice(active, func(i, j int) bool { return active[i].PickedUpAt.Before(active[j].PickedUpAt) })
		for _, tr := range active {
			fmt.Fprintf(w, "  %s\t%s\t%s\t%s\t%s\t%s\n",
				tr.Name, tr.Owner, tr.Status,
				tr.PickedUpAt.Format(time.RFC3339),
				tr.LastActivityAt.Format(time.RFC3339),
				tr.ETA,
			)
		}
		if err := w.Flush(); err != nil {
			return fmt.Errorf("write active tracks: %w", err)
		}
	}

	// Recently completed under this cluster
	var done []Completed
	for _, rc := range t.RecentlyCompleted {
		if rc.Cluster == name {
			done = append(done, rc)
		}
	}
	if len(done) > 0 {
		fmt.Println()
		fmt.Println("recently completed:")
		for _, rc := range done {
			fmt.Printf("  %s\t%s\treleased=%s\tcommit=%s\n",
				rc.Name, rc.Owner, rc.ReleasedAt.Format(time.RFC3339), rc.FinalCommit)
		}
	}

	// Pending decisions tagged to this cluster
	var pend []PendingDecision
	for _, d := range t.PendingDecisions {
		if d.Cluster == name && d.Status != "resolved" {
			pend = append(pend, d)
		}
	}
	if len(pend) > 0 {
		fmt.Println()
		fmt.Println("pending decisions:")
		for _, d := range pend {
			fmt.Printf("  %s\t%s\traised_by=%s\n", d.ID, d.Summary, d.RaisedBy)
		}
	}
	return nil
}

func cmdClusterList(_ []string) error {
	t, _, err := load()
	if err != nil {
		return err
	}
	if len(t.Clusters) == 0 {
		fmt.Println("(no registered clusters)")
		return nil
	}
	sort.Slice(t.Clusters, func(i, j int) bool { return t.Clusters[i].PickedUpAt.Before(t.Clusters[j].PickedUpAt) })
	w := bufio.NewWriter(os.Stdout)
	fmt.Fprintln(w, "CLUSTER\tCAPTAIN\tSTATUS\tPICKED_UP\tLAST_ACTIVITY\tSCOPE")
	for _, c := range t.Clusters {
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\n",
			c.Name, c.Captain, c.Status,
			c.PickedUpAt.Format(time.RFC3339),
			c.LastActivityAt.Format(time.RFC3339),
			strings.Join(c.Scope, ","),
		)
	}
	return w.Flush()
}

func cmdClusterUpdate(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work cluster update <name> [--status ...] [--note ...] [--scope ...] [--kickoff-memo ...]")
	}
	name := pos[0]
	t, p, err := load()
	if err != nil {
		return err
	}
	for i := range t.Clusters {
		if t.Clusters[i].Name != name {
			continue
		}
		t.Clusters[i].LastActivityAt = now()
		if v := flags["status"]; v != "" {
			t.Clusters[i].Status = v
		}
		if v := flags["note"]; v != "" {
			t.Clusters[i].Notes = v
		}
		if v := flags["scope"]; v != "" {
			t.Clusters[i].Scope = splitCSV(v)
		}
		if v := flags["kickoff-memo"]; v != "" {
			t.Clusters[i].KickoffMemo = v
		}
		if err := save(t, p); err != nil {
			return err
		}
		fmt.Fprintf(os.Stderr, "updated cluster %q (status=%s)\n", name, t.Clusters[i].Status)
		return nil
	}
	return fmt.Errorf("no cluster named %q", name)
}

func cmdClusterRelease(args []string) error {
	_, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work cluster release <name>")
	}
	name := pos[0]
	t, p, err := load()
	if err != nil {
		return err
	}
	for i, c := range t.Clusters {
		if c.Name != name {
			continue
		}
		// Refuse if active tracks still linked to this cluster.
		var stillActive []string
		for _, tr := range t.Tracks {
			if tr.Cluster == name {
				stillActive = append(stillActive, tr.Name)
			}
		}
		if len(stillActive) > 0 {
			return fmt.Errorf("cluster %q has %d active tracks (%s); release them first or detach with `work update <track> --cluster=\"\"`",
				name, len(stillActive), strings.Join(stillActive, ", "))
		}
		t.Clusters = append(t.Clusters[:i], t.Clusters[i+1:]...)
		if err := save(t, p); err != nil {
			return err
		}
		fmt.Fprintf(os.Stderr, "released cluster %q\n", name)
		return nil
	}
	return fmt.Errorf("no cluster named %q", name)
}

// ----------------------------------------------------------------------
// role subcommands

func cmdRoleList(_ []string) error {
	d, err := rolesDir()
	if err != nil {
		return err
	}
	entries, err := os.ReadDir(d)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("(no role-prompts — directory", d, "does not exist)")
			return nil
		}
		return err
	}
	var roles []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		n := e.Name()
		if !strings.HasSuffix(n, ".md") {
			continue
		}
		if n == "INDEX.md" || strings.HasPrefix(n, ".") {
			continue
		}
		roles = append(roles, strings.TrimSuffix(n, ".md"))
	}
	if len(roles) == 0 {
		fmt.Println("(no role-prompts in", d+")")
		return nil
	}
	sort.Strings(roles)
	for _, r := range roles {
		fmt.Println(r)
	}
	return nil
}

func cmdRoleLoad(args []string) error {
	_, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work role load <role>")
	}
	name := pos[0]
	d, err := rolesDir()
	if err != nil {
		return err
	}
	p := filepath.Join(d, name+".md")
	b, err := os.ReadFile(p)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("role-prompt %q not found at %s (use `work role list` to see available roles)", name, p)
		}
		return err
	}
	if _, err := os.Stdout.Write(b); err != nil {
		return fmt.Errorf("write role prompt: %w", err)
	}
	return nil
}

// ----------------------------------------------------------------------
// file-claim subcommands

func cmdFileClaim(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work file claim <path> --until <when> [--note ...] [--track ...]")
	}
	path := pos[0]
	until, err := parseUntil(flags["until"])
	if err != nil {
		return err
	}
	t, p, err := load()
	if err != nil {
		return err
	}
	owner := whoami()
	for _, fc := range t.FileClaims {
		if fc.Path == path && fc.Until.After(now()) && fc.Owner != owner {
			return fmt.Errorf("path %q already claimed by %s until %s (note: %s)",
				path, fc.Owner, fc.Until.Format(time.RFC3339), fc.Note)
		}
	}
	// Drop the old claim by this owner on the same path before re-adding.
	kept := t.FileClaims[:0]
	for _, fc := range t.FileClaims {
		if fc.Path == path && fc.Owner == owner {
			continue
		}
		kept = append(kept, fc)
	}
	t.FileClaims = append(kept, FileClaim{
		Path:      path,
		Owner:     owner,
		ClaimedAt: now(),
		Until:     until,
		Track:     flags["track"],
		Note:      flags["note"],
	})
	if err := save(t, p); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "claimed %q until %s\n", path, until.Format(time.RFC3339))
	return nil
}

func cmdFileRelease(args []string) error {
	_, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work file release <path>")
	}
	path := pos[0]
	t, p, err := load()
	if err != nil {
		return err
	}
	owner := whoami()
	kept := t.FileClaims[:0]
	released := 0
	for _, fc := range t.FileClaims {
		if fc.Path == path && fc.Owner == owner {
			released++
			continue
		}
		kept = append(kept, fc)
	}
	t.FileClaims = kept
	if err := save(t, p); err != nil {
		return err
	}
	if released == 0 {
		fmt.Fprintf(os.Stderr, "no claim by %s on %q to release\n", owner, path)
		return nil
	}
	fmt.Fprintf(os.Stderr, "released %d claim(s) on %q\n", released, path)
	return nil
}

func cmdFileList(_ []string) error {
	t, _, err := load()
	if err != nil {
		return err
	}
	// Auto-prune expired claims from display, but don't write — that
	// happens lazily on the next claim/release.
	var active []FileClaim
	for _, fc := range t.FileClaims {
		if fc.Until.After(now()) {
			active = append(active, fc)
		}
	}
	if len(active) == 0 {
		fmt.Println("(no active file claims)")
		return nil
	}
	sort.Slice(active, func(i, j int) bool { return active[i].Path < active[j].Path })
	w := bufio.NewWriter(os.Stdout)
	fmt.Fprintln(w, "PATH\tOWNER\tUNTIL\tTRACK\tNOTE")
	for _, fc := range active {
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n",
			fc.Path, fc.Owner, fc.Until.Format(time.RFC3339), fc.Track, fc.Note)
	}
	return w.Flush()
}

// ----------------------------------------------------------------------
// decision subcommands

func nextDecisionID(existing []PendingDecision) string {
	max := 0
	for _, d := range existing {
		var n int
		if _, err := fmt.Sscanf(d.ID, "d-%d", &n); err == nil && n > max {
			max = n
		}
	}
	return fmt.Sprintf("d-%03d", max+1)
}

func cmdDecisionsPending(args []string) error {
	flags, _ := parseFlags(args)
	wantCluster := flags["cluster"]
	t, _, err := load()
	if err != nil {
		return err
	}
	var pend []PendingDecision
	for _, d := range t.PendingDecisions {
		if d.Status == "resolved" {
			continue
		}
		if wantCluster != "" && d.Cluster != wantCluster {
			continue
		}
		pend = append(pend, d)
	}
	if len(pend) == 0 {
		fmt.Println("(no pending decisions)")
		return nil
	}
	sort.Slice(pend, func(i, j int) bool { return pend[i].RaisedAt.Before(pend[j].RaisedAt) })
	w := bufio.NewWriter(os.Stdout)
	fmt.Fprintln(w, "ID\tCLUSTER\tRAISED_BY\tRAISED_AT\tSUMMARY")
	for _, d := range pend {
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n",
			d.ID, d.Cluster, d.RaisedBy, d.RaisedAt.Format(time.RFC3339), d.Summary)
	}
	return w.Flush()
}

func cmdDecisionsRaise(args []string) error {
	flags, _ := parseFlags(args)
	summary := flags["summary"]
	if summary == "" {
		return fmt.Errorf("usage: work decisions raise --summary <text> [--cluster ...] [--options \"a,b,c\"] [--raised-by ...]")
	}
	t, p, err := load()
	if err != nil {
		return err
	}
	raisedBy := flags["raised-by"]
	if raisedBy == "" {
		raisedBy = whoami()
	}
	d := PendingDecision{
		ID:       nextDecisionID(t.PendingDecisions),
		Summary:  summary,
		RaisedBy: raisedBy,
		Cluster:  flags["cluster"],
		Options:  splitCSV(flags["options"]),
		RaisedAt: now(),
		Status:   "open",
	}
	t.PendingDecisions = append(t.PendingDecisions, d)
	if err := save(t, p); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "raised decision %s: %s\n", d.ID, summary)
	return nil
}

func cmdDecisionsResolve(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work decisions resolve <id> --resolution <text>")
	}
	id := pos[0]
	resolution := flags["resolution"]
	if resolution == "" {
		return fmt.Errorf("--resolution required")
	}
	t, p, err := load()
	if err != nil {
		return err
	}
	for i := range t.PendingDecisions {
		if t.PendingDecisions[i].ID != id {
			continue
		}
		t.PendingDecisions[i].Status = "resolved"
		t.PendingDecisions[i].Resolution = resolution
		t.PendingDecisions[i].ResolvedAt = now()
		if err := save(t, p); err != nil {
			return err
		}
		fmt.Fprintf(os.Stderr, "resolved %s: %s\n", id, resolution)
		return nil
	}
	return fmt.Errorf("no decision %q", id)
}

// ----------------------------------------------------------------------
// dispatch

// cmdMigrate is the one-shot splitter: read the legacy monolithic
// active-work.yaml + write its contents to per-track files + delete the
// monolith. Idempotent — re-running on a fully-migrated repo is a no-op.
func cmdMigrate(_ []string) error {
	legacy, err := trackerPath()
	if err != nil {
		return err
	}
	dir, err := trackerDir()
	if err != nil {
		return err
	}
	b, err := os.ReadFile(legacy)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Fprintln(os.Stderr, "migrate: no legacy", legacy, "— nothing to do")
			return nil
		}
		return err
	}
	var t Tracker
	if err := yaml.Unmarshal(b, &t); err != nil {
		return fmt.Errorf("yaml parse %s: %w", legacy, err)
	}
	// Temporarily move the legacy file aside so save()'s legacy-present
	// refuse-guard doesn't trip. We restore + remove at the end.
	stash := legacy + ".migrating"
	if err := os.Rename(legacy, stash); err != nil {
		return fmt.Errorf("rename %s -> %s: %w", legacy, stash, err)
	}
	if err := save(&t, dir); err != nil {
		rollbackErr := os.Rename(stash, legacy)
		if rollbackErr != nil {
			return errors.Join(fmt.Errorf("write per-track files: %w", err),
				fmt.Errorf("restore legacy tracker: %w", rollbackErr))
		}
		return fmt.Errorf("write per-track files: %w", err)
	}
	if err := os.Remove(stash); err != nil {
		return fmt.Errorf("rm %s: %w", stash, err)
	}
	fmt.Fprintf(os.Stderr,
		"migrate: split %s into per-track files under %s/ (tracks=%d completed=%d queued=%d clusters=%d file_claims=%d decisions=%d). Legacy monolith removed.\n",
		legacy, dir, len(t.Tracks), len(t.RecentlyCompleted), len(t.Queued),
		len(t.Clusters), len(t.FileClaims), len(t.PendingDecisions))
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, `work — concurrency-governance CLI

Track subcommands (per-actor work):
  pickup <track> [--scope ...] [--eta ...] [--note ...] [--cluster ...]
  update <track> [--status ...] [--scope ...] [--note ...] [--eta ...] [--cluster ...]
  release <track> [--final-commit <sha>]
  list [--owner ...] [--status ...] [--cluster ...]
  queued
  check-stale [--threshold 24h]
  whoami
  commit <track> -m <msg>

Cluster subcommands (multi-track captaincy):
  cluster register <name> --captain <agent_id> [--scope ...] [--kickoff-memo <p>] [--note ...]
  cluster status <name>
  cluster list
  cluster update <name> [--status ...] [--note ...] [--scope ...] [--kickoff-memo ...]
  cluster release <name>

Role subcommands (load role-prompts at agent boot):
  role list
  role load <role>

File-claim subcommands (file-grain conflict avoidance):
  file claim <path> --until <when> [--note ...] [--track ...]
  file release <path>
  file list

Decision subcommands (cross-cluster decision dedup):
  decisions pending [--cluster ...]
  decisions raise --summary <text> [--cluster ...] [--options "a,b,c"]
  decisions resolve <id> --resolution <text>

Migration (one-shot, idempotent):
  migrate              Split the legacy <tracker_dir>.yaml into per-track files,
                       then remove the legacy file. Safe to re-run.

Paths come from .claude/agent-workflow.yaml (tracker_dir, roles_dir,
worktrees_dir, trunk, bus). See README.md beside the source.`)
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	args := os.Args[2:]
	var err error
	switch os.Args[1] {
	case "pickup":
		err = cmdPickup(args)
	case "update":
		err = cmdUpdate(args)
	case "release":
		err = cmdRelease(args)
	case "list":
		err = cmdList(args)
	case "queued":
		err = cmdQueued(args)
	case "check-stale":
		err = cmdCheckStale(args)
	case "whoami":
		err = cmdWhoami(args)
	case "commit":
		err = cmdCommit(args)
	case "cluster":
		err = dispatchCluster(args)
	case "role":
		err = dispatchRole(args)
	case "file":
		err = dispatchFile(args)
	case "decisions":
		err = dispatchDecisions(args)
	case "bus":
		err = dispatchBus(args)
	case "migrate":
		err = cmdMigrate(args)
	case "-h", "--help", "help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand %q\n", os.Args[1])
		usage()
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func dispatchCluster(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: work cluster <register|status|list|update|release> ...")
	}
	rest := args[1:]
	switch args[0] {
	case "register":
		return cmdClusterRegister(rest)
	case "status":
		return cmdClusterStatus(rest)
	case "list":
		return cmdClusterList(rest)
	case "update":
		return cmdClusterUpdate(rest)
	case "release":
		return cmdClusterRelease(rest)
	default:
		return fmt.Errorf("unknown `cluster` subcommand %q", args[0])
	}
}

func dispatchRole(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: work role <list|load>")
	}
	rest := args[1:]
	switch args[0] {
	case "list":
		return cmdRoleList(rest)
	case "load":
		return cmdRoleLoad(rest)
	default:
		return fmt.Errorf("unknown `role` subcommand %q", args[0])
	}
}

func dispatchFile(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: work file <claim|release|list>")
	}
	rest := args[1:]
	switch args[0] {
	case "claim":
		return cmdFileClaim(rest)
	case "release":
		return cmdFileRelease(rest)
	case "list":
		return cmdFileList(rest)
	default:
		return fmt.Errorf("unknown `file` subcommand %q", args[0])
	}
}

func dispatchDecisions(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: work decisions <pending|raise|resolve>")
	}
	rest := args[1:]
	switch args[0] {
	case "pending":
		return cmdDecisionsPending(rest)
	case "raise":
		return cmdDecisionsRaise(rest)
	case "resolve":
		return cmdDecisionsResolve(rest)
	default:
		return fmt.Errorf("unknown `decisions` subcommand %q", args[0])
	}
}

// ----------------------------------------------------------------------
// — session-bus event layer
//
// Append-only JSONL at ~/.claude/state/session-bus-<repo-fingerprint>.jsonl,
// one bus per clone, so repos on the same machine don't cross-pollinate. A
// marker key `bus: <name>` puts the repo on ~/.claude/state/session-bus-<name>.jsonl
// instead, so sibling repos can share one bus. The delivery hook computes the
// same path.
//
// Six subcommands:
//   bus warn <msg>     — emit a warn-level event
//   bus info <msg>     — emit an info-level event
//   bus urgent <msg>   — emit an urgent-level event (future: ntfy push)
//   bus ack <ts>       — acknowledge a message (directed info back at its sender)
//   bus tail [--track <name>] [--since <byte-offset>]  — read events
//   bus cursor         — print current end-of-file byte offset
//
// Emitters can direct a message at a specific reader with --to session:<id>
// or --to track:<name>; this prefixes the msg with the canonical
// "TO session <id>: " / "TO track <name>: " marker that the delivery hook
// (.claude/hooks/session-bus-tail.sh) always injects for the addressee,
// even when the info firehose is capped.
//
// DELIVERY CONTRACT: posting to the bus is NOT delivery. Delivery happens
// when a reader session's session-bus-tail.sh hook fires (SessionStart
// catch-up + every UserPromptSubmit) and injects the event as context.
//
// Events carry: ts (RFC3339), level, msg, track, owner, host, cwd, branch.
// Atomic single-write append via O_APPEND (POSIX guarantee for <PIPE_BUF
// writes).
//
// Substrate-replaceable: any agent or operator can append to the JSONL
// directly if the CLI is unavailable; the file format is the contract.

type BusEvent struct {
	TS        string `json:"ts"`
	Level     string `json:"level"`
	Msg       string `json:"msg"`
	Track     string `json:"track,omitempty"`
	Owner     string `json:"owner"`
	Host      string `json:"host,omitempty"`
	Cwd       string `json:"cwd,omitempty"`
	Branch    string `json:"branch,omitempty"`
	SessionID string `json:"session_id,omitempty"` // CLAUDE_SESSION_ID || PPID+stat-ctime
	Ref       string `json:"ref,omitempty"`        // ts of the event being acked (bus ack)
}

// Bus etiquette — emit only substrate-relevant signals.
// DO emit: pickup / release / permission-boundary halt / repair-mode entry-exit /
//
//	dictator election / integration milestone / drift detection / urgent
//	operator-attention.
//
// DON'T emit: per-Bash-call status / file-edit events / build-step progress /
//
//	search-grep results / routine debug output.
//
// busRateLimit refuses identical (level, owner, msg) tuples emitted within 60s
// to prevent accidental flooding (e.g., a tight retry loop).
const busRateLimitWindow = 60 * time.Second

func busFilePath() (string, error) {
	// CRITICAL: fingerprint must be the same when called from the master
	// worktree OR from any child worktree, otherwise sessions in different
	// worktrees write to different bus files and never see each other.
	//
	// repoRoot() (which uses `git rev-parse --show-toplevel`) returns the
	// CHILD worktree's path when called from a child worktree — wrong key.
	//
	// Use `git rev-parse --git-common-dir` instead; that returns the
	// master's `.git` directory regardless of which worktree we're in.
	// Strip the trailing `/.git` to get the master worktree's path.
	commonDir, err := runGitOutput("rev-parse", "--git-common-dir")
	if err != nil {
		// Fall back to repoRoot() if not in a git repo (degenerate case)
		commonDir, err = repoRoot()
		if err != nil {
			return "", err
		}
	}
	commonDirAbs, err := filepath.Abs(commonDir)
	if err != nil {
		commonDirAbs = commonDir
	}
	masterRoot := commonDirAbs
	if filepath.Base(masterRoot) == ".git" {
		masterRoot = filepath.Dir(masterRoot)
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	stateDir := filepath.Join(homeDir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return "", err
	}
	if name := cfg().Bus; name != "" {
		return filepath.Join(stateDir, "session-bus-"+name+".jsonl"), nil
	}
	// Per-master-repo fingerprint via SHA-256 of master worktree path;
	// first 12 hex chars. Stable across master + every child worktree.
	h := sha256.Sum256([]byte(masterRoot))
	fp := hex.EncodeToString(h[:])[:12]
	return filepath.Join(stateDir, "session-bus-"+fp+".jsonl"), nil
}

// busSessionID returns a stable session identifier for the current process.
//
// Order matters, and the second entry is load-bearing. Claude Code does not
// export CLAUDE_SESSION_ID, but it does export CLAUDE_CODE_SESSION_ID, and
// that value is the SAME uuid the delivery hook reads from its stdin JSON
// (.session_id) — so it is the only id an emitter can stamp that a reader
// will recognise as itself.
//
// The p<ppid> fallback is a last resort, not a session id: measured
// 2026-09-05, Claude Code runs every Bash tool call in a FRESH shell, so
// os.Getppid() differs on every invocation. 157 events in one repo's bus
// carried ~155 distinct p<ppid> values. Under that fallback:
//   - own-event filtering fails, so a session is fed back its own posts;
//   - "--to session:<id>" addresses an id that existed for one command,
//     so directed delivery never fires for the intended reader.
//
// Both symptoms disappear once a real session uuid is stamped.
func busSessionID() string {
	for _, k := range []string{"CLAUDE_SESSION_ID", "CLAUDE_CODE_SESSION_ID"} {
		if sid := os.Getenv(k); sid != "" {
			return sid
		}
	}
	ppid := os.Getppid()
	return fmt.Sprintf("p%d", ppid)
}

// busRotateIfNeeded archives the bus file if its mtime is in a previous
// calendar month.
func busRotateIfNeeded(path string) error {
	st, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	now := time.Now().UTC()
	mtime := st.ModTime().UTC()
	if mtime.Year() == now.Year() && mtime.Month() == now.Month() {
		return nil
	}
	// File is from a previous month → rotate.
	archive := fmt.Sprintf("%s-%04d-%02d", path, mtime.Year(), int(mtime.Month()))
	return os.Rename(path, archive)
}

// busValidate enforces required-field schema before emitting. Refuses to
// emit malformed events so consumers don't have to defensively parse.
func busValidate(ev BusEvent) error {
	if ev.TS == "" {
		return fmt.Errorf("event missing required field: ts")
	}
	if ev.Level != "warn" && ev.Level != "info" && ev.Level != "urgent" {
		return fmt.Errorf("event level must be warn|info|urgent, got: %q", ev.Level)
	}
	if ev.Msg == "" {
		return fmt.Errorf("event missing required field: msg")
	}
	if ev.Owner == "" {
		return fmt.Errorf("event missing required field: owner")
	}
	if len(ev.Msg) > 2048 {
		return fmt.Errorf("event msg exceeds 2KB (got %d bytes); split into multiple events", len(ev.Msg))
	}
	return nil
}

// busRateLimitCheck refuses to emit if an identical (level, owner, msg)
// event was emitted within the last busRateLimitWindow. Prevents accidental
// flooding from tight retry loops; respects the bus etiquette of emitting
// only substrate-relevant signals.
func busRateLimitCheck(path string, ev BusEvent) error {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	defer f.Close()

	// Read up to last 16KB to find the most recent matching event.
	st, err := f.Stat()
	if err != nil {
		return fmt.Errorf("stat bus log: %w", err)
	}
	readFrom := st.Size() - 16*1024
	if readFrom < 0 {
		readFrom = 0
	}
	if _, err := f.Seek(readFrom, io.SeekStart); err != nil {
		return nil // best-effort
	}

	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	cutoff := time.Now().UTC().Add(-busRateLimitWindow)

	for scanner.Scan() {
		var prior BusEvent
		if err := json.Unmarshal(scanner.Bytes(), &prior); err != nil {
			continue
		}
		if prior.Level != ev.Level || prior.Owner != ev.Owner || prior.Msg != ev.Msg {
			continue
		}
		priorTS, err := time.Parse(time.RFC3339, prior.TS)
		if err != nil {
			continue
		}
		if priorTS.After(cutoff) {
			return fmt.Errorf("rate-limited: identical (level=%s, owner=%s, msg) emitted at %s (within %s window)",
				ev.Level, ev.Owner, prior.TS, busRateLimitWindow)
		}
	}
	return nil
}

func busTrackFromCwd() string {
	branch, err := runGitOutput("symbolic-ref", "--quiet", "--short", "HEAD")
	if err != nil || branch == "" {
		return ""
	}
	if strings.HasPrefix(branch, "track/") {
		return strings.TrimPrefix(branch, "track/")
	}
	return ""
}

func busBranchFromCwd() string {
	b, _ := runGitOutput("symbolic-ref", "--quiet", "--short", "HEAD") //nolint:errcheck // branch metadata is optional
	return b
}

func busCwd() string {
	cwd, _ := os.Getwd() //nolint:errcheck // cwd metadata is optional
	return cwd
}

func busHost() string {
	h, _ := os.Hostname() //nolint:errcheck // host metadata is optional
	return h
}

func dispatchBus(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: work bus <warn|info|urgent|ack|tail|cursor> [args...]")
	}
	rest := args[1:]
	switch args[0] {
	case "warn":
		return cmdBusEmit("warn", rest)
	case "info":
		return cmdBusEmit("info", rest)
	case "urgent":
		return cmdBusEmit("urgent", rest)
	case "ack":
		return cmdBusAck(rest)
	case "tail":
		return cmdBusTail(rest)
	case "cursor":
		return cmdBusCursor(rest)
	default:
		return fmt.Errorf("unknown `bus` subcommand %q (expect warn|info|urgent|ack|tail|cursor)", args[0])
	}
}

// busDirectedPrefix turns a --to value into the canonical directed-message
// prefix the delivery hook greps for. Accepted forms:
//
//	--to session:<id>   →  "TO session <id>: "
//	--to track:<name>   →  "TO track <name>: "
//
// The convention is textual on purpose: any writer (human, agent, raw echo
// to the JSONL) can address a message without schema support, and the hook
// can match it with a substring check.
func busDirectedPrefix(to string) (string, error) {
	switch {
	case strings.HasPrefix(to, "session:"):
		id := strings.TrimPrefix(to, "session:")
		if id == "" {
			return "", fmt.Errorf("--to session: requires a session id (e.g. session:p1522)")
		}
		return "TO session " + id + ": ", nil
	case strings.HasPrefix(to, "track:"):
		name := strings.TrimPrefix(to, "track:")
		if name == "" {
			return "", fmt.Errorf("--to track: requires a track name")
		}
		return "TO track " + name + ": ", nil
	default:
		return "", fmt.Errorf("--to must be session:<id> or track:<name>, got %q", to)
	}
}

func cmdBusEmit(level string, args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) == 0 {
		return fmt.Errorf("usage: work bus %s <msg> [--to session:<id>|track:<name>] [--track <name>] [--force]", level)
	}
	msg := strings.Join(pos, " ")
	if to := flags["to"]; to != "" {
		prefix, err := busDirectedPrefix(to)
		if err != nil {
			return err
		}
		msg = prefix + msg
	}
	track := flags["track"]
	if track == "" {
		track = busTrackFromCwd()
	}
	ev := BusEvent{
		TS:        now().Format(time.RFC3339),
		Level:     level,
		Msg:       msg,
		Track:     track,
		Owner:     whoami(),
		Host:      busHost(),
		Cwd:       busCwd(),
		Branch:    busBranchFromCwd(),
		SessionID: busSessionID(),
	}
	_, force := flags["force"]
	if err := busAppend(ev, force); err != nil {
		return err
	}

	fmt.Fprintf(os.Stderr, "bus[%s] track=%s session=%s: %s\n", level, ev.Track, ev.SessionID, msg)
	if level == "urgent" {
		// future: optional ntfy push.
		// Today: stderr emphasis only.
		fmt.Fprintln(os.Stderr, "  (urgent — operator should review this run)")
	}
	return nil
}

// busAppend validates, rotates, rate-limits and atomically appends one event.
func busAppend(ev BusEvent, force bool) (err error) {
	// Schema validation — refuse malformed events at emit time
	if err := busValidate(ev); err != nil {
		return err
	}

	path, err := busFilePath()
	if err != nil {
		return err
	}

	// Monthly rotation — archive prior-month file if mtime is from a previous month
	if err := busRotateIfNeeded(path); err != nil {
		// Non-fatal; warn and continue
		fmt.Fprintf(os.Stderr, "warning: bus rotation failed: %v\n", err)
	}

	// Rate-limit identical (level, owner, msg) within busRateLimitWindow
	if !force {
		if err := busRateLimitCheck(path, ev); err != nil {
			return err
		}
	}

	line, err := json.Marshal(ev)
	if err != nil {
		return fmt.Errorf("marshal event: %w", err)
	}
	line = append(line, '\n')

	// Atomic append per POSIX O_APPEND for line-sized (<PIPE_BUF) writes.
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open bus file: %w", err)
	}
	defer func() {
		err = errors.Join(err, f.Close())
	}()
	if _, err := f.Write(line); err != nil {
		return fmt.Errorf("write event: %w", err)
	}
	return nil
}

// cmdBusAck acknowledges receipt of a bus message. Looks up the event whose
// ts matches <ref> (in the live bus file), then emits an info event directed
// back at the sender's session so the delivery hook surfaces it to them:
//
//	work bus ack 2026-08-11T04:56:21Z [--note "picked up; widening in my lane"]
//
// Senders check delivery with: work bus tail | grep '"ref":"<their-ts>"'.
func cmdBusAck(args []string) error {
	flags, pos := parseFlags(args)
	if len(pos) != 1 {
		return fmt.Errorf("usage: work bus ack <ts-of-message> [--note <text>]")
	}
	ref := pos[0]

	path, err := busFilePath()
	if err != nil {
		return err
	}
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open bus file: %w", err)
	}
	defer f.Close()

	var orig *BusEvent
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	for scanner.Scan() {
		var ev BusEvent
		if err := json.Unmarshal(scanner.Bytes(), &ev); err != nil {
			continue
		}
		if ev.TS == ref {
			evCopy := ev
			orig = &evCopy
			// keep scanning: last match wins (ts collisions are rare but possible)
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read bus file: %w", err)
	}
	if orig == nil {
		return fmt.Errorf("no bus event with ts %q in %s (acks only reach the live file, not rotated archives)", ref, path)
	}

	msg := "ACK " + ref
	if orig.SessionID != "" {
		msg = "TO session " + orig.SessionID + ": " + msg
	}
	if note := flags["note"]; note != "" {
		msg += " — " + note
	}
	ack := BusEvent{
		TS:        now().Format(time.RFC3339),
		Level:     "info",
		Msg:       msg,
		Track:     busTrackFromCwd(),
		Owner:     whoami(),
		Host:      busHost(),
		Cwd:       busCwd(),
		Branch:    busBranchFromCwd(),
		SessionID: busSessionID(),
		Ref:       ref,
	}
	if err := busAppend(ack, false); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "bus[ack] → session=%s ref=%s\n", orig.SessionID, ref)
	return nil
}

func cmdBusTail(args []string) error {
	flags, _ := parseFlags(args)
	track := flags["track"]
	since := flags["since"]
	path, err := busFilePath()
	if err != nil {
		return err
	}

	var sinceOffset int64
	if since != "" {
		_, err := fmt.Sscanf(since, "%d", &sinceOffset)
		if err != nil {
			return fmt.Errorf("--since must be a byte offset integer: %w", err)
		}
	}

	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Fprintln(os.Stderr, "bus file does not exist yet:", path)
			return nil
		}
		return fmt.Errorf("open bus file: %w", err)
	}
	defer f.Close()

	if sinceOffset > 0 {
		if _, err := f.Seek(sinceOffset, io.SeekStart); err != nil {
			return fmt.Errorf("seek: %w", err)
		}
	}

	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	count := 0
	for scanner.Scan() {
		line := scanner.Text()
		if track != "" {
			var ev BusEvent
			if err := json.Unmarshal([]byte(line), &ev); err != nil {
				continue
			}
			if ev.Track != track {
				continue
			}
		}
		fmt.Println(line)
		count++
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read bus file: %w", err)
	}
	if count == 0 {
		fmt.Fprintln(os.Stderr, "(no events)")
	}
	return nil
}

func cmdBusCursor(_ []string) error {
	path, err := busFilePath()
	if err != nil {
		return err
	}
	st, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println(0)
			return nil
		}
		return fmt.Errorf("stat bus file: %w", err)
	}
	fmt.Println(st.Size())
	return nil
}
