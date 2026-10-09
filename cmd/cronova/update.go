package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path"
	"runtime"
	"strings"
	"time"
)

// releaseRepo is where the independent Windows project publishes its releases.
const releaseRepo = "ako74programmer/poc-cronova-windows"

const (
	// maxBinary caps any single extracted executable.
	maxBinary = 256 << 20 // 256 MiB
	// Download bounds prevent a release endpoint from exhausting updater memory.
	maxReleaseArchiveBytes  = int64(512 << 20)
	maxReleaseMetadataBytes = int64(4 << 20)
)

// cmdUpdate replaces the installed cronova (and cronova-executor, if present)
// with a prebuilt release from GitHub, then restarts the managed service. It is
// the counterpart to the bootstrap installer: same asset naming, same checksum
// verification, but self-contained in the binary.
//
//	cronova update                              # latest release
//	cronova update v0.2.0                        # a specific tag (re-install / downgrade)
//	cronova update -proxy http://127.0.0.1:7890  # download through a proxy
//
// CRONOVA_BASE_URL overrides the download origin (private mirror / testing).
func cmdUpdate(args []string) error {
	fs := flag.NewFlagSet("update", flag.ExitOnError)
	proxy := fs.String("proxy", "", "proxy for the download: http(s)://host:port or socks5://host:port, e.g. http://127.0.0.1:7890 (env CRONOVA_UPDATE_PROXY; also honors HTTPS_PROXY/ALL_PROXY)")
	pos := parsePositionals(fs, args)
	target := "latest"
	if len(pos) > 0 {
		target = pos[0]
	}

	proxyVal := *proxy
	if proxyVal == "" {
		proxyVal = os.Getenv("CRONOVA_UPDATE_PROXY")
	}
	if proxyVal != "" {
		if _, err := normalizeProxyURL(proxyVal); err != nil {
			return fmt.Errorf("invalid -proxy %q: %w", proxyVal, err)
		}
	}

	if err := ensureRoot("update"); err != nil {
		return err
	}

	base := releaseBaseURL(target)
	if err := validateBaseURL(base); err != nil {
		return err
	}
	asset := releaseAsset()
	if proxyVal != "" {
		fmt.Printf("cronova: fetching %s (%s) via proxy %s…\n", asset, target, proxyVal)
	} else {
		fmt.Printf("cronova: fetching %s (%s)…\n", asset, target)
	}
	bins, newVer, err := fetchRelease(base, asset, proxyVal)
	if err != nil {
		return err
	}

	// Short-circuit an unpinned update that is already current. (A pinned
	// version is always applied, so re-install and downgrade both work.)
	if target == "latest" && newVer != "" && newVer == version {
		fmt.Printf("cronova: already up to date (%s)\n", version)
		return nil
	}

	// Swap the binaries. cronova is required; the executor is only replaced when
	// the release ships one AND the host already has it (don't silently add it).
	var restores []func() error
	rollback := func() error {
		var errs []error
		for i := len(restores) - 1; i >= 0; i-- {
			if err := restores[i](); err != nil {
				errs = append(errs, err)
			}
		}
		return errors.Join(errs...)
	}

	restore, err := swapBinary(binDst, bins["cronova"])
	if err != nil {
		return fmt.Errorf("replace %s: %w", binDst, err)
	}
	restores = append(restores, restore)

	if eb, ok := bins["cronova-executor"]; ok {
		if _, statErr := os.Stat(binExecutor); statErr == nil {
			r2, err := swapBinary(binExecutor, eb)
			if err != nil {
				if rbErr := rollback(); rbErr != nil {
					return fmt.Errorf("replace %s: %w (restoring previous binaries also failed: %v)", binExecutor, err, rbErr)
				}
				return fmt.Errorf("replace %s: %w", binExecutor, err)
			}
			restores = append(restores, r2)
		}
	}

	// Restart the service so the new binary actually runs. On failure, roll the
	// binaries back and bring the previous version back up — never leave the box
	// on a half-applied update.
	if serviceInstalled() {
		fmt.Println("cronova: restarting service…")
		if err := restartService(); err != nil {
			fmt.Fprintln(os.Stderr, "cronova: restart failed — rolling back to the previous version")
			// A running executable is locked on Windows: stop everything before
			// moving the *.bak binaries back.
			_ = stopServices()
			if rbErr := rollback(); rbErr != nil {
				return fmt.Errorf("update failed and restoring the previous binaries failed: %v (original: %w)", rbErr, err)
			}
			if restartErr := restartService(); restartErr != nil {
				return fmt.Errorf("update failed and the rollback restart also failed: %v (original: %w)", restartErr, err)
			}
			return fmt.Errorf("update aborted, restored previous version: %w", err)
		}
	}

	// Success — drop the .bak backups.
	commitSwap(binDst)
	commitSwap(binExecutor)

	from := version
	if from == "" || from == "dev" {
		from = "(unknown)"
	}
	to := newVer
	if to == "" {
		to = target
	}
	fmt.Printf("cronova: updated %s -> %s\n", from, to)
	if !serviceInstalled() {
		fmt.Println("cronova: binary replaced (no managed service to restart — install it with deploy\\install.ps1).")
	}
	return nil
}

