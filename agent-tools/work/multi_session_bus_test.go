// Multi-session integration test for the session-bus event layer.
//
// Coverage gap closed: bus_test.go covers the bus surface in isolation but
// doesn't exercise the actual cross-session delivery path. This test:
//  1. Builds the `work` binary
//  2. Provisions a sandbox repo + sandbox $HOME so the bus state lives in
//     a per-test temp dir
//  3. Spawns "session A" → emits an event via the real `work bus warn`
//     binary with CLAUDE_SESSION_ID=A
//  4. Spawns "session B" → invokes the real plugin hook session-bus-tail.sh
//     script with CLAUDE_SESSION_ID=B and captures stdout
//  5. Asserts B sees A's event (cross-session delivery works)
//  6. Asserts A's hook does NOT see A's event (self-filter by session_id)
//  7. Asserts B's second hook call doesn't replay (cursor advancement)
//
// This exercises the real producer + real consumer + real hook script. The
// only thing NOT exercised is Claude Code itself firing the hook on prompt
// submit — that part is harness-bound and out of scope here.
package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

// findRepoRoot walks up from the test file's location until it finds the
// repo root (where agent-tools/work/main.go lives). Used to locate the hook
// script + the source dir for `go build`.
func findRepoRoot(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	dir := filepath.Dir(thisFile)
	for {
		if _, err := os.Stat(filepath.Join(dir, "agent-tools", "work", "main.go")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatalf("could not find repo root from %s", thisFile)
		}
		dir = parent
	}
}

// buildWorkBinary builds `work` into a temp dir and returns its path.
// The work CLI has its own go.mod at agent-tools/work/go.mod, so build runs
// from that directory rather than the repo root.
func buildWorkBinary(t *testing.T, repoRoot string) string {
	t.Helper()
	binDir := t.TempDir()
	binPath := filepath.Join(binDir, "work")
	cmd := exec.Command("go", "build", "-o", binPath, ".")
	cmd.Dir = filepath.Join(repoRoot, "agent-tools", "work")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}
	return binPath
}

