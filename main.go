package main // import "github.com/tianon/gosu"

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"text/template"
)

func init() {
	// make sure we only have one process and that it runs on the main thread (so that ideally, when we Exec, we keep our user switches and stuff)
	runtime.GOMAXPROCS(1)
	runtime.LockOSThread()
}

func version() string {
	return fmt.Sprintf(`%s (%s on %s/%s; %s)`, Version, runtime.Version(), runtime.GOOS, runtime.GOARCH, runtime.Compiler)
}

func usage() string {
	t := template.Must(template.New("usage").Parse(`
Usage: {{ .Self }} user-spec command [args]
   eg: {{ .Self }} tianon bash
       {{ .Self }} nobody:root bash -c 'whoami && id'
       {{ .Self }} 1000:1 id

{{ .Self }} version: {{ .Version }}
{{ .Self }} license: Apache-2.0 (full text at https://github.com/tianon/gosu)
`))
	var b bytes.Buffer
	template.Must(t, t.Execute(&b, struct {
		Self    string
		Version string
	}{
		Self:    filepath.Base(os.Args[0]),
		Version: version(),
	}))
	return strings.TrimSpace(b.String()) + "\n"
}

func main() {
	log.SetFlags(0) // no timestamps on our logs

	if len(os.Args) >= 2 {
		switch os.Args[1] {
		case "--help", "-h", "-?":
			fmt.Println(usage())
			os.Exit(0)
		case "--version", "-v":
			fmt.Println(version())
			os.Exit(0)
		}
	}
	if len(os.Args) <= 2 {
		log.Println(usage())
		os.Exit(1)
	}

	// clear HOME so that SetupUser will set it
	os.Unsetenv("HOME")

	if err := SetupUser(os.Args[1]); err != nil {
		log.Fatalf("error: failed switching to %q: %v", os.Args[1], err)
	}

	name, err := exec.LookPath(os.Args[2])
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	if err = syscall.Exec(name, os.Args[2:], os.Environ()); err != nil {
		log.Fatalf("error: exec failed: %v", err)
	}
}
