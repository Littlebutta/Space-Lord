// Command launcher checks GitHub Releases for a newer game build,
// installs it, then starts the game. Any update failure falls back
// to launching the build already on disk.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// Config is read from launcher.json next to the launcher binary.
type Config struct {
	Repo  string            `json:"repo"`  // "owner/name"
	Asset string            `json:"asset"` // e.g. "SpaceLord-{os}.zip"
	Dir   string            `json:"dir"`   // game folder, relative
	Exe   map[string]string `json:"exe"`   // GOOS -> path inside Dir
}

func main() {
	base := exeDir()
	cfg, err := loadConfig(filepath.Join(base, "launcher.json"))
	if err != nil {
		fail("config: %v", err)
	}
	dir := filepath.Join(base, cfg.Dir)
	if err := checkAndUpdate(cfg, dir, apiURL); err != nil {
		fmt.Println("update skipped:", err)
	}
	exe, ok := cfg.Exe[runtime.GOOS]
	if !ok {
		fail("no exe configured for %s", runtime.GOOS)
	}
	cmd := exec.Command(filepath.Join(dir, exe), os.Args[1:]...)
	cmd.Dir = dir
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Start(); err != nil {
		fail("start game: %v", err)
	}
}

// checkAndUpdate installs the latest release if it differs from the
// version recorded in dir/version.txt.
func checkAndUpdate(cfg Config, dir, api string) error {
	rel, err := latestRelease(api, cfg.Repo)
	if err != nil {
		return err
	}
	if rel.Tag == localVersion(dir) {
		fmt.Println("up to date:", rel.Tag)
		return nil
	}
	name := strings.ReplaceAll(cfg.Asset, "{os}", runtime.GOOS)
	fmt.Printf("updating to %s (%s)\n", rel.Tag, name)
	return install(rel, name, dir)
}

func loadConfig(path string) (Config, error) {
	var c Config
	b, err := os.ReadFile(path)
	if err == nil {
		err = json.Unmarshal(b, &c)
	}
	return c, err
}

func localVersion(dir string) string {
	b, _ := os.ReadFile(filepath.Join(dir, "version.txt"))
	return strings.TrimSpace(string(b))
}

func exeDir() string {
	p, err := os.Executable()
	if err != nil {
		return "."
	}
	return filepath.Dir(p)
}

func fail(f string, a ...any) {
	fmt.Fprintf(os.Stderr, f+"\n", a...)
	os.Exit(1)
}