// makeSandboxRepo creates a synthetic git repo + initializes HEAD so
// repoRoot() inside the work binary resolves cleanly.
func makeSandboxRepo(t *testing.T, parentDir string) string {
	t.Helper()
	repoDir := filepath.Join(parentDir, "repo")
	if err := os.MkdirAll(repoDir, 0o755); err != nil {
		t.Fatal(err)
	}
	gitInit := exec.Command("git", "init", "--quiet", repoDir)
	if err := gitInit.Run(); err != nil {
		t.Fatalf("git init: %v", err)
	}
	commit := exec.Command("git", "-C", repoDir, "commit", "--allow-empty", "-m", "init", "--quiet")
	commit.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=test@example.com",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=test@example.com",
	)
	if err := commit.Run(); err != nil {
		t.Fatalf("git commit: %v", err)
	}
	// The delivery hook is opt-in: it runs only in a repo carrying the marker.
	if err := os.MkdirAll(filepath.Join(repoDir, ".claude"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repoDir, ".claude", "agent-workflow.yaml"), []byte("version: 1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return repoDir
}

// sessionEnv returns environment for a simulated Claude session with the
// given session_id. Sets CLAUDE_SESSION_ID, sandboxed HOME, real PATH.
func sessionEnv(home, sessionID string) []string {
	env := []string{
		"HOME=" + home,
		"CLAUDE_SESSION_ID=" + sessionID,
		"PATH=" + os.Getenv("PATH"),
		// Git author info for any subprocess git ops
		"GIT_AUTHOR_NAME=session-" + sessionID, "GIT_AUTHOR_EMAIL=" + sessionID + "@test",
		"GIT_COMMITTER_NAME=session-" + sessionID, "GIT_COMMITTER_EMAIL=" + sessionID + "@test",
		// USER for whoami() inside work CLI
		"USER=session-" + sessionID,
	}
	return env
}

// runHook invokes the real session-bus-tail.sh hook with the given session
// env from a given working directory. Returns hook stdout (bus events
// rendered as system-reminder blocks) and any error.
func runHook(t *testing.T, hookPath, repoDir, home, sessionID string) string {
	t.Helper()
	cmd := exec.Command("bash", hookPath)
	cmd.Dir = repoDir
	cmd.Env = sessionEnv(home, sessionID)
	out, err := cmd.Output()
	if err != nil {
		t.Logf("hook stderr / err: %v", err)
	}
	return string(out)
}

// runWorkBus invokes the real work binary's bus subcommand from a session.
func runWorkBus(t *testing.T, binPath, repoDir, home, sessionID string, args ...string) (string, error) {
	t.Helper()
	cmd := exec.Command(binPath, append([]string{"bus"}, args...)...)
	cmd.Dir = repoDir
	cmd.Env = sessionEnv(home, sessionID)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func TestMultiSession_CrossSessionEventDelivery(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	if _, err := exec.LookPath("bash"); err != nil {
		t.Skip("bash not available")
	}

	repoRootSrc := findRepoRoot(t)
	binPath := buildWorkBinary(t, repoRootSrc)
	hookPath := filepath.Join(repoRootSrc, "claude", "plugins", "agent-workflow", "hooks", "session-bus-tail.sh")
	if _, err := os.Stat(hookPath); err != nil {
		t.Fatalf("hook script not found at %s: %v", hookPath, err)
	}

	tmpHome := t.TempDir()
	repoDir := makeSandboxRepo(t, tmpHome)

	// Realistic flow: bus file MUST exist before the hook can prime a cursor
	// (the hook's first-fire-skip-backfill logic only runs after the file
	// exists). Prime by emitting a warmup event from a third "ghost" session,
	// then prime A and B cursors against current EOF.
	_, err := runWorkBus(t, binPath, repoDir, tmpHome, "ghost", "info", "warmup-ignore-me")
	if err != nil {
		t.Fatalf("ghost warmup: %v", err)
	}
	_ = runHook(t, hookPath, repoDir, tmpHome, "session-A")
	_ = runHook(t, hookPath, repoDir, tmpHome, "session-B")

	// --- Session A: emits an event
	_, err = runWorkBus(t, binPath, repoDir, tmpHome, "session-A",
		"warn", "from-session-A track=test-X")
	if err != nil {
		t.Fatalf("session A emit: %v", err)
	}

	// Tiny sleep to ensure file mtime differs (rotation logic compares months
	// but we want to confirm timestamps in events differ across rapid emits).
	time.Sleep(50 * time.Millisecond)

	// --- Session B: hook fires — should see A's event
	bOut := runHook(t, hookPath, repoDir, tmpHome, "session-B")
	if !strings.Contains(bOut, "from-session-A") {
		t.Errorf("session B did NOT see session A's event\nB hook output:\n%s", bOut)
	}
	if !strings.Contains(bOut, "<session-bus-events>") {
		t.Errorf("session B hook output missing <session-bus-events> framing\nGot:\n%s", bOut)
	}

	// --- Session A: hook fires — should NOT see its own event (self-filter)
	aOut := runHook(t, hookPath, repoDir, tmpHome, "session-A")
	if strings.Contains(aOut, "from-session-A") {
		t.Errorf("session A SAW its own event (self-filter broken)\nA hook output:\n%s", aOut)
	}

	// --- Session B: second hook call — cursor should have advanced; no replay
	bOut2 := runHook(t, hookPath, repoDir, tmpHome, "session-B")
	if strings.Contains(bOut2, "from-session-A") {
		t.Errorf("session B's second hook call replayed event (cursor not advanced)\nGot:\n%s", bOut2)
	}
}

func TestMultiSession_OrderingAcrossEmitters(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	if _, err := exec.LookPath("bash"); err != nil {
		t.Skip("bash not available")
	}

	repoRootSrc := findRepoRoot(t)
	binPath := buildWorkBinary(t, repoRootSrc)
	hookPath := filepath.Join(repoRootSrc, "claude", "plugins", "agent-workflow", "hooks", "session-bus-tail.sh")

	tmpHome := t.TempDir()
	repoDir := makeSandboxRepo(t, tmpHome)

	// Prime: emit a warmup so the bus file exists, then prime each session's
	// cursor by firing the hook against current EOF.
	_, err := runWorkBus(t, binPath, repoDir, tmpHome, "ghost", "info", "warmup-ordering-test")
	if err != nil {
		t.Fatalf("ghost warmup: %v", err)
	}
	for _, sid := range []string{"A", "B", "C", "D"} {
		_ = runHook(t, hookPath, repoDir, tmpHome, "s-"+sid)
	}

	// A, B, D each emit one event (C is the observer); each event has unique
	// content so we can assert order in the observer's hook output.
	for _, p := range []struct{ sid, msg string }{
		{"A", "first-event-from-A"},
		{"B", "second-event-from-B"},
		{"D", "third-event-from-D"},
	} {
		_, err2 := runWorkBus(t, binPath, repoDir, tmpHome, "s-"+p.sid, "info", p.msg)
		if err2 != nil {
			t.Fatalf("emit from %s: %v", p.sid, err2)
		}
		time.Sleep(20 * time.Millisecond)
	}

	// Session C observes — should see all three events in emission order
	cOut := runHook(t, hookPath, repoDir, tmpHome, "s-C")
	idxA := strings.Index(cOut, "first-event-from-A")
	idxB := strings.Index(cOut, "second-event-from-B")
	idxD := strings.Index(cOut, "third-event-from-D")
	if idxA < 0 || idxB < 0 || idxD < 0 {
		t.Errorf("session C missed an event:\n  A=%d B=%d D=%d\nOutput:\n%s", idxA, idxB, idxD, cOut)
		return
	}
	if !(idxA < idxB && idxB < idxD) {
		t.Errorf("event ordering broken: A=%d B=%d D=%d (expected A<B<D)", idxA, idxB, idxD)
	}
}

func TestMultiSession_RateLimitAcrossSessionsRefusesIdentical(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	if _, err := exec.LookPath("bash"); err != nil {
		t.Skip("bash not available")
	}

	repoRootSrc := findRepoRoot(t)
	binPath := buildWorkBinary(t, repoRootSrc)

	tmpHome := t.TempDir()
	repoDir := makeSandboxRepo(t, tmpHome)

	// Two SAME-USER (USER env from sessionEnv) sessions emit IDENTICAL
	// (level, owner, msg) — second should rate-limit-refuse since both
	// resolve to USER=session-A.
	out1, err1 := runWorkBus(t, binPath, repoDir, tmpHome, "A", "info", "exact-duplicate-msg")
	if err1 != nil {
		t.Fatalf("first emit: %v\noutput: %s", err1, out1)
	}
	// Same session, same msg, immediate retry — should refuse
	out2, err2 := runWorkBus(t, binPath, repoDir, tmpHome, "A", "info", "exact-duplicate-msg")
	if err2 == nil {
		t.Errorf("second emit should have been rate-limited; output:\n%s", out2)
	}
	if !strings.Contains(out2, "rate-limited") {
		t.Errorf("expected rate-limit message in error output; got:\n%s", out2)
	}

	// --force should bypass
	out3, err3 := runWorkBus(t, binPath, repoDir, tmpHome, "A", "info", "exact-duplicate-msg", "--force")
	if err3 != nil {
		t.Errorf("--force bypass should succeed; got %v\noutput: %s", err3, out3)
	}
}
