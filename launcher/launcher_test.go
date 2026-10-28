package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func zipBytes(t *testing.T, files map[string]string) []byte {
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for n, c := range files {
		f, _ := w.Create(n)
		f.Write([]byte(c))
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

// server fakes the releases API plus the zip and checksum assets.
func server(t *testing.T, tag string, z []byte, sum string) *httptest.Server {
	mux := http.NewServeMux()
	var s *httptest.Server
	name := "G-" + runtime.GOOS + ".zip"
	mux.HandleFunc("/repos/o/r/releases/latest", func(w http.ResponseWriter, _ *http.Request) {
		json.NewEncoder(w).Encode(release{Tag: tag, Assets: []asset{
			{name, s.URL + "/z"}, {name + ".sha256", s.URL + "/s"},
		}})
	})
	mux.HandleFunc("/z", func(w http.ResponseWriter, _ *http.Request) { w.Write(z) })
	mux.HandleFunc("/s", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte(sum)) })
	s = httptest.NewServer(mux)
	t.Cleanup(s.Close)
	return s
}

func TestUpdateFlow(t *testing.T) {
	z := zipBytes(t, map[string]string{"bin/game": "v2"})
	h := sha256.Sum256(z)
	s := server(t, "v2", z, hex.EncodeToString(h[:])+"  G.zip\n")
	dir := filepath.Join(t.TempDir(), "game")
	os.MkdirAll(dir, 0o755)
	os.WriteFile(filepath.Join(dir, "version.txt"), []byte("v1"), 0o644)
	cfg := Config{Repo: "o/r", Asset: "G-{os}.zip"}
	if err := checkAndUpdate(cfg, dir, s.URL); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "bin/game")); string(b) != "v2" {
		t.Fatalf("game file = %q", b)
	}
	if v := localVersion(dir); v != "v2" {
		t.Fatalf("version = %q", v)
	}
	if err := checkAndUpdate(cfg, dir, s.URL); err != nil {
		t.Fatal("second run should be a no-op:", err)
	}
}

func TestBadChecksumKeepsOldBuild(t *testing.T) {
	z := zipBytes(t, map[string]string{"bin/game": "v2"})
	s := server(t, "v2", z, "deadbeef")
	dir := filepath.Join(t.TempDir(), "game")
	os.MkdirAll(dir, 0o755)
	os.WriteFile(filepath.Join(dir, "version.txt"), []byte("v1"), 0o644)
	if checkAndUpdate(Config{Repo: "o/r", Asset: "G-{os}.zip"}, dir, s.URL) == nil {
		t.Fatal("expected checksum error")
	}
	if v := localVersion(dir); v != "v1" {
		t.Fatalf("old build replaced: %q", v)
	}
}

func TestZipSlipRejected(t *testing.T) {
	z := zipBytes(t, map[string]string{"../evil": "x"})
	src := filepath.Join(t.TempDir(), "a.zip")
	os.WriteFile(src, z, 0o644)
	if unzip(src, filepath.Join(t.TempDir(), "out")) == nil {
		t.Fatal("expected zip-slip rejection")
	}
}

func TestLoadConfigFallsBackToBuiltIn(t *testing.T) {
	c, err := loadConfig(filepath.Join(t.TempDir(), "missing.json"))
	if err != nil || c.Repo != "Littlebutta/Space-Lord" {
		t.Fatalf("got %+v, %v", c, err)
	}
}
