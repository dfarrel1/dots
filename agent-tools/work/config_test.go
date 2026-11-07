package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func writeMarker(t *testing.T, repo, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(repo, ".claude"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, markerRelPath), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestConfig_DefaultsWithoutMarker(t *testing.T) {
	_, restore := fakeRepo(t)
	defer restore()
	c, err := loadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if c.TrackerDir != defaultTrackerDir || c.RolesDir != defaultRolesDir ||
		c.WorktreesDir != defaultWorktreesDir || c.Trunk != defaultTrunk || c.Bus != "" || c.Marker != "" {
		t.Fatalf("defaults wrong: %+v", c)
	}
	if got := c.legacyTrackerRelPath(); got != "docs/project/active-work.yaml" {
		t.Fatalf("legacy path = %q", got)
	}
}

func TestConfig_MarkerOverridesPaths(t *testing.T) {
	dir, restore := fakeRepo(t)
	defer restore()
	writeMarker(t, dir, "version: 1\ntracker_dir: .agents/tracks\nroles_dir: .agents/roles\nworktrees_dir: wt\ntrunk: trunk\n")

	root, _ := repoRoot()
	d, err := trackerDir()
	if err != nil {
		t.Fatal(err)
	}
	if d != filepath.Join(root, ".agents/tracks") {
		t.Fatalf("trackerDir = %q", d)
	}
	r, _ := rolesDir()
	if r != filepath.Join(root, ".agents/roles") {
		t.Fatalf("rolesDir = %q", r)
	}
	lp, _ := trackerPath()
	if lp != filepath.Join(root, ".agents/tracks.yaml") {
		t.Fatalf("legacy trackerPath = %q", lp)
	}
	if c := cfg(); c.WorktreesDir != "wt" || c.Trunk != "trunk" {
		t.Fatalf("cfg = %+v", c)
	}
}

func TestConfig_PickupWritesUnderConfiguredTrackerDir(t *testing.T) {
	dir, restore := fakeRepo(t)
	defer restore()
	writeMarker(t, dir, "tracker_dir: coord/active\n")
	if err := cmdPickup([]string{"demo", "--note", "x"}); err != nil {
		t.Fatalf("pickup: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "coord/active/tracks/demo.yaml")); err != nil {
		t.Fatalf("track not written under the configured dir: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "docs/project/active-work")); !os.IsNotExist(err) {
		t.Fatalf("default dir must not be created when the marker names another")
	}
}

func TestConfig_RejectsEscapingPathsAndBadBusName(t *testing.T) {
	for _, body := range []string{"tracker_dir: ../outside\n", "roles_dir: /etc\n", "bus: has space\n", "bus: a/b\n", "tracker_dir: [unclosed\n"} {
		dir, restore := fakeRepo(t)
		writeMarker(t, dir, body)
		if _, err := loadConfig(); err == nil {
			t.Errorf("marker %q accepted", body)
		}
		restore()
	}
}

func TestBusFilePath_NamedBusSharedAcrossRepos(t *testing.T) {
	tmp := sandbox(t) // repo A, HOME sandboxed, cwd = repo A
	repoA, _ := os.Getwd()
	writeMarker(t, repoA, "bus: team-x\n")
	pA, err := busFilePath()
	if err != nil {
		t.Fatal(err)
	}
	if want := filepath.Join(tmp, ".claude", "state", "session-bus-team-x.jsonl"); pA != want {
		t.Fatalf("named bus path = %q, want %q", pA, want)
	}

	repoB := filepath.Join(tmp, "repo-b")
	if out, err := exec.Command("git", "init", "--quiet", repoB).CombinedOutput(); err != nil {
		t.Fatalf("git init: %v %s", err, out)
	}
	writeMarker(t, repoB, "bus: team-x\n")
	if err := os.Chdir(repoB); err != nil {
		t.Fatal(err)
	}
	pB, _ := busFilePath()
	if pA != pB {
		t.Fatalf("sibling repos on one named bus got different files: %q vs %q", pA, pB)
	}

	writeMarker(t, repoB, "version: 1\n")
	pB2, _ := busFilePath()
	if pB2 == pA || !strings.Contains(filepath.Base(pB2), "session-bus-") {
		t.Fatalf("without bus: the repo must fall back to its per-clone bus, got %q", pB2)
	}
}

func TestRemotesWithMain_UsesConfiguredTrunkAndAnyRemoteName(t *testing.T) {
	sandbox(t)
	repo, _ := os.Getwd()
	run := func(args ...string) {
		t.Helper()
		cmd := exec.Command("git", args...)
		cmd.Env = append(os.Environ(), "GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@t", "GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@t")
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v %s", args, err, out)
		}
	}
	// Two remotes, neither called origin, each with a "develop" trunk ref.
	run("-C", repo, "update-ref", "refs/remotes/upstream/develop", "HEAD")
	run("-C", repo, "update-ref", "refs/remotes/fork/develop", "HEAD")
	run("-C", repo, "remote", "add", "upstream", "https://example.invalid/a/b.git")
	run("-C", repo, "remote", "add", "fork", "git@example.invalid:c/b.git")

	if got := remotesWithMain(); len(got) != 1 || got[0] != "origin" {
		t.Fatalf("with trunk main and no */main refs, want the origin fallback, got %v", got)
	}
	writeMarker(t, repo, "trunk: develop\n")
	got := remotesWithMain()
	if len(got) != 2 {
		t.Fatalf("want both remotes carrying develop, got %v", got)
	}
	if remoteSlug("fork") != "c/b" || remoteSlug("upstream") != "a/b" {
		t.Fatalf("slugs: %q %q", remoteSlug("fork"), remoteSlug("upstream"))
	}
}
