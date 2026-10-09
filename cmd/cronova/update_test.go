package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
)

func makeZip(t *testing.T, files map[string][]byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, data := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write(data); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestReleaseAsset(t *testing.T) {
	want := fmt.Sprintf("cronova_windows_%s.zip", runtime.GOARCH)
	if got := releaseAsset(); got != want {
		t.Fatalf("releaseAsset() = %q, want %q", got, want)
	}
}

func TestReleaseBaseURL(t *testing.T) {
	t.Setenv("CRONOVA_BASE_URL", "") // ensure the override is off for the GitHub cases
	os.Unsetenv("CRONOVA_BASE_URL")
	cases := map[string]string{
		"latest": "https://github.com/" + releaseRepo + "/releases/latest/download",
		"v0.2.0": "https://github.com/" + releaseRepo + "/releases/download/v0.2.0",
	}
	for target, want := range cases {
		if got := releaseBaseURL(target); got != want {
			t.Errorf("releaseBaseURL(%q) = %q, want %q", target, got, want)
		}
	}
	t.Setenv("CRONOVA_BASE_URL", "http://localhost:9999/mirror/")
	if got, want := releaseBaseURL("latest"), "http://localhost:9999/mirror"; got != want {
		t.Errorf("override = %q, want %q (trailing slash trimmed)", got, want)
	}
}

func TestValidateBaseURL(t *testing.T) {
	ok := []string{
		"https://github.com/x/y/releases/latest/download",
		"http://localhost:8899",
		"http://127.0.0.1:9000/mirror",
		"http://[::1]:9000",
	}
	bad := []string{
		"http://mirror.internal/cronova",
		"http://example.com",
		"ftp://example.com",
	}
	for _, u := range ok {
		if err := validateBaseURL(u); err != nil {
			t.Errorf("validateBaseURL(%q) = %v, want nil", u, err)
		}
	}
	for _, u := range bad {
		if err := validateBaseURL(u); err == nil {
			t.Errorf("validateBaseURL(%q) = nil, want rejection", u)
		}
	}
}

func TestCheckRedirect(t *testing.T) {
	req := func(raw string) *http.Request {
		u, _ := url.Parse(raw)
		return &http.Request{URL: u}
	}
	if err := checkRedirect(req("https://objects.githubusercontent.com/x"), nil); err != nil {
		t.Errorf("https redirect should be allowed: %v", err)
	}
	if err := checkRedirect(req("http://localhost:8899/x"), nil); err != nil {
		t.Errorf("http-to-loopback redirect should be allowed: %v", err)
	}
	if err := checkRedirect(req("http://evil.example/x"), nil); err == nil {
		t.Error("https->http downgrade redirect to a remote host must be refused")
	}
	if err := checkRedirect(req("https://x/y"), make([]*http.Request, 10)); err == nil {
		t.Error("should stop after 10 redirects")
	}
}

func TestConfirmFrom(t *testing.T) {
	cases := map[string]bool{
		"y\n":   true,
		"yes\n": true,
		"Y\n":   true,
		"y":     true, // no trailing newline (Ctrl-D / printf 'y')
		"yes":   true,
		" y \n": true,
		"n\n":   false,
		"no\n":  false,
		"\n":    false,
		"":      false, // closed/empty stdin -> safe no
		"maybe": false,
	}
	for in, want := range cases {
		if got := confirmFrom(strings.NewReader(in)); got != want {
			t.Errorf("confirmFrom(%q) = %v, want %v", in, got, want)
		}
	}
}

// TestFetchReleaseThroughProxy proves the download actually ROUTES through the
// proxy: a local forward-proxy counts every request, and fetchRelease's traffic
// to the mirror must pass through it.
func TestFetchReleaseThroughProxy(t *testing.T) {
	tb := makeZip(t, map[string][]byte{"cronova.exe": []byte("hi"), "VERSION": []byte("v1")})
	sum := fmt.Sprintf("%x", sha256.Sum256(tb))
	asset := releaseAsset()

	mirror := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if filepath.Base(r.URL.Path) == asset {
			w.Write(tb)
		} else {
			fmt.Fprint(w, sum+"  "+asset+"\n")
		}
	}))
	defer mirror.Close()

	var hits int32
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1) // an http proxy receives the ABSOLUTE URL
		out, _ := http.NewRequest(r.Method, r.URL.String(), r.Body)
		resp, err := http.DefaultTransport.RoundTrip(out)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		w.WriteHeader(resp.StatusCode)
		io.Copy(w, resp.Body)
	}))
	defer proxy.Close()

	bins, ver, err := fetchRelease(mirror.URL, asset, proxy.URL)
	if err != nil {
		t.Fatalf("fetchRelease via proxy: %v", err)
	}
	if string(bins["cronova"]) != "hi" || ver != "v1" {
		t.Fatalf("got %q / %q", bins["cronova"], ver)
	}
	if n := atomic.LoadInt32(&hits); n < 1 {
		t.Fatalf("download did NOT go through the proxy (hits=%d)", n)
	}
}

