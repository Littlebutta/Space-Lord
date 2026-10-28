package main

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// install downloads the release zip, verifies its optional .sha256
// asset, unpacks it beside dir and swaps it in, rolling back on error.
func install(rel release, name, dir string) error {
	a, ok := rel.find(name)
	if !ok {
		return fmt.Errorf("release %s has no asset %s", rel.Tag, name)
	}
	zipPath := dir + ".download.zip"
	defer os.Remove(zipPath)
	sum, err := download(a.URL, zipPath)
	if err != nil {
		return err
	}
	if err := verify(rel, name, sum); err != nil {
		return err
	}
	tmp, old := dir+".new", dir+".old"
	os.RemoveAll(tmp)
	os.RemoveAll(old)
	if err := unzip(zipPath, tmp); err != nil {
		os.RemoveAll(tmp)
		return err
	}
	ver := filepath.Join(tmp, "version.txt")
	if err := os.WriteFile(ver, []byte(rel.Tag), 0o644); err != nil {
		return err
	}
	return swap(dir, tmp, old)
}

func swap(dir, tmp, old string) error {
	had := os.Rename(dir, old) == nil
	if err := os.Rename(tmp, dir); err != nil {
		if had {
			os.Rename(old, dir)
		}
		return err
	}
	os.RemoveAll(old)
	return nil
}

// download saves url to path and returns its sha256 hex digest.
func download(url, path string) (string, error) {
	body, err := get(url, 0)
	if err != nil {
		return "", err
	}
	defer body.Close()
	f, err := os.Create(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(io.MultiWriter(f, h), body); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func verify(rel release, name, sum string) error {
	a, ok := rel.find(name + ".sha256")
	if !ok {
		return nil
	}
	body, err := get(a.URL, 0)
	if err != nil {
		return err
	}
	defer body.Close()
	b, err := io.ReadAll(io.LimitReader(body, 1024))
	if err != nil {
		return err
	}
	want := strings.Fields(string(b))
	if len(want) == 0 || !strings.EqualFold(want[0], sum) {
		return fmt.Errorf("checksum mismatch for %s", name)
	}
	return nil
}

func unzip(src, dst string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()
	for _, f := range r.File {
		if err := extract(f, dst); err != nil {
			return err
		}
	}
	return nil
}

func extract(f *zip.File, dst string) error {
	p := filepath.Join(dst, f.Name)
	if !strings.HasPrefix(p, filepath.Clean(dst)+string(os.PathSeparator)) {
		return fmt.Errorf("bad path in zip: %s", f.Name)
	}
	if f.FileInfo().IsDir() {
		return os.MkdirAll(p, 0o755)
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	in, err := f.Open()
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(p, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, f.Mode()|0o600)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}
