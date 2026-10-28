package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const apiURL = "https://api.github.com"

var client = &http.Client{Timeout: 10 * time.Minute}

type asset struct {
	Name string `json:"name"`
	URL  string `json:"browser_download_url"`
}

type release struct {
	Tag    string  `json:"tag_name"`
	Assets []asset `json:"assets"`
}

func (r release) find(name string) (asset, bool) {
	for _, a := range r.Assets {
		if a.Name == name {
			return a, true
		}
	}
	return asset{}, false
}

func latestRelease(api, repo string) (release, error) {
	var r release
	url := fmt.Sprintf("%s/repos/%s/releases/latest", api, repo)
	body, err := get(url, 5*time.Second)
	if err != nil {
		return r, err
	}
	defer body.Close()
	return r, json.NewDecoder(body).Decode(&r)
}

// get fetches url; a short timeout keeps boot fast when offline.
func get(url string, timeout time.Duration) (io.ReadCloser, error) {
	c := client
	if timeout > 0 {
		c = &http.Client{Timeout: timeout}
	}
	res, err := c.Get(url)
	if err != nil {
		return nil, err
	}
	if res.StatusCode != http.StatusOK {
		res.Body.Close()
		return nil, fmt.Errorf("GET %s: %s", url, res.Status)
	}
	return res.Body, nil
}