func TestNormalizeProxyURL(t *testing.T) {
	ok := map[string]string{
		"127.0.0.1:7890":          "http://127.0.0.1:7890", // bare host:port -> http proxy
		"http://127.0.0.1:7890":   "http://127.0.0.1:7890",
		"https://proxy.corp:8080": "https://proxy.corp:8080",
		"socks5://127.0.0.1:7891": "socks5://127.0.0.1:7891",
	}
	for in, want := range ok {
		u, err := normalizeProxyURL(in)
		if err != nil || u.String() != want {
			t.Errorf("normalizeProxyURL(%q) = %v, %v; want %q", in, u, err, want)
		}
	}
	for _, bad := range []string{"", "ftp://x:1", "://", "http://"} {
		if _, err := normalizeProxyURL(bad); err == nil {
			t.Errorf("normalizeProxyURL(%q) should error", bad)
		}
	}
}

func TestHTTPClientProxyWiring(t *testing.T) {
	// explicit proxy -> the transport routes through it
	tr := httpClient("http://127.0.0.1:7890").Transport.(*http.Transport)
	req, _ := http.NewRequest("GET", "https://github.com/x", nil)
	pu, err := tr.Proxy(req)
	if err != nil || pu == nil || pu.Host != "127.0.0.1:7890" {
		t.Errorf("explicit proxy: got %v, %v", pu, err)
	}
	// empty proxy -> falls back to the env proxy resolver (not nil)
	if httpClient("").Transport.(*http.Transport).Proxy == nil {
		t.Error("empty proxy should fall back to ProxyFromEnvironment, not disable proxying")
	}
}

func TestSumFor(t *testing.T) {
	sums := "abc123  cronova_windows_amd64.zip\n" +
		"def456 *cronova_windows_arm64.zip\n" +
		"# a comment line\n"
	if got, ok := sumFor(sums, "cronova_windows_amd64.zip"); !ok || got != "abc123" {
		t.Errorf("space form: got %q ok=%v", got, ok)
	}
	if got, ok := sumFor(sums, "cronova_windows_arm64.zip"); !ok || got != "def456" {
		t.Errorf("binary-mode(*) form: got %q ok=%v", got, ok)
	}
	if _, ok := sumFor(sums, "cronova_windows_386.zip"); ok {
		t.Error("expected miss for an unlisted asset")
	}
}

func TestExtractReleaseZipBinaries(t *testing.T) {
	data := makeZip(t, map[string][]byte{
		"cronova.exe":          []byte("WINDOWS-A"),
		"cronova-executor.exe": []byte("WINDOWS-B"),
		"VERSION":              []byte("v10.0.0\n"),
		"cronova.yaml":         []byte("ignored"),
	})
	bins, ver, err := extractReleaseZipBinaries(data)
	if err != nil {
		t.Fatal(err)
	}
	if string(bins["cronova"]) != "WINDOWS-A" || string(bins["cronova-executor"]) != "WINDOWS-B" {
		t.Fatalf("wrong Windows binaries: %q / %q", bins["cronova"], bins["cronova-executor"])
	}
	if ver != "v10.0.0" {
		t.Fatalf("version = %q, want v10.0.0", ver)
	}
}

