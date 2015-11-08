package main

import (
	"os"
	"syscall"

	"github.com/opencontainers/runc/libcontainer/system"
	"github.com/opencontainers/runc/libcontainer/user"
)

// this function comes from libcontainer/init_linux.go
// we don't use that directly because we don't want the whole namespaces package imported here
// (also, because we need minor modifications and it's not even exported)

// SetupUser changes the groups, gid, and uid for the user inside the container
func SetupUser(u string) error {
	// Set up defaults.
	defaultExecUser := user.ExecUser{
		Uid:  syscall.Getuid(),
		Gid:  syscall.Getgid(),
		Home: "/",
	}
	passwdPath, err := user.GetPasswdPath()
	if err != nil {
		return err
	}
	groupPath, err := user.GetGroupPath()
	if err != nil {
		return err
	}
	execUser, err := user.GetExecUserPath(u, &defaultExecUser, passwdPath, groupPath)
	if err != nil {
		return err
	}
	if err := syscall.Setgroups(execUser.Sgids); err != nil {
		return err
	}
	if err := system.Setgid(execUser.Gid); err != nil {
		return err
	}
	if err := system.Setuid(execUser.Uid); err != nil {
		return err
	}
	// if we didn't get HOME already, set it based on the user's HOME
	if envHome := os.Getenv("HOME"); envHome == "" {
		if err := os.Setenv("HOME", execUser.Home); err != nil {
			return err
		}
	}
	return nil
}
