package main // import "github.com/tianon/gosu"

import (
	"log"
	"os"
	"os/exec"
	"runtime"
	"syscall"
)

const VERSION = "1.2"

func init() {
	// make sure we only have one process and that it runs on the main thread (so that ideally, when we Exec, we keep our user switches and stuff)
	runtime.GOMAXPROCS(1)
	runtime.LockOSThread()
}

func main() {
	log.SetFlags(0) // no timestamps on our logs

	if len(os.Args) <= 2 {
		log.Printf("Usage: %s user-spec command [args]", os.Args[0])
		log.Printf("   ie: %s tianon bash", os.Args[0])
		log.Printf("       %s nobody:root bash -c 'whoami && id'", os.Args[0])
		log.Printf("       %s 1000:1 id", os.Args[0])
		log.Println()
		log.Printf("%s version: %s (%s on %s/%s; %s)", os.Args[0], VERSION, runtime.Version(), runtime.GOOS, runtime.GOARCH, runtime.Compiler)
		log.Println()
		os.Exit(1)
	}

	// clear HOME so that SetupUser will set it
	os.Setenv("HOME", "")

	err := SetupUser(os.Args[1])
	if err != nil {
		log.Fatalf("error: failed switching to %q: %v", os.Args[1], err)
	}

	name, err := exec.LookPath(os.Args[2])
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	err = syscall.Exec(name, os.Args[2:], os.Environ())
	if err != nil {
		log.Fatalf("error: exec failed: %v", err)
	}
}
