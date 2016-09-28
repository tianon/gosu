package main // import "github.com/tianon/gosu"

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

func init() {
	// make sure we only have one process and that it runs on the main thread (so that ideally, when we Exec, we keep our user switches and stuff)
	runtime.GOMAXPROCS(1)
	runtime.LockOSThread()
}

func main() {
	log.SetFlags(0) // no timestamps on our logs

	if len(os.Args) <= 2 {
		self := filepath.Base(os.Args[0])
		log.Printf("Usage: %s user-spec command [args]", self)
		log.Printf("   ie: %s tianon bash", self)
		log.Printf("       %s nobody:root bash -c 'whoami && id'", self)
		log.Printf("       %s 1000:1 id", self)
		log.Println()
		log.Printf("%s version: %s (%s on %s/%s; %s)", self, Version, runtime.Version(), runtime.GOOS, runtime.GOARCH, runtime.Compiler)
		log.Printf("%s license: GPL-3 (full text at https://github.com/tianon/gosu)\n", strings.Repeat(" ", len(self)))
		log.Println()
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
