package main

import (
	"deployment/src/log"
	"os"
)

func runInstall(args []string) {
	log.FailProcess(0, "You can not run install on gosource pls use deployment install")
}

func runHello(args []string) {
	log.PrintStep(0, "Hello World and welcome to gosource!")
}

func runHelp(args []string) {
	log.PrintStep(0, "Help und so :>")
}

func main() {
	if len(os.Args) < 2 {
		log.FailProcess(0, "Wrong usage: deployment <command> [args...]")
		return
	}

	command := os.Args[1]
	args := os.Args[2:]

	switch command {

	case "help":
	case "?":
		runHelp(args)

	case "hello":
		runHello(args)

	case "install":
		runInstall(args)

	case "build":
		runBuild(args)

	case "start":
		runStart(args)

	case "stop":
		runStop(args)

	case "status":
		runStatus(args)

	case "deploy":
		runDeploy(args)

	default:
		log.FailProcess(0, "Unknown command:", command, "use help for usage.")
	}
}
