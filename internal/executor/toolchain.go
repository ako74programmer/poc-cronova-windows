package executor

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type windowsToolchainRoots struct {
	programFiles    string
	programFilesX86 string
	localAppData    string
	userProfile     string
	systemDrive     string
	nvmHome         string
	nvmSymlink      string
}

var versionNumberRE = regexp.MustCompile(`\d+`)

// discoverWindowsToolchain populates runtime tool paths for task processes.
// Explicit CRONOVA_* values (and JAVA_HOME/MAVEN_HOME) always win. When they
// are absent, known per-user and system installation roots are searched so a
// clean `app.cmd start` can run SDLC tasks without a hand-built PATH.
func discoverWindowsToolchain(env map[string]string, roots windowsToolchainRoots) {
	path := env["PATH"]
	var prepend []string

	python := env["CRONOVA_PYTHON"]
	if python == "" {
		python = findExecutableOnPath(withoutWindowsApps(path), "python.exe", "python3.exe")
	}
	if python == "" {
		python = newestFile(
			filepath.Join(roots.localAppData, "Programs", "Python", "Python*", "python.exe"),
			filepath.Join(roots.programFiles, "Python*", "python.exe"),
			filepath.Join(roots.programFilesX86, "Python*", "python.exe"),
			filepath.Join(roots.systemDrive, "Python*", "python.exe"),
		)
	}
	if python != "" {
		env["CRONOVA_PYTHON"] = python
		prepend = append(prepend, filepath.Dir(python), filepath.Join(filepath.Dir(python), "Scripts"))
	}

	node := env["CRONOVA_NODE"]
	if node == "" {
		node = findExecutableOnPath(path, "node.exe")
	}
	if node == "" {
		node = firstExistingFile(
			filepath.Join(roots.programFiles, "nodejs", "node.exe"),
			filepath.Join(roots.programFilesX86, "nodejs", "node.exe"),
			filepath.Join(roots.localAppData, "Programs", "nodejs", "node.exe"),
			filepath.Join(roots.nvmSymlink, "node.exe"),
			filepath.Join(roots.nvmHome, "node.exe"),
		)
	}
	if node != "" {
		env["CRONOVA_NODE"] = node
		prepend = append(prepend, filepath.Dir(node))
	}

	npm := env["CRONOVA_NPM"]
	if npm == "" {
		npm = findExecutableOnPath(path, "npm.cmd", "npm.exe")
	}
	if npm == "" && node != "" {
		npm = firstExistingFile(filepath.Join(filepath.Dir(node), "npm.cmd"))
	}
	if npm != "" {
		env["CRONOVA_NPM"] = npm
		prepend = append(prepend, filepath.Dir(npm))
	}

	javaHome := firstNonEmpty(env["CRONOVA_JAVA_HOME"], env["JAVA_HOME"])
	if javaHome == "" {
		javaExe := findExecutableOnPath(path, "java.exe")
		if javaExe == "" {
			javaExe = newestFile(
				filepath.Join(roots.programFiles, "Java", "jdk-*", "bin", "java.exe"),
				filepath.Join(roots.programFiles, "Eclipse Adoptium", "jdk-*", "bin", "java.exe"),
				filepath.Join(roots.programFiles, "Microsoft", "jdk-*", "bin", "java.exe"),
				filepath.Join(roots.programFilesX86, "Java", "jdk-*", "bin", "java.exe"),
				filepath.Join(roots.systemDrive, "Java", "jdk-*", "bin", "java.exe"),
				filepath.Join(roots.systemDrive, "jdk-*", "bin", "java.exe"),
			)
		}
		if javaExe != "" {
			javaHome = filepath.Dir(filepath.Dir(javaExe))
		}
	}
	if javaHome != "" {
		if env["CRONOVA_JAVA_HOME"] == "" {
			env["CRONOVA_JAVA_HOME"] = javaHome
		}
		if env["JAVA_HOME"] == "" {
			env["JAVA_HOME"] = javaHome
		}
		prepend = append(prepend, filepath.Join(javaHome, "bin"))
	}

	mavenHome := firstNonEmpty(env["CRONOVA_MAVEN_HOME"], env["MAVEN_HOME"])
	if mavenHome == "" {
		mavenExe := findExecutableOnPath(path, "mvn.cmd", "mvn.exe")
		if mavenExe == "" {
			mavenExe = newestFile(
				filepath.Join(roots.programFiles, "Apache", "Maven", "apache-maven-*", "bin", "mvn.cmd"),
				filepath.Join(roots.systemDrive, "apache-maven-*", "bin", "mvn.cmd"),
				filepath.Join(roots.systemDrive, "tools", "apache-maven-*", "bin", "mvn.cmd"),
				filepath.Join(roots.userProfile, "tools", "apache-maven-*", "bin", "mvn.cmd"),
			)
		}
		if mavenExe != "" {
			mavenHome = filepath.Dir(filepath.Dir(mavenExe))
		}
	}
	if mavenHome != "" {
		if env["CRONOVA_MAVEN_HOME"] == "" {
			env["CRONOVA_MAVEN_HOME"] = mavenHome
		}
		if env["MAVEN_HOME"] == "" {
			env["MAVEN_HOME"] = mavenHome
		}
		prepend = append(prepend, filepath.Join(mavenHome, "bin"))
	}

	env["PATH"] = prependPath(path, prepend...)
}