func TestFetchRelease(t *testing.T) {
	tb := makeZip(t, map[string][]byte{"cronova.exe": []byte("hello"), "VERSION": []byte("v1.2.3")})
	sum := fmt.Sprintf("%x", sha256.Sum256(tb))
	asset := releaseAsset()

	newServer := func(sums string, serveSums bool) *httptest.Server {
		return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch filepath.Base(r.URL.Path) {
			case asset:
				w.Write(tb)
			case "SHA256SUMS":
				if !serveSums {
					http.NotFound(w, r)
					return
				}
				fmt.Fprint(w, sums)
			default:
				http.NotFound(w, r)
			}
		}))
	}

	t.Run("verified", func(t *testing.T) {
		srv := newServer(sum+"  "+asset+"\n", true)
		defer srv.Close()
		bins, ver, err := fetchRelease(srv.URL, asset, "")
		if err != nil {
			t.Fatal(err)
		}
		if string(bins["cronova"]) != "hello" || ver != "v1.2.3" {
			t.Fatalf("got %q / %q", bins["cronova"], ver)
		}
	})

	t.Run("checksum mismatch is fatal", func(t *testing.T) {
		srv := newServer(strings.Repeat("0", 64)+"  "+asset+"\n", true)
		defer srv.Close()
		if _, _, err := fetchRelease(srv.URL, asset, ""); err == nil {
			t.Fatal("expected a checksum-mismatch error")
		}
	})

	t.Run("missing SHA256SUMS is fatal", func(t *testing.T) {
		srv := newServer("", false)
		defer srv.Close()
		if _, _, err := fetchRelease(srv.URL, asset, ""); err == nil {
			t.Fatal("missing sums must prevent an unverified update")
		}
	})

	t.Run("asset missing from SHA256SUMS is fatal", func(t *testing.T) {
		srv := newServer(sum+"  some-other-asset.zip\n", true)
		defer srv.Close()
		if _, _, err := fetchRelease(srv.URL, asset, ""); err == nil {
			t.Fatal("unlisted asset must prevent an unverified update")
		}
	})

	t.Run("404 asset errors", func(t *testing.T) {
		srv := newServer("", true)
		defer srv.Close()
		if _, _, err := fetchRelease(srv.URL, "cronova_nope_nope.zip", ""); err == nil {
			t.Fatal("expected a download error for a missing asset")
		}
	})
}

func TestHTTPGetRejectsOversizedResponse(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(bytes.Repeat([]byte("x"), 65))
	}))
	defer srv.Close()
	if _, err := httpGet(srv.URL, "", 64); err == nil || (!strings.Contains(err.Error(), "large") && !strings.Contains(err.Error(), "exceeds")) {
		t.Fatalf("oversized response error = %v", err)
	}
}

func TestSwapBinary(t *testing.T) {
	t.Run("replace existing with backup + restore", func(t *testing.T) {
		dir := t.TempDir()
		dst := filepath.Join(dir, "cronova")
		if err := os.WriteFile(dst, []byte("OLD"), 0o755); err != nil {
			t.Fatal(err)
		}
		restore, err := swapBinary(dst, []byte("NEW"))
		if err != nil {
			t.Fatal(err)
		}
		if b, _ := os.ReadFile(dst); string(b) != "NEW" {
			t.Fatalf("after swap dst = %q, want NEW", b)
		}
		if b, _ := os.ReadFile(dst + ".bak"); string(b) != "OLD" {
			t.Fatalf("backup = %q, want OLD", b)
		}
		if fi, err := os.Stat(dst); err != nil || fi.IsDir() {
			t.Errorf("swapped binary missing: %v", err)
		}
		if err := restore(); err != nil {
			t.Fatal(err)
		}
		if b, _ := os.ReadFile(dst); string(b) != "OLD" {
			t.Fatalf("after restore dst = %q, want OLD", b)
		}
	})

	t.Run("fresh install restore removes the new file", func(t *testing.T) {
		dir := t.TempDir()
		dst := filepath.Join(dir, "cronova")
		restore, err := swapBinary(dst, []byte("NEW"))
		if err != nil {
			t.Fatal(err)
		}
		if b, _ := os.ReadFile(dst); string(b) != "NEW" {
			t.Fatalf("dst = %q, want NEW", b)
		}
		if err := restore(); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(dst); !os.IsNotExist(err) {
			t.Fatalf("restore should have removed dst, stat err = %v", err)
		}
	})

	t.Run("commitSwap drops the backup", func(t *testing.T) {
		dir := t.TempDir()
		dst := filepath.Join(dir, "cronova")
		os.WriteFile(dst, []byte("OLD"), 0o755)
		if _, err := swapBinary(dst, []byte("NEW")); err != nil {
			t.Fatal(err)
		}
		commitSwap(dst)
		if _, err := os.Stat(dst + ".bak"); !os.IsNotExist(err) {
			t.Fatalf("commitSwap should remove .bak, stat err = %v", err)
		}
	})

	t.Run("empty payload is refused", func(t *testing.T) {
		dir := t.TempDir()
		dst := filepath.Join(dir, "cronova")
		if _, err := swapBinary(dst, nil); err == nil {
			t.Fatal("expected refusal to install an empty binary")
		}
	})
}
