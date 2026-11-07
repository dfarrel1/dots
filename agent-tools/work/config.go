package main

// Per-repo configuration: .claude/agent-workflow.yaml at the repo root.
//
// The marker is what switches a repo onto this workflow (the plugin's
// repo-shaped hooks look for it too). Every key is optional; an absent key, or
// an absent marker, takes the default below, which is the layout the tool was
// first written for, so a repo that has always used that layout needs no keys.
//
//	version: 1
//	tracker_dir: docs/project/active-work   # per-track yaml records
//	roles_dir: ops/work/roles               # role prompts for `work role`
//	worktrees_dir: .claude/worktrees        # per-session worktrees
//	trunk: main                             # the branch work merges into
//	bus: ""                                 # named bus shared by sibling repos; empty = one bus per clone
//	master_readonly: true                   # read by the plugin's worktree guards

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

const markerRelPath = ".claude/agent-workflow.yaml"

const (
	defaultTrackerDir   = "docs/project/active-work"
	defaultRolesDir     = "ops/work/roles"
	defaultWorktreesDir = ".claude/worktrees"
	defaultTrunk        = "main"
)

// Config is the resolved per-repo configuration.
type Config struct {
	TrackerDir   string `yaml:"tracker_dir"`
	RolesDir     string `yaml:"roles_dir"`
	WorktreesDir string `yaml:"worktrees_dir"`
	Trunk        string `yaml:"trunk"`
	Bus          string `yaml:"bus"`
	// Marker is the file the values came from; empty when there is none.
	Marker string `yaml:"-"`
}

var busNameRE = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

// configCandidates lists where the marker may live: the current worktree's
// root first, then the master worktree's root (a linked worktree made before
// the marker was committed still finds it there).
func configCandidates() []string {
	var out []string
	if root, err := repoRoot(); err == nil {
		out = append(out, filepath.Join(root, markerRelPath))
	}
	if common, err := runGitOutput("rev-parse", "--git-common-dir"); err == nil {
		abs := absPath(common)
		if filepath.Base(abs) == ".git" {
			out = append(out, filepath.Join(filepath.Dir(abs), markerRelPath))
		}
	}
	return out
}

// loadConfig reads the marker and fills defaults. A marker that does not parse
// is an error rather than a silent fall back to defaults: writing tracker
// records to the wrong directory is worse than refusing.
func loadConfig() (Config, error) {
	c := Config{}
	for _, p := range configCandidates() {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		if err := yaml.Unmarshal(b, &c); err != nil {
			return Config{}, fmt.Errorf("%s: %w", p, err)
		}
		c.Marker = p
		break
	}
	if c.TrackerDir == "" {
		c.TrackerDir = defaultTrackerDir
	}
	if c.RolesDir == "" {
		c.RolesDir = defaultRolesDir
	}
	if c.WorktreesDir == "" {
		c.WorktreesDir = defaultWorktreesDir
	}
	if c.Trunk == "" {
		c.Trunk = defaultTrunk
	}
	for _, rel := range []string{c.TrackerDir, c.RolesDir, c.WorktreesDir} {
		if filepath.IsAbs(rel) || strings.HasPrefix(filepath.Clean(rel), "..") {
			return Config{}, fmt.Errorf("%s: paths must be relative to the repo root and stay inside it: %q", c.Marker, rel)
		}
	}
	c.TrackerDir = filepath.Clean(c.TrackerDir)
	c.RolesDir = filepath.Clean(c.RolesDir)
	c.WorktreesDir = filepath.Clean(c.WorktreesDir)
	if c.Bus != "" && !busNameRE.MatchString(c.Bus) {
		return Config{}, fmt.Errorf("%s: bus name %q may use only letters, digits, '.', '_' and '-'", c.Marker, c.Bus)
	}
	return c, nil
}

// cfg returns the configuration, exiting on a marker that does not parse.
func cfg() Config {
	c, err := loadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "work: %v\n", err)
		os.Exit(2)
	}
	return c
}

// legacyTrackerRelPath is the monolithic tracker file that preceded the
// per-track directory: <tracker_dir>.yaml. load() refuses while it exists.
func (c Config) legacyTrackerRelPath() string { return c.TrackerDir + ".yaml" }
