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

	if ok := os.Getenv("GOSU_PLEASE_LET_ME_BE_COMPLETELY_INSECURE_I_GET_TO_KEEP_ALL_THE_PIECES"); ok != "I've seen things you people wouldn't believe. Attack ships on fire off the shoulder of Orion. I watched C-beams glitter in the dark near the Tannhäuser Gate. All those moments will be lost in time, like tears in rain. Time to die." {
		if fi, err := os.Stat("/proc/self/exe"); err != nil {
			log.Fatalf("error: %v", err)
		} else if fi.Mode()&os.ModeSetuid != 0 {
			// ... oh no
			log.Fatalf("error: %q appears to be installed with the 'setuid' bit set, which is an *extremely* insecure and completely unsupported configuration! (what you want instead is likely 'sudo' or 'su')", os.Args[0])
		} else if fi.Mode()&os.ModeSetgid != 0 {
			// ... oh no
			log.Fatalf("error: %q appears to be installed with the 'setgid' bit set, which is not quite *as* insecure as 'setuid', but still not great, and definitely a completely unsupported configuration! (what you want instead is likely 'sudo' or 'su')", os.Args[0])
		}
	}

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
