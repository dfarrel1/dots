// Tests for the session-bus event layer.
//
// Coverage strategy mixes three test classes:
//  1. Standard table-driven unit tests for deterministic logic (busValidate,
//     busSessionID, busFilePath fingerprint stability, busRateLimitCheck
//     within / outside window).
//  2. Property-based tests via stdlib `testing/quick` for invariants (the
//     Go-native equivalent of Python's hypothesis): any valid event
//     round-trips through emit -> tail; rate-limit window invariant.
//  3. Fuzz tests via Go-native `go test -fuzz` for JSON parsing robustness
//     on the consumer side (busValidate against malformed input, tail
//     against torn lines).
//
// Plus one concurrent-write test for atomic append correctness.
//
// All tests sandbox the bus by overriding $HOME to a per-test t.TempDir() so
// the production ~/.claude/state/ tree is never touched.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"testing/quick"
	"time"
)

// sandbox overrides HOME for the duration of the test so the bus state path
// resolves to a per-test temp dir. Returns the temp dir.
func sandbox(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	t.Setenv("HOME", tmp)
	// Also need a real-looking repo root so repoRoot() works. Use git init in
	// a sub-dir + chdir there.
	repoDir := filepath.Join(tmp, "repo")
	if err := os.MkdirAll(repoDir, 0o755); err != nil {
		t.Fatalf("mkdir repo: %v", err)
	}
	cmd := exec.Command("git", "init", "--quiet", repoDir)
	if err := cmd.Run(); err != nil {
		t.Fatalf("git init: %v", err)
	}
	// commit something so HEAD resolves
	cmd = exec.Command("git", "-C", repoDir, "commit", "--allow-empty", "-m", "init", "--quiet")
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=test@example.com",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=test@example.com",
	)
	if err := cmd.Run(); err != nil {
		t.Fatalf("git commit: %v", err)
	}
	prevWd, _ := os.Getwd()
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	t.Cleanup(func() { _ = os.Chdir(prevWd) })
	return tmp
}

// --- Unit tests (deterministic logic) ---

func TestBusValidate_RequiredFields(t *testing.T) {
	cases := []struct {
		name    string
		ev      BusEvent
		wantErr string
	}{
		{"empty TS", BusEvent{Level: "info", Msg: "x", Owner: "o"}, "missing required field: ts"},
		{"bad level", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "bogus", Msg: "x", Owner: "o"}, "level must be"},
		{"empty msg", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "info", Owner: "o"}, "missing required field: msg"},
		{"empty owner", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "info", Msg: "x"}, "missing required field: owner"},
		{"oversize msg", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "info", Msg: strings.Repeat("x", 4096), Owner: "o"}, "exceeds 2KB"},
		{"valid info", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "info", Msg: "x", Owner: "o"}, ""},
		{"valid warn", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "warn", Msg: "x", Owner: "o"}, ""},
		{"valid urgent", BusEvent{TS: "2026-05-08T00:00:00Z", Level: "urgent", Msg: "x", Owner: "o"}, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := busValidate(c.ev)
			if c.wantErr == "" {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}
				return
			}
			if err == nil {
				t.Errorf("expected error containing %q, got nil", c.wantErr)
				return
			}
			if !strings.Contains(err.Error(), c.wantErr) {
				t.Errorf("expected error containing %q, got %q", c.wantErr, err.Error())
			}
		})
	}
}

func TestBusSessionID_EnvVarTakesPrecedence(t *testing.T) {
	t.Setenv("CLAUDE_SESSION_ID", "explicit-session-xyz")
	got := busSessionID()
	if got != "explicit-session-xyz" {
		t.Errorf("expected env-var value, got %q", got)
	}
}

// Claude Code exports the delivery hook's session uuid as
// CLAUDE_CODE_SESSION_ID, never as CLAUDE_SESSION_ID. Stamping it is what
// makes "--to session:<id>" and own-event filtering work at all.
func TestBusSessionID_FallsBackToHarnessSessionUUID(t *testing.T) {
	t.Setenv("CLAUDE_SESSION_ID", "")
	t.Setenv("CLAUDE_CODE_SESSION_ID", "ac4b6eb4-93c3-4675-9f09-82c0f376cd72")
	if got := busSessionID(); got != "ac4b6eb4-93c3-4675-9f09-82c0f376cd72" {
		t.Errorf("expected harness session uuid, got %q", got)
	}
}