// releaseAsset is the platform archive name emitted by the release packagers.
func releaseAsset() string {
	return fmt.Sprintf("cronova_windows_%s.zip", runtime.GOARCH)
}

// releaseBaseURL is the directory holding <asset> and SHA256SUMS.
func releaseBaseURL(target string) string {
	if b := os.Getenv("CRONOVA_BASE_URL"); b != "" {
		return strings.TrimRight(b, "/")
	}
	if target == "latest" {
		return "https://github.com/" + releaseRepo + "/releases/latest/download"
	}
	return "https://github.com/" + releaseRepo + "/releases/download/" + target
}

// httpClient builds the download client. A non-empty proxy (http(s)/socks5)
// routes the download through it; empty falls back to the standard *_PROXY env
// vars (HTTPS_PROXY / HTTP_PROXY / ALL_PROXY) — a custom Transport does NOT read
// them unless we ask it to.
func httpClient(proxy string) *http.Client {
	tr := &http.Transport{TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12}}
	if proxy != "" {
		if pu, err := normalizeProxyURL(proxy); err == nil {
			tr.Proxy = http.ProxyURL(pu)
		}
	} else {
		tr.Proxy = http.ProxyFromEnvironment
	}
	return &http.Client{
		Timeout:       10 * time.Minute,
		Transport:     tr,
		CheckRedirect: checkRedirect,
	}
}

// normalizeProxyURL turns a proxy spec into a URL, defaulting a bare host:port to
// an http proxy. Accepts http/https/socks5 (e.g. clash's 7890=http, 7891=socks5).
func normalizeProxyURL(s string) (*url.URL, error) {
	if !strings.Contains(s, "://") {
		s = "http://" + s // "127.0.0.1:7890" -> http proxy
	}
	u, err := url.Parse(s)
	if err != nil {
		return nil, err
	}
	switch u.Scheme {
	case "http", "https", "socks5", "socks5h":
	default:
		return nil, fmt.Errorf("unsupported proxy scheme %q (use http, https, or socks5)", u.Scheme)
	}
	if u.Host == "" {
		return nil, fmt.Errorf("proxy is missing host:port")
	}
	return u, nil
}

// checkRedirect refuses to follow a redirect that downgrades to cleartext — a
// self-updating root binary must never fetch its payload over http on the way to
// an https origin (matches deploy/bootstrap.sh's `curl --proto '=https'`). Plain
// http is allowed only to loopback (local mirror / testing).
func checkRedirect(req *http.Request, via []*http.Request) error {
	if len(via) >= 10 {
		return errors.New("stopped after 10 redirects")
	}
	if isSecureURL(req.URL) {
		return nil
	}
	return fmt.Errorf("refusing insecure redirect to %s", req.URL)
}

// isSecureURL accepts https anywhere, and http only to a loopback host.
func isSecureURL(u *url.URL) bool {
	if u.Scheme == "https" {
		return true
	}
	return u.Scheme == "http" && isLoopbackHost(u.Hostname())
}

func isLoopbackHost(h string) bool {
	if h == "localhost" {
		return true
	}
	if ip := net.ParseIP(h); ip != nil {
		return ip.IsLoopback()
	}
	return false
}

// validateBaseURL rejects an insecure CRONOVA_BASE_URL up front (the default
// GitHub origin is https, so only an override can trip this).
func validateBaseURL(base string) error {
	u, err := url.Parse(base)
	if err != nil {
		return fmt.Errorf("invalid update URL %q: %w", base, err)
	}
	if isSecureURL(u) {
		return nil
	}
	return fmt.Errorf("refusing insecure update origin %q — CRONOVA_BASE_URL must be https:// (http:// is allowed only for localhost)", base)
}

// fetchRelease requires SHA256SUMS, downloads the bounded tarball, verifies it,
// and only then extracts executable payloads. Missing or incomplete checksum
// metadata is fatal: a root self-updater must never install unverified bytes.
func fetchRelease(base, asset, proxy string) (bins map[string][]byte, version string, err error) {
	sums, err := httpGet(base+"/SHA256SUMS", proxy, maxReleaseMetadataBytes)
	if err != nil {
		return nil, "", fmt.Errorf("download SHA256SUMS: %w", err)
	}
	want, ok := sumFor(string(sums), asset)
	if !ok {
		return nil, "", fmt.Errorf("%s is not listed in SHA256SUMS", asset)
	}
	decoded, decodeErr := hex.DecodeString(want)
	if decodeErr != nil || len(decoded) != sha256.Size {
		return nil, "", fmt.Errorf("invalid SHA-256 digest for %s in SHA256SUMS", asset)
	}

	archiveData, err := httpGet(base+"/"+asset, proxy, maxReleaseArchiveBytes)
	if err != nil {
		return nil, "", fmt.Errorf("download %s: %w — see https://github.com/%s/releases", asset, err, releaseRepo)
	}
	got := fmt.Sprintf("%x", sha256.Sum256(archiveData))
	if !strings.EqualFold(got, want) {
		return nil, "", fmt.Errorf("checksum mismatch for %s:\n  got  %s\n  want %s", asset, got, want)
	}
	fmt.Println("cronova: checksum OK")

	bins, version, err = extractReleaseZipBinaries(archiveData)
	if err != nil {
		return nil, "", err
	}
	if _, ok := bins["cronova"]; !ok {
		return nil, "", errors.New("release archive does not contain a cronova binary")
	}
	return bins, version, nil
}