func windowsToolchainRootsFromHost() windowsToolchainRoots {
	programFiles := os.Getenv("ProgramFiles")
	systemDrive := os.Getenv("SystemDrive")
	if systemDrive == "" {
		systemDrive = filepath.VolumeName(programFiles)
	}
	if systemDrive == "" {
		systemDrive = `C:`
	}
	if len(systemDrive) == 2 && systemDrive[1] == ':' {
		systemDrive += `\`
	}
	return windowsToolchainRoots{
		programFiles:    programFiles,
		programFilesX86: os.Getenv("ProgramFiles(x86)"),
		localAppData:    os.Getenv("LOCALAPPDATA"),
		userProfile:     os.Getenv("USERPROFILE"),
		systemDrive:     systemDrive,
		nvmHome:         os.Getenv("NVM_HOME"),
		nvmSymlink:      os.Getenv("NVM_SYMLINK"),
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func isRegularFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}

func firstExistingFile(paths ...string) string {
	for _, path := range paths {
		if path != "" && isRegularFile(path) {
			return path
		}
	}
	return ""
}

// withoutWindowsApps drops %LOCALAPPDATA%\Microsoft\WindowsApps, whose
// python.exe/python3.exe are Microsoft Store stubs that exit 9009.
func withoutWindowsApps(path string) string {
	var kept []string
	for _, directory := range filepath.SplitList(path) {
		if strings.HasSuffix(strings.ToLower(filepath.Clean(directory)), `\microsoft\windowsapps`) {
			continue
		}
		kept = append(kept, directory)
	}
	return strings.Join(kept, string(filepath.ListSeparator))
}

func findExecutableOnPath(path string, names ...string) string {
	for _, directory := range filepath.SplitList(path) {
		if directory == "" {
			continue
		}
		for _, name := range names {
			if found := firstExistingFile(filepath.Join(directory, name)); found != "" {
				return found
			}
		}
	}
	return ""
}

func newestFile(patterns ...string) string {
	var matches []string
	seen := make(map[string]struct{})
	for _, pattern := range patterns {
		if pattern == "" {
			continue
		}
		found, _ := filepath.Glob(pattern)
		for _, path := range found {
			if isRegularFile(path) {
				key := strings.ToLower(filepath.Clean(path))
				if _, ok := seen[key]; !ok {
					seen[key] = struct{}{}
					matches = append(matches, path)
				}
			}
		}
	}
	if len(matches) == 0 {
		return ""
	}
	sort.SliceStable(matches, func(i, j int) bool {
		left, right := versionNumbers(matches[i]), versionNumbers(matches[j])
		for index := 0; index < len(left) && index < len(right); index++ {
			if left[index] != right[index] {
				return left[index] < right[index]
			}
		}
		if len(left) != len(right) {
			return len(left) < len(right)
		}
		return strings.ToLower(matches[i]) < strings.ToLower(matches[j])
	})
	return matches[len(matches)-1]
}

func versionNumbers(path string) []int {
	versionLabel := filepath.Base(filepath.Dir(path))
	if strings.EqualFold(versionLabel, "bin") {
		versionLabel = filepath.Base(filepath.Dir(filepath.Dir(path)))
	}
	parts := versionNumberRE.FindAllString(versionLabel, -1)
	version := make([]int, 0, len(parts))
	for _, part := range parts {
		value := 0
		for _, digit := range part {
			value = value*10 + int(digit-'0')
		}
		version = append(version, value)
	}
	return version
}

func prependPath(existing string, directories ...string) string {
	var result []string
	seen := make(map[string]struct{})
	add := func(directory string) {
		directory = strings.TrimSpace(directory)
		if directory == "" {
			return
		}
		key := strings.ToLower(filepath.Clean(directory))
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		result = append(result, directory)
	}
	for _, directory := range directories {
		add(directory)
	}
	for _, directory := range filepath.SplitList(existing) {
		add(directory)
	}
	return strings.Join(result, string(os.PathListSeparator))
}