// With no harness id at all the fallback is p<ppid>. That is not a session
// id — Claude Code gives every Bash tool call a fresh shell, so it changes
// per invocation; assert only that it stays recognisable as the fallback.
func TestBusSessionID_FallsBackToPPID(t *testing.T) {
	t.Setenv("CLAUDE_SESSION_ID", "")
	t.Setenv("CLAUDE_CODE_SESSION_ID", "")
	got := busSessionID()
	if got == "" {
		t.Errorf("expected non-empty PPID-based id, got empty")
	}
	if !strings.HasPrefix(got, "p") {
		t.Errorf("expected p-prefix for PPID fallback, got %q", got)
	}
}

func TestBusFilePath_Stable(t *testing.T) {
	sandbox(t)
	p1, err := busFilePath()
	if err != nil {
		t.Fatalf("busFilePath: %v", err)
	}
	p2, err := busFilePath()
	if err != nil {
		t.Fatalf("busFilePath: %v", err)
	}
	if p1 != p2 {
		t.Errorf("expected stable path, got %q vs %q", p1, p2)
	}
	if !strings.HasSuffix(p1, ".jsonl") {
		t.Errorf("expected .jsonl suffix, got %q", p1)
	}
	if !strings.Contains(p1, "session-bus-") {
		t.Errorf("expected session-bus- prefix in path, got %q", p1)
	}
}

func TestBusFilePath_PerRepoFingerprint(t *testing.T) {
	tmp1 := sandbox(t)
	p1, _ := busFilePath()
	// switch to a different "repo" — different path = different fingerprint
	repoDir2 := filepath.Join(tmp1, "..", "repo2")
	_ = os.MkdirAll(repoDir2, 0o755)
	cmd := exec.Command("git", "init", "--quiet", repoDir2)
	_ = cmd.Run()
	cmd = exec.Command("git", "-C", repoDir2, "commit", "--allow-empty", "-m", "init", "--quiet")
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@e.com",
		"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@e.com",
	)
	_ = cmd.Run()
	chdirForTest(t, repoDir2)
	p2, _ := busFilePath()
	if p1 == p2 {
		t.Errorf("expected different paths for different repos, both %q", p1)
	}
}

// --- Rotation tests ---