// httpGet returns the body of a 200 response; any other status or transport
// error is returned as an error.
func httpGet(url, proxy string, maxBytes int64) ([]byte, error) {
	resp, err := httpClient(proxy).Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s", resp.Status)
	}
	if resp.ContentLength > maxBytes {
		return nil, fmt.Errorf("response is too large: %d bytes (limit %d)", resp.ContentLength, maxBytes)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, maxBytes+1))
	if err != nil {
		return nil, err
	}
	if int64(len(b)) > maxBytes {
		return nil, fmt.Errorf("response exceeds %d-byte limit", maxBytes)
	}
	return b, nil
}

// sumFor pulls the hex digest for a file out of a `sha256sum`-format listing
// ("<hex>  name" or "<hex> *name"), matching on the file's base name.
func sumFor(sums, asset string) (string, bool) {
	want := path.Base(asset)
	for _, line := range strings.Split(sums, "\n") {
		fields := strings.Fields(line)
		if len(fields) != 2 {
			continue
		}
		name := strings.TrimPrefix(fields[1], "*") // binary-mode marker
		if path.Base(name) == want {
			return fields[0], true
		}
	}
	return "", false
}

// extractReleaseZipBinaries reads the Windows ZIP release and returns the
// executable payloads keyed without the .exe suffix plus VERSION. Only the
// files required by the updater are extracted; other ZIP entries are ignored.
func extractReleaseZipBinaries(data []byte) (map[string][]byte, string, error) {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, "", fmt.Errorf("read release zip: %w", err)
	}
	out := make(map[string][]byte, 2)
	version := ""
	for _, f := range zr.File {
		name := strings.ToLower(path.Base(f.Name))
		if f.FileInfo().IsDir() {
			continue
		}
		if name != "cronova.exe" && name != "cronova-executor.exe" && name != "version" {
			continue
		}
		if f.UncompressedSize64 > maxBinary && name != "version" {
			return nil, "", fmt.Errorf("release file %s is too large: %d bytes", name, f.UncompressedSize64)
		}
		limit := int64(maxBinary)
		if name == "version" {
			limit = 1 << 10
		}
		rc, err := f.Open()
		if err != nil {
			return nil, "", fmt.Errorf("open release file %s: %w", name, err)
		}
		b, readErr := io.ReadAll(io.LimitReader(rc, limit+1))
		closeErr := rc.Close()
		if readErr != nil {
			return nil, "", fmt.Errorf("extract %s: %w", name, readErr)
		}
		if closeErr != nil {
			return nil, "", fmt.Errorf("close release file %s: %w", name, closeErr)
		}
		if int64(len(b)) > limit {
			return nil, "", fmt.Errorf("release file %s exceeds %d bytes", name, limit)
		}
		switch name {
		case "cronova.exe":
			out["cronova"] = b
		case "cronova-executor.exe":
			out["cronova-executor"] = b
		case "version":
			version = strings.TrimSpace(string(b))
		}
	}
	return out, version, nil
}

// swapBinary atomically replaces dst with data. It writes a sibling temp file
// (same filesystem, so the rename is atomic), backs the current binary up to
// dst.bak, then renames the new file into place. The returned restore func undoes
// the swap; on success the caller drops the backup with commitSwap.
//
// Replacing a *running* executable this way is safe on Unix: the rename swaps the
// directory entry while the old inode stays live for any process already exec'd
// from it — so cronova can update the very binary it is running from.
func swapBinary(dst string, data []byte) (restore func() error, err error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("refusing to install an empty %s", path.Base(dst))
	}
	tmp := dst + ".new"
	if err := os.WriteFile(tmp, data, 0o755); err != nil {
		return nil, err
	}
	if err := os.Chmod(tmp, 0o755); err != nil { // WriteFile is subject to umask; force it
		os.Remove(tmp)
		return nil, err
	}

	bak := dst + ".bak"
	hadOld := false
	if _, err := os.Stat(dst); err == nil {
		if err := os.Rename(dst, bak); err != nil {
			os.Remove(tmp)
			return nil, err
		}
		hadOld = true
	}
	if err := os.Rename(tmp, dst); err != nil {
		if hadOld {
			_ = os.Rename(bak, dst) // best-effort restore
		}
		os.Remove(tmp)
		return nil, err
	}

	return func() error {
		if !hadOld {
			return os.Remove(dst)
		}
		return os.Rename(bak, dst) // overwrites the just-installed dst
	}, nil
}

// commitSwap drops the backup left by swapBinary (best-effort).
func commitSwap(dst string) { _ = os.Remove(dst + ".bak") }
