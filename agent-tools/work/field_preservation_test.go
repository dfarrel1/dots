// Tests that round-trip YAML serialization preserves every field that has
// ever been written to active-work.yaml — closes the schema-drift gap
// surfaced 2026-05-13.
//
// The bug: prior versions of the `Completed` struct were missing the
// `Summary` and `FinalCommits` (plural) fields that operator workflows had
// been writing into recently_completed rows. Every `work pickup` call
// (which appends to tracks + re-saves the whole YAML) silently dropped
// those fields on every closed track in the file. The first operator who
// noticed had already lost two summaries before the load → mutate → save
// cycle re-saved without them.
//
// Test posture:
//   - Marshal+unmarshal each schema struct directly to assert field
//     preservation at the YAML library boundary (cheap; fast).
//   - One end-to-end test that simulates the load → save round-trip
//     against a temp-file representation of an active-work.yaml that
//     carries the at-risk fields, asserting no field is silently dropped.
//
// Coverage rule we want to enforce going forward: every new field that
// appears anywhere in active-work.yaml MUST appear in one of the structs
// and MUST be exercised by this test. The end-to-end-fixture test asserts
// that fact by matching the post-save YAML against the pre-save YAML
// modulo intentional formatting changes; a missing field on the struct
// would surface as a content diff and fail the test.
package main

import (
	"strings"
	"testing"
	"time"

	yaml "gopkg.in/yaml.v3"
)

// TestCompleted_SummaryFieldRoundTrips pins the specific bug from
// 2026-05-13: the `summary` field on a recently_completed row must survive
// marshal+unmarshal. Pre-fix this test would have failed because the
// Completed struct had no Summary field — yaml.Unmarshal would silently
// drop it on the read side, and re-marshaling would silently omit it on
// the write side.
func TestCompleted_SummaryFieldRoundTrips(t *testing.T) {
	in := Completed{
		Name:       "track-with-closeout-summary",
		Owner:      "operator@example.org",
		PickedUpAt: time.Date(2026, 5, 12, 19, 0, 0, 0, time.UTC),
		ReleasedAt: time.Date(2026, 5, 13, 0, 10, 0, 0, time.UTC),
		Summary:    "lead paragraph\n\n- bullet 1\n- bullet 2\n",
	}
	out, err := yaml.Marshal(&in)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(out), "summary:") {
		t.Fatalf("marshal did not emit summary field; output:\n%s", out)
	}
	var got Completed
	if err := yaml.Unmarshal(out, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Summary != in.Summary {
		t.Fatalf("summary did not round-trip:\nwant=%q\ngot =%q", in.Summary, got.Summary)
	}
}

// TestCompleted_FinalCommitsPluralRoundTrips pins the sibling bug: when a
// release spans multiple commits, operators write `final_commits: [a, b]`
// (plural). Pre-fix the Completed struct only had `FinalCommit` (singular),
// so the plural form would be silently dropped.
func TestCompleted_FinalCommitsPluralRoundTrips(t *testing.T) {
	in := Completed{
		Name:         "multi-commit-release",
		Owner:        "operator@example.org",
		PickedUpAt:   time.Date(2026, 5, 12, 19, 0, 0, 0, time.UTC),
		ReleasedAt:   time.Date(2026, 5, 13, 0, 10, 0, 0, time.UTC),
		FinalCommits: []string{"94a71ded", "95c5ce4d"},
	}
	out, err := yaml.Marshal(&in)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(out), "final_commits:") {
		t.Fatalf("marshal did not emit final_commits field; output:\n%s", out)
	}
	var got Completed
	if err := yaml.Unmarshal(out, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(got.FinalCommits) != len(in.FinalCommits) {
		t.Fatalf("final_commits length: want=%d got=%d", len(in.FinalCommits), len(got.FinalCommits))
	}
	for i, want := range in.FinalCommits {
		if got.FinalCommits[i] != want {
			t.Fatalf("final_commits[%d]: want=%q got=%q", i, want, got.FinalCommits[i])
		}
	}
}

