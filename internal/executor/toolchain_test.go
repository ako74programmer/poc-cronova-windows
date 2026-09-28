package executor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDiscoverWindowsToolchainFromCommonInstallRoots(t *testing.T) {
	root := t.TempDir()
	roots := windowsToolchainRoots{
		localAppData:    filepath.Join(root, "LocalAppData"),
		programFiles:    filepath.Join(root, "Program Files"),
		programFilesX86: filepath.Join(root, "Program Files (x86)"),
		userProfile:     filepath.Join(root, "Users", "test"),
		systemDrive:     filepath.Join(root, "C"),
	}
	makeFile := func(path string) {
		t.Helper()
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("fixture"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	python312 := filepath.Join(roots.localAppData, "Programs", "Python", "Python312", "python.exe")
	python313 := filepath.Join(roots.localAppData, "Programs", "Python", "Python313", "python.exe")
	makeFile(python312)
	makeFile(python313)

	node := filepath.Join(roots.programFiles, "nodejs", "node.exe")
	npm := filepath.Join(roots.programFiles, "nodejs", "npm.cmd")
	makeFile(node)
	makeFile(npm)

	java21 := filepath.Join(roots.programFiles, "Java", "jdk-21", "bin", "java.exe")
	java25 := filepath.Join(roots.programFiles, "Java", "jdk-25", "bin", "java.exe")
	makeFile(java21)
	makeFile(java25)

	maven39 := filepath.Join(roots.systemDrive, "apache-maven-3.9.9", "bin", "mvn.cmd")
	maven3914 := filepath.Join(roots.systemDrive, "apache-maven-3.9.14", "bin", "mvn.cmd")
	makeFile(maven39)
	makeFile(maven3914)

	env := map[string]string{"PATH": ""}
	discoverWindowsToolchain(env, roots)

	want := map[string]string{
		"CRONOVA_PYTHON":     python313,
		"CRONOVA_NODE":       node,
		"CRONOVA_NPM":        npm,
		"CRONOVA_JAVA_HOME":  filepath.Join(roots.programFiles, "Java", "jdk-25"),
		"JAVA_HOME":          filepath.Join(roots.programFiles, "Java", "jdk-25"),
		"CRONOVA_MAVEN_HOME": filepath.Join(roots.systemDrive, "apache-maven-3.9.14"),
		"MAVEN_HOME":         filepath.Join(roots.systemDrive, "apache-maven-3.9.14"),
	}
	for name, expected := range want {
		if env[name] != expected {
			t.Errorf("%s = %q, want %q", name, env[name], expected)
		}
	}

	for _, directory := range []string{
		filepath.Dir(python313),
		filepath.Join(filepath.Dir(python313), "Scripts"),
		filepath.Dir(node),
		filepath.Join(roots.programFiles, "Java", "jdk-25", "bin"),
		filepath.Join(roots.systemDrive, "apache-maven-3.9.14", "bin"),
	} {
		if !pathListContains(env["PATH"], directory) {
			t.Errorf("PATH %q does not contain discovered directory %q", env["PATH"], directory)
		}
	}
}

func TestDiscoverWindowsToolchainPreservesExplicitOverrides(t *testing.T) {
	root := t.TempDir()
	roots := windowsToolchainRoots{
		localAppData: filepath.Join(root, "LocalAppData"),
		programFiles: filepath.Join(root, "Program Files"),
		systemDrive:  filepath.Join(root, "C"),
	}
	installedPython := filepath.Join(roots.localAppData, "Programs", "Python", "Python313", "python.exe")
	if err := os.MkdirAll(filepath.Dir(installedPython), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(installedPython, []byte("fixture"), 0o644); err != nil {
		t.Fatal(err)
	}

	explicitPython := filepath.Join(root, "custom", "python.exe")
	explicitJavaHome := filepath.Join(root, "custom", "jdk")
	explicitMavenHome := filepath.Join(root, "custom", "maven")
	env := map[string]string{
		"PATH":               "",
		"CRONOVA_PYTHON":     explicitPython,
		"CRONOVA_JAVA_HOME":  explicitJavaHome,
		"CRONOVA_MAVEN_HOME": explicitMavenHome,
		"CRONOVA_NODE":       "custom-node.exe",
		"CRONOVA_NPM":        "custom-npm.cmd",
	}
	discoverWindowsToolchain(env, roots)

	for name, expected := range map[string]string{
		"CRONOVA_PYTHON":     explicitPython,
		"CRONOVA_JAVA_HOME":  explicitJavaHome,
		"CRONOVA_MAVEN_HOME": explicitMavenHome,
		"CRONOVA_NODE":       "custom-node.exe",
		"CRONOVA_NPM":        "custom-npm.cmd",
	} {
		if env[name] != expected {
			t.Errorf("explicit %s override changed to %q, want %q", name, env[name], expected)
		}
	}
}

func pathListContains(path, directory string) bool {
	for _, entry := range filepath.SplitList(path) {
		if strings.EqualFold(filepath.Clean(entry), filepath.Clean(directory)) {
			return true
		}
	}
	return false
}
