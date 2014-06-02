package main

import (
	"log"
	"os"
	"os/exec"
	"syscall"

	"github.com/dotcloud/docker/pkg/user"
)

const VERSION = "1.0"

func main() {
	log.SetFlags(0) // no timestamps on our logs

	if len(os.Args) <= 2 {
		log.Printf("Usage: %s user-spec command [args]", os.Args[0])
		log.Printf("   ie: %s tianon bash", os.Args[0])
		log.Printf("       %s nobody:root bash -c 'whoami && id'", os.Args[0])
		log.Printf("       %s 1000:1 id", os.Args[0])
		log.Printf("%s version: %s", os.Args[0], VERSION)
		os.Exit(1)
	}

	uid, gid, suppGids, err := user.GetUserGroupSupplementary(os.Args[1], syscall.Getuid(), syscall.Getgid())
	if err != nil {
		log.Fatalf("error: failed parsing '%s': %v", os.Args[1], err)
	}

	if err := syscall.Setgroups(suppGids); err != nil {
		log.Fatalf("error: failed to setgroups: %v", err)
	}
	if err := syscall.Setgid(gid); err != nil {
		log.Fatalf("error: failed to setgid: %v", err)
	}
	if err := syscall.Setuid(uid); err != nil {
		log.Fatalf("error: failed to setuid: %v", err)
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