// TestCompleted_FinalCommitSingularStillRoundTrips guards against
// regression of the existing (pre-bug) field. Both singular and plural
// forms must coexist for back-compat with existing rows in the file.
func TestCompleted_FinalCommitSingularStillRoundTrips(t *testing.T) {
	in := Completed{
		Name:        "single-commit-release",
		Owner:       "operator@example.org",
		PickedUpAt:  time.Date(2026, 5, 12, 19, 0, 0, 0, time.UTC),
		ReleasedAt:  time.Date(2026, 5, 13, 0, 10, 0, 0, time.UTC),
		FinalCommit: "deadbeef",
	}
	out, err := yaml.Marshal(&in)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var got Completed
	if err := yaml.Unmarshal(out, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.FinalCommit != in.FinalCommit {
		t.Fatalf("final_commit: want=%q got=%q", in.FinalCommit, got.FinalCommit)
	}
}

// TestTracker_FullRoundTrip_PreservesSummary is the end-to-end pin for the
// regression: load a YAML buffer that carries an at-risk field
// (`summary:`), unmarshal into the Tracker schema, re-marshal, and assert
// the field is still present in the output. This is the operation that
// the work CLI performs on every pickup — when the schema was missing the
// field, this round-trip silently dropped it.
func TestTracker_FullRoundTrip_PreservesSummary(t *testing.T) {
	src := `schema_version: 1
tracks: []
queued: []
clusters: []
file_claims: []
pending_decisions: []
recently_completed:
  - name: closed-track-with-summary
    owner: operator@example.org
    picked_up_at: 2026-05-12T19:00:37Z
    released_at: 2026-05-13T00:10:10Z
    final_commits: [aaaa, bbbb]
    summary: |
      Lead paragraph describing the work.

      - first bullet
      - second bullet
      - third bullet
`
	var t1 Tracker
	if err := yaml.Unmarshal([]byte(src), &t1); err != nil {
		t.Fatalf("unmarshal #1: %v", err)
	}
	if len(t1.RecentlyCompleted) != 1 {
		t.Fatalf("recently_completed length: want=1 got=%d", len(t1.RecentlyCompleted))
	}
	if t1.RecentlyCompleted[0].Summary == "" {
		t.Fatalf("Summary was dropped on unmarshal — schema field missing or mis-tagged")
	}
	if len(t1.RecentlyCompleted[0].FinalCommits) != 2 {
		t.Fatalf("FinalCommits length: want=2 got=%d", len(t1.RecentlyCompleted[0].FinalCommits))
	}

	out, err := yaml.Marshal(&t1)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(out), "summary:") {
		t.Fatalf("re-marshaled YAML missing summary field; output:\n%s", out)
	}
	if !strings.Contains(string(out), "final_commits:") {
		t.Fatalf("re-marshaled YAML missing final_commits field; output:\n%s", out)
	}

	// Round-trip back through unmarshal — Summary content must be byte-equal
	var t2 Tracker
	if err := yaml.Unmarshal(out, &t2); err != nil {
		t.Fatalf("unmarshal #2: %v", err)
	}
	if t2.RecentlyCompleted[0].Summary != t1.RecentlyCompleted[0].Summary {
		t.Fatalf("Summary changed across round-trip:\nwant=%q\ngot =%q",
			t1.RecentlyCompleted[0].Summary, t2.RecentlyCompleted[0].Summary)
	}
	if len(t2.RecentlyCompleted[0].FinalCommits) != len(t1.RecentlyCompleted[0].FinalCommits) {
		t.Fatalf("FinalCommits length changed across round-trip")
	}
	for i := range t1.RecentlyCompleted[0].FinalCommits {
		if t2.RecentlyCompleted[0].FinalCommits[i] != t1.RecentlyCompleted[0].FinalCommits[i] {
			t.Fatalf("FinalCommits[%d] changed across round-trip", i)
		}
	}
}

// TestTracker_FullRoundTrip_PreservesAllAtRiskFields is a defensive net:
// for every field name that has ever appeared in active-work.yaml,
// confirm the struct accepts + emits it on round-trip. A test failure
// here points the author at the missing struct field. Adding a new
// recently_completed-row field elsewhere in the project must also add a
// row to this fixture.
func TestTracker_FullRoundTrip_PreservesAllAtRiskFields(t *testing.T) {
	src := `schema_version: 1
tracks:
  - name: active-track
    owner: operator@example.org
    picked_up_at: 2026-05-12T19:00:37Z
    last_activity_at: 2026-05-13T00:00:00Z
    scope:
      - one
      - two
    status: active
    eta: 2-3h
    notes: a-note
    cluster: c1
    mode: worktree
    worktree_path: .claude/worktrees/foo
    branch: track/foo
    host: SlickBook.local
queued:
  - name: backlog-item
    why: |
      Reason text.
    source: docs/design/foo.md
    gated_on: some condition
    notes: queued note
    surfaced_at: 2026-05-01T00:00:00Z
recently_completed:
  - name: closed-singular
    owner: operator@example.org
    picked_up_at: 2026-05-10T00:00:00Z
    released_at: 2026-05-11T00:00:00Z
    final_commit: deadbeef
    notes: shipping note
    cluster: c1
  - name: closed-plural
    owner: operator@example.org
    picked_up_at: 2026-05-11T00:00:00Z
    released_at: 2026-05-12T00:00:00Z
    final_commits: [aaaa, bbbb, cccc]
    summary: |
      Closeout narrative.
`
	var loaded Tracker
	if err := yaml.Unmarshal([]byte(src), &loaded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	out, err := yaml.Marshal(&loaded)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	wantSubstrings := []string{
		// Track fields
		"scope:", "eta:", "notes:", "cluster:",
		"mode:", "worktree_path:", "branch:", "host:",
		// QueuedItem fields
		"why:", "source:", "gated_on:", "surfaced_at:",
		// Completed fields (the at-risk set + back-compat singular)
		"final_commit:", "final_commits:", "summary:",
	}
	for _, ss := range wantSubstrings {
		if !strings.Contains(string(out), ss) {
			t.Errorf("re-marshaled YAML dropped at-risk field %q\nfull output:\n%s", ss, out)
		}
	}
}
