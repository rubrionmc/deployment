package main

import (
	"deployment/src/log"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"gopkg.in/yaml.v3"
)

// checkKubectl verifies that kubectl is installed and connected to a cluster.
// Returns true if both checks pass, false otherwise (with user-facing error messages).
func checkKubectl() bool {
	// check if kubectl is installed
	_, err := exec.LookPath("kubectl")
	if err != nil {
		log.FailProcess(0, "kubectl is not installed or not in PATH. Please install kubectl: https://kubernetes.io/docs/tasks/tools/")
		return false
	}

	// check if kubectl is connected to a cluster
	cmd := exec.Command("kubectl", "cluster-info", "--request-timeout=5s")
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		log.FailProcess(0, "kubectl is installed but not connected to a cluster. Please configure your kubeconfig (e.g. run: kubectl config use-context <your-context>)")
		return false
	}

	return true
}

// runKubectl runs a kubectl command and streams its output to stdout/stderr.
func runKubectl(args ...string) error {
	cmd := exec.Command("kubectl", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// runKubectlOutput runs a kubectl command and returns its combined output as a string.
func runKubectlOutput(args ...string) (string, error) {
	cmd := exec.Command("kubectl", args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// envPrefix derives the k8s namespace prefix from an environment config file.
// e.g. exposed_domain: rubrion.lab -> prefix: rubrion-lab
func envPrefix(environment string) (string, error) {
	configPath := fmt.Sprintf("k8s/enviroment/%s.yaml", environment)
	file, err := os.ReadFile(configPath)
	if err != nil {
		return "", fmt.Errorf("failed to read environment config: %w", err)
	}

	var raw struct {
		ExposedDomain string `yaml:"exposed_domain"`
	}
	if err := yaml.Unmarshal(file, &raw); err != nil {
		return "", fmt.Errorf("failed to parse environment config: %w", err)
	}

	return strings.ReplaceAll(raw.ExposedDomain, ".", "-"), nil
}

// buildSilent builds the environment manifests without calling os.Exit on success.
// This is used internally so the caller can continue after the build.
func buildSilent(environment string) bool {
	log.PrintStep(1, "Building manifests for environment:", environment)

	envConfig, err := loadEnvironmentConfig(environment)
	if err != nil {
		log.FailProcess(1, "Failed to load environment config:", err.Error())
		return false
	}

	runtimeDir := ".runtime/k8s"
	_ = os.RemoveAll(runtimeDir)
	if err := os.MkdirAll(runtimeDir, 0755); err != nil {
		log.FailProcess(1, "Failed to create runtime directory:", err.Error())
		return false
	}

	if err := processDirectory("k8s/golbal", runtimeDir+"/global", envConfig, "", environment); err != nil {
		log.FailProcess(1, "Failed to process global files:", err.Error())
		return false
	}

	if err := processNamespaces("k8s", runtimeDir, envConfig, environment); err != nil {
		log.FailProcess(1, "Failed to process namespaces:", err.Error())
		return false
	}

	log.PrintStep(1, "Manifests built successfully")
	return true
}

// usage: deployment start <env>
func runStart(args []string) {
	if len(args) != 1 {
		log.FailProcess(0, "Wrong usage: deployment start <env>")
		return
	}

	if !checkKubectl() {
		return
	}

	environment := args[0]
	log.OpenProcess(0, "Starting environment:", environment)

	if !buildSilent(environment) {
		return
	}

	runtimeDir := ".runtime/k8s"

	// apply global resources first (namespaces, resource quotas)
	log.PrintStep(1, "Applying global resources")
	if err := runKubectl("apply", "-R", "-f", runtimeDir+"/global"); err != nil {
		log.FailProcess(0, "Failed to apply global resources:", err.Error())
		return
	}

	// apply each namespace directory
	entries, err := os.ReadDir(runtimeDir)
	if err != nil {
		log.FailProcess(0, "Failed to read runtime directory:", err.Error())
		return
	}

	for _, entry := range entries {
		if !entry.IsDir() || entry.Name() == "global" {
			continue
		}

		nsDir := runtimeDir + "/" + entry.Name()
		log.PrintStep(1, "Applying namespace:", entry.Name())
		if err := runKubectl("apply", "-R", "-f", nsDir); err != nil {
			log.FailProcess(0, "Failed to apply namespace "+entry.Name()+":", err.Error())
			return
		}
	}

	log.EndProcess(0, "Environment started: "+environment)
}

// usage: deployment stop <env>
func runStop(args []string) {
	if len(args) != 1 {
		log.FailProcess(0, "Wrong usage: deployment stop <env>")
		return
	}

	if !checkKubectl() {
		return
	}

	environment := args[0]
	log.OpenProcess(0, "Stopping environment:", environment)

	prefix, err := envPrefix(environment)
	if err != nil {
		log.FailProcess(0, "Failed to derive prefix:", err.Error())
		return
	}

	// list all namespaces that start with our prefix
	out, err := runKubectlOutput("get", "namespaces", "-o", "jsonpath={.items[*].metadata.name}")
	if err != nil {
		log.FailProcess(0, "Failed to list namespaces:", err.Error())
		return
	}

	var matching []string
	for _, ns := range strings.Fields(out) {
		if strings.HasPrefix(ns, prefix+"-") {
			matching = append(matching, ns)
		}
	}

	if len(matching) == 0 {
		log.PrintStep(1, "No namespaces found with prefix:", prefix)
		log.EndProcess(0, "Nothing to stop")
		return
	}

	for _, ns := range matching {
		log.PrintStep(1, "Deleting namespace:", ns)
		if err := runKubectl("delete", "namespace", ns, "--ignore-not-found=true"); err != nil {
			log.FailProcess(0, "Failed to delete namespace "+ns+":", err.Error())
			return
		}
	}

	log.EndProcess(0, "Environment stopped: "+environment)
}

// usage: deployment status [env]
func runStatus(args []string) {
	if !checkKubectl() {
		return
	}

	log.OpenProcess(0, "Cluster status")

	// derive prefix filter if an environment is given
	var prefix string
	if len(args) >= 1 {
		p, err := envPrefix(args[0])
		if err != nil {
			log.FailProcess(0, "Failed to derive prefix:", err.Error())
			return
		}
		prefix = p
		log.PrintStep(1, "Filtering by prefix:", prefix)
	}

	// --- nodes ---
	log.PrintStep(1, "Nodes")
	if err := runKubectl("get", "nodes", "-o", "wide"); err != nil {
		log.PrintStep(1, "Failed to get nodes")
	}
	fmt.Println()

	// collect only our namespaces
	out, err := runKubectlOutput("get", "namespaces", "-o", "jsonpath={.items[*].metadata.name}")
	if err != nil {
		log.FailProcess(0, "Failed to list namespaces:", err.Error())
		return
	}

	var namespaces []string
	for _, ns := range strings.Fields(out) {
		if prefix == "" || strings.HasPrefix(ns, prefix+"-") {
			namespaces = append(namespaces, ns)
		}
	}

	if len(namespaces) == 0 {
		if prefix != "" {
			log.PrintStep(1, "No namespaces found with prefix:", prefix)
		} else {
			log.PrintStep(1, "No namespaces found")
		}
		log.EndProcess(0, "Status complete")
		return
	}

	// per-namespace breakdown
	for _, ns := range namespaces {
		log.PrintStep(1, "Namespace:", ns)

		log.PrintStep(2, "Pods")
		if err := runKubectl("get", "pods", "-n", ns, "-o", "wide"); err != nil {
			log.PrintStep(2, "No pods or failed to get pods")
		}

		log.PrintStep(2, "Deployments")
		if err := runKubectl("get", "deployments", "-n", ns); err != nil {
			log.PrintStep(2, "No deployments or failed to get deployments")
		}

		log.PrintStep(2, "StatefulSets")
		if err := runKubectl("get", "statefulsets", "-n", ns); err != nil {
			log.PrintStep(2, "No statefulsets or failed to get statefulsets")
		}

		log.PrintStep(2, "Services")
		if err := runKubectl("get", "services", "-n", ns); err != nil {
			log.PrintStep(2, "No services or failed to get services")
		}

		// resource usage — requires metrics-server, skip silently if unavailable
		log.PrintStep(2, "Resource usage")
		if err := runKubectl("top", "pods", "-n", ns); err != nil {
			log.PrintStep(2, "metrics-server not available, skipping")
		}

		fmt.Println()
	}

	log.EndProcess(0, "Status complete")
}

// usage: deployment deploy <env> <namespace> [deployment] [-f]
func runDeploy(args []string) {
	if len(args) < 2 {
		log.FailProcess(0, "Wrong usage: deployment deploy <env> <namespace> [deployment] [-f]")
		return
	}

	if !checkKubectl() {
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
		log.FailProcess(0, "Wrong usage: deployment deploy <env> <namespace> [deployment] [-f]")
	}
}

// deployNamespace applies all manifests for a namespace.
// Accepts both the short name ("infra") and the full k8s name ("rubrion-lab-infra").
func deployNamespace(environment string, namespace string, forced bool) {
	log.OpenProcess(0, "Deploying namespace:", namespace, "in environment:", environment)

	if !buildSilent(environment) {
		return
	}

	prefix, err := envPrefix(environment)
	if err != nil {
		log.FailProcess(0, "Failed to derive prefix:", err.Error())
		return
	}

	// normalise: strip the prefix so we always work with the short folder name
	shortName := strings.TrimPrefix(namespace, prefix+"-")
	fullNs := prefix + "-" + shortName

	nsDir := fmt.Sprintf(".runtime/k8s/%s", shortName)
	if _, err := os.Stat(nsDir); os.IsNotExist(err) {
		log.FailProcess(0, "Namespace directory not found after build:", nsDir)
		return
	}

	if forced {
		log.PrintStep(1, "Force flag set — deleting existing resources in:", fullNs)
		if err := runKubectl("delete", "all", "--all", "-n", fullNs, "--ignore-not-found=true"); err != nil {
			log.FailProcess(0, "Failed to delete existing resources:", err.Error())
			return
		}
	}

	log.PrintStep(1, "Applying manifests from:", nsDir)
	if err := runKubectl("apply", "-R", "-f", nsDir); err != nil {
		log.FailProcess(0, "Failed to apply namespace:", err.Error())
		return
	}

	log.EndProcess(0, "Namespace deployed: "+namespace)
}

// deployDeployment applies a single deployment manifest and waits for rollout.
// Accepts both short and full namespace names (see deployNamespace).
func deployDeployment(environment string, namespace string, deployment string, forced bool) {
	log.OpenProcess(0, "Deploying:", deployment, "in namespace:", namespace, "environment:", environment)

	if !buildSilent(environment) {
		return
	}

	prefix, err := envPrefix(environment)
	if err != nil {
		log.FailProcess(0, "Failed to derive prefix:", err.Error())
		return
	}

	// normalise namespace
	shortName := strings.TrimPrefix(namespace, prefix+"-")
	fullNs := prefix + "-" + shortName

	// manifest lives at .runtime/k8s/<shortName>/deployment/<name>.yaml
	manifestPath := fmt.Sprintf(".runtime/k8s/%s/deployment/%s.yaml", shortName, deployment)
	if _, err := os.Stat(manifestPath); os.IsNotExist(err) {
		log.FailProcess(0, "Manifest not found:", manifestPath)
		return
	}

	if forced {
		log.PrintStep(1, "Force flag set — restarting deployment:", deployment)
		// ignore error — deployment might not exist yet
		_ = runKubectl("rollout", "restart", "deployment/"+deployment, "-n", fullNs)
	}

	log.PrintStep(1, "Applying manifest:", manifestPath)
	if err := runKubectl("apply", "-f", manifestPath); err != nil {
		log.FailProcess(0, "Failed to apply deployment:", err.Error())
		return
	}

	log.PrintStep(1, "Waiting for rollout to complete")
	if err := runKubectl("rollout", "status", "deployment/"+deployment, "-n", fullNs, "--timeout=120s"); err != nil {
		log.FailProcess(0, "Rollout did not complete successfully:", err.Error())
		return
	}

	log.EndProcess(0, "Deployment complete: "+deployment)
}
