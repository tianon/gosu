package main

import (
	"io/ioutil"
	"strconv"
	"syscall"
)

func chownFds(uid, gid int) error {
	fdList, err := ioutil.ReadDir("/proc/self/fd")
	if err != nil {
		return err
	}
	for _, fi := range fdList {
		fd, err := strconv.Atoi(fi.Name())
		if err != nil {
			// ignore non-numeric file names
			continue
		}

		if err = syscall.Fchown(fd, uid, gid); err != nil {
			// "bad file descriptor" probably just means it no longer exists since we did "readdir", so ignore that
			if err != syscall.EBADF {
				return err
			}
		}
	}
	return nil
}
