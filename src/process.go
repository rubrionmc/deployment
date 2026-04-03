package main

import (
	"deployment/src/log"
	"fmt"
)

func runStart(args []string) {
	enviroment := args[0]
	fmt.Printf("Starting %s\n", enviroment)
}

// usage: deployment stop <env>
func runStop(args []string) {

}

// usage: deployment status <env>
func runStatus(args []string) {

}

// usage: deployment deploy <env> <namspace> [deployment] [-f]
func runDeploy(args []string) {

	if len(args) < 2 {
		log.FailProcess(0, "Wrong Usage: deployment deploy <env> <namespace> [deployment] [-f]")
		return
	}

	forced := false
	if args[len(args)-1] == "-f" {
		forced = true
		args = args[:len(args)-1]
	}

	switch len(args) {
	case 2:
		// env, namespace
		deployNamespace(args[0], args[1], forced)
	case 3:
		// env, namespace, deployment
		deployDeployment(args[0], args[1], args[2], forced)
	default:
		log.FailProcess(0, "Wrong Usage: deployment deploy <env> <namespace> [deployment] [-f]")
	}
}

func startEnviroment(enviroment string, forced bool) {
	// todo: start enviroment

}

func deployNamespace(enviroment string, namespace string, forced bool) {
	// todo: deploy/redeploy one namespace
}

func deployDeployment(enviroment string, namespace string, deployment string, forced bool) {
	// todo: deploy/redeploy one deployment
}