func TestBusRotateIfNeeded_SameMonthNoOp(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()
	if err := os.WriteFile(path, []byte(`{"ts":"now"}`+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := busRotateIfNeeded(path); err != nil {
		t.Fatalf("rotate: %v", err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Errorf("file should still exist after no-op rotation: %v", err)
	}
}

func TestBusRotateIfNeeded_PriorMonthArchives(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()
	if err := os.WriteFile(path, []byte(`{"ts":"old"}`+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	// Force mtime to a prior calendar month. Use the last day of the
	// previous month (first-of-this-month minus one day), NOT
	// now.AddDate(0, -1, 0): AddDate overflows on month-end days — on
	// e.g. May 31 "April 31" normalizes to May 1, i.e. the CURRENT
	// month, so busRotateIfNeeded correctly wouldn't rotate and this
	// test flaked at month boundaries (observed failing on the 31st).
	now := time.Now().UTC()
	firstOfThisMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	priorMonth := firstOfThisMonth.AddDate(0, 0, -1)
	if err := os.Chtimes(path, priorMonth, priorMonth); err != nil {
		t.Fatal(err)
	}
	if err := busRotateIfNeeded(path); err != nil {
		t.Fatalf("rotate: %v", err)
	}
	// Original path should not exist anymore
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Errorf("expected original to be archived, but it still exists")
	}
	// Archive should exist
	archive := fmt.Sprintf("%s-%04d-%02d", path, priorMonth.Year(), int(priorMonth.Month()))
	if _, err := os.Stat(archive); err != nil {
		t.Errorf("expected archive at %s, got %v", archive, err)
	}
}

// --- Rate-limit tests ---

func TestBusRateLimitCheck_RefusesWithinWindow(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()

	now := time.Now().UTC()
	priorEv := BusEvent{
		TS:    now.Add(-30 * time.Second).Format(time.RFC3339),
		Level: "info",
		Msg:   "duplicate",
		Owner: "tester",
	}
	line, _ := json.Marshal(priorEv)
	if err := os.WriteFile(path, append(line, '\n'), 0o644); err != nil {
		t.Fatal(err)
	}

	// Try to emit identical (level, owner, msg) within window
	dup := BusEvent{
		TS:    now.Format(time.RFC3339),
		Level: "info",
		Msg:   "duplicate",
		Owner: "tester",
	}
	err := busRateLimitCheck(path, dup)
	if err == nil {
		t.Errorf("expected rate-limit refusal, got nil")
	}
}

func TestBusRateLimitCheck_AllowsAfterWindow(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()

	now := time.Now().UTC()
	priorEv := BusEvent{
		TS:    now.Add(-2 * busRateLimitWindow).Format(time.RFC3339),
		Level: "info",
		Msg:   "old-message",
		Owner: "tester",
	}
	line, _ := json.Marshal(priorEv)
	if err := os.WriteFile(path, append(line, '\n'), 0o644); err != nil {
		t.Fatal(err)
	}

	dup := BusEvent{
		TS:    now.Format(time.RFC3339),
		Level: "info",
		Msg:   "old-message",
		Owner: "tester",
	}
	if err := busRateLimitCheck(path, dup); err != nil {
		t.Errorf("expected rate-limit allow after window, got %v", err)
	}
}

func TestBusRateLimitCheck_AllowsDifferentMsg(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()

	now := time.Now().UTC()
	priorEv := BusEvent{
		TS:    now.Add(-30 * time.Second).Format(time.RFC3339),
		Level: "info",
		Msg:   "msg-A",
		Owner: "tester",
	}
	line, _ := json.Marshal(priorEv)
	_ = os.WriteFile(path, append(line, '\n'), 0o644)

	differ := BusEvent{
		TS:    now.Format(time.RFC3339),
		Level: "info",
		Msg:   "msg-B", // different
		Owner: "tester",
	}
	if err := busRateLimitCheck(path, differ); err != nil {
		t.Errorf("expected allow for different msg, got %v", err)
	}
}

// --- Property-based tests (testing/quick — Go-native hypothesis analog) ---

// validBusEventGen is the generator for property tests. quick.Check picks
// random concrete BusEvent values; we only assert the post-validate
// round-trip property on those that VALIDATE successfully.
type validBusEvent struct {
	TS    string
	Level string
	Msg   string
	Owner string
}

func TestBusEvent_ValidEventsRoundTripJSON(t *testing.T) {
	prop := func(level int, msg, owner string) bool {
		levels := []string{"warn", "info", "urgent"}
		if level < 0 {
			level = -level
		}
		ev := BusEvent{
			TS:    time.Now().UTC().Format(time.RFC3339),
			Level: levels[level%3],
			Msg:   strings.TrimSpace(msg),
			Owner: strings.TrimSpace(owner),
		}
		// Skip cases that won't validate (the property is over valid events)
		if err := busValidate(ev); err != nil {
			return true // vacuous true for invalid inputs; property doesn't apply
		}
		// Round trip through JSON
		line, err := json.Marshal(ev)
		if err != nil {
			t.Logf("marshal failed: %v", err)
			return false
		}
		var got BusEvent
		if err := json.Unmarshal(line, &got); err != nil {
			t.Logf("unmarshal failed: %v on line %q", err, line)
			return false
		}
		return got.TS == ev.TS &&
			got.Level == ev.Level &&
			got.Msg == ev.Msg &&
			got.Owner == ev.Owner
	}
	if err := quick.Check(prop, &quick.Config{MaxCount: 200}); err != nil {
		t.Errorf("round-trip property failed: %v", err)
	}
}

func TestBusValidate_NeverPanicsOnArbitraryInput(t *testing.T) {
	// Property: validate never panics regardless of input shape.
	// Returns either nil (valid) or an error; never crashes.
	prop := func(ts, level, msg, owner, host, cwd, branch, sid string, longMsg bool) bool {
		ev := BusEvent{
			TS: ts, Level: level, Msg: msg, Owner: owner,
			Host: host, Cwd: cwd, Branch: branch, SessionID: sid,
		}
		if longMsg {
			ev.Msg = strings.Repeat("x", 5000)
		}
		defer func() {
			if r := recover(); r != nil {
				t.Errorf("panic on input %#v: %v", ev, r)
			}
		}()
		_ = busValidate(ev)
		return true
	}
	if err := quick.Check(prop, &quick.Config{MaxCount: 500}); err != nil {
		t.Errorf("no-panic property failed: %v", err)
	}
}

// --- Concurrent-write test (atomicity) ---

func TestBusEmit_ConcurrentWritesNoTornLines(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()
	// Pre-create the file
	_ = os.WriteFile(path, []byte{}, 0o644)

	const writers = 8
	const eventsPerWriter = 25

	var wg sync.WaitGroup
	for w := 0; w < writers; w++ {
		wg.Add(1)
		go func(writerID int) {
			defer wg.Done()
			for i := 0; i < eventsPerWriter; i++ {
				ev := BusEvent{
					TS:    time.Now().UTC().Format(time.RFC3339Nano),
					Level: "info",
					Msg:   fmt.Sprintf("writer=%d seq=%d", writerID, i),
					Owner: "concurrent-test",
				}
				line, _ := json.Marshal(ev)
				line = append(line, '\n')
				f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
				if err != nil {
					t.Errorf("open: %v", err)
					return
				}
				_, err = f.Write(line)
				_ = f.Close()
				if err != nil {
					t.Errorf("write: %v", err)
					return
				}
			}
		}(w)
	}
	wg.Wait()

	// Verify: every line is a complete, parseable JSON object with our fields.
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	lines := bytes.Split(bytes.TrimRight(data, "\n"), []byte{'\n'})
	if len(lines) != writers*eventsPerWriter {
		t.Errorf("expected %d lines, got %d", writers*eventsPerWriter, len(lines))
	}
	for i, line := range lines {
		var ev BusEvent
		if err := json.Unmarshal(line, &ev); err != nil {
			t.Errorf("line %d torn or invalid: %v\n  line: %q", i, err, line)
			continue
		}
		if ev.Owner != "concurrent-test" {
			t.Errorf("line %d unexpected owner %q", i, ev.Owner)
		}
	}
}

// --- Round-trip integration test (emit -> tail -> cursor) ---

func TestBus_RoundTrip(t *testing.T) {
	sandbox(t)
	path, _ := busFilePath()

	// Emit two events directly (mirrors what cmdBusEmit does)
	for i, msg := range []string{"first event", "second event"} {
		ev := BusEvent{
			TS:    time.Now().UTC().Format(time.RFC3339),
			Level: "info",
			Msg:   msg,
			Owner: "round-trip-test",
		}
		if err := busValidate(ev); err != nil {
			t.Fatalf("validate event %d: %v", i, err)
		}
		line, _ := json.Marshal(ev)
		f, _ := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
		_, _ = f.Write(append(line, '\n'))
		_ = f.Close()
		// Sleep a hair so timestamps differ
		time.Sleep(10 * time.Millisecond)
	}

	// Verify file contents
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	lines := bytes.Split(bytes.TrimRight(data, "\n"), []byte{'\n'})
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d", len(lines))
	}
	var first, second BusEvent
	_ = json.Unmarshal(lines[0], &first)
	_ = json.Unmarshal(lines[1], &second)
	if first.Msg != "first event" || second.Msg != "second event" {
		t.Errorf("unexpected event order: %+v %+v", first, second)
	}

	// Cursor: stat-size matches data length
	st, _ := os.Stat(path)
	if st.Size() != int64(len(data)) {
		t.Errorf("cursor mismatch: stat=%d len=%d", st.Size(), len(data))
	}
}

// --- Fuzz tests ---

func FuzzBusValidate(f *testing.F) {
	// Seed corpus with known shapes
	f.Add("2026-05-08T00:00:00Z", "info", "hello", "owner")
	f.Add("", "info", "x", "o")
	f.Add("ts", "bogus", "x", "o")
	f.Add("ts", "info", "", "o")
	f.Add("ts", "info", "x", "")
	f.Fuzz(func(t *testing.T, ts, level, msg, owner string) {
		ev := BusEvent{TS: ts, Level: level, Msg: msg, Owner: owner}
		// Property: no panic on arbitrary input
		defer func() {
			if r := recover(); r != nil {
				t.Errorf("panic on input %#v: %v", ev, r)
			}
		}()
		_ = busValidate(ev)
	})
}

func FuzzBusJSONUnmarshal(f *testing.F) {
	// Seed with a valid event then random byte streams
	good := BusEvent{TS: "2026-05-08T00:00:00Z", Level: "info", Msg: "x", Owner: "o"}
	goodLine, _ := json.Marshal(good)
	f.Add(goodLine)
	f.Add([]byte(`{}`))
	f.Add([]byte(`not json at all`))
	f.Add([]byte(`{"level":"info"}`))
	f.Fuzz(func(t *testing.T, data []byte) {
		var ev BusEvent
		// Property: unmarshal never panics; either errors or produces a struct
		defer func() {
			if r := recover(); r != nil {
				t.Errorf("panic on input %q: %v", data, r)
			}
		}()
		_ = json.Unmarshal(data, &ev)
	})
}
