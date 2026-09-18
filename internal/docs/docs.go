// Package docs embeds the project documentation markdown files so the cronova
// console can serve them directly from the single binary.
package docs

import (
	"embed"
	"io/fs"
)

//go:embed all:docs
var content embed.FS

// FS returns the embedded documentation files rooted at docs/.
func FS() fs.FS {
	sub, err := fs.Sub(content, "docs")
	if err != nil {
		panic(err)
	}
	return sub
}
