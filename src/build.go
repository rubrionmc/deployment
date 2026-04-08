package main

import (
	"deployment/src/log"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

func runBuild(args []string) {
	if len(args) != 1 {
		log.FailProcess(0, "Wrong usage: deployment build <env>")
		return
	}
	buildEnvironment(args[0])
}

func buildEnvironment(environment string) {
	log.OpenProcess(0, "Starting build for environment:", environment)

	log.PrintStep(1, "Loading configurations")
	envConfig, err := loadEnvironmentConfig(environment)
	if err != nil {
		log.FailProcess(0, "Failed to load environment config:", err.Error())
		return
	}

	runtimeDir := ".runtime/k8s"
	err = os.RemoveAll(runtimeDir)
	if err != nil {
		log.FailProcess(0, "Failed to clear runtime directory:", err.Error())
		return
	}

	err = os.MkdirAll(runtimeDir, 0755)
	if err != nil {
		log.FailProcess(0, "Failed to create runtime directory:", err.Error())
	}

	log.PrintStep(1, "Processing global files")
	err = processDirectory("k8s/golbal", runtimeDir+"/global", envConfig, "", environment)
	if err != nil {
		log.FailProcess(0, "Failed to process global files:", err.Error())
		return
	}

	log.PrintStep(1, "Processing namespace directories")
	err = processNamespaces("k8s", runtimeDir, envConfig, environment)
	if err != nil {
		log.FailProcess(0, "Failed to process namespaces:", err.Error())
		return
	}

	log.EndProcess(0, "Build completed successfully")
}

type EnvironmentConfig struct {
	ExposedDomain      string `yaml:"exposed_domain"`
	ClaimDomainLocally bool   `yaml:"claim_domain_localy"`
	MemoryUsageLimit   string `yaml:"memory_usage_limit"`
	CPUUsageLimit      string `yaml:"cpu_usage_limit"`
	GameServerMinimal  int    `yaml:"game_server_minimal"`
	VersionSuffix      string `yaml:"version_suffix"`
	Images             map[string]struct {
		Link    string `yaml:"link"`
		Image   string `yaml:"image"`
		Version string `yaml:"version"`
	} `yaml:"images"`
	Ports map[string]int `yaml:"ports"`
}

func loadEnvironmentConfig(environment string) (*EnvironmentConfig, error) {
	configPath := fmt.Sprintf("k8s/enviroment/%s.yaml", environment)
	file, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read environment config: %w", err)
	}

	var config EnvironmentConfig
	err = yaml.Unmarshal(file, &config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse environment config: %w", err)
	}

	return &config, nil
}

func replacePlaceholders(content string, envConfig *EnvironmentConfig, namespace, environment string) string {
	// static placeholders
	domain := envConfig.ExposedDomain
	prefix := strings.ReplaceAll(domain, ".", "-")

	replacements := map[string]string{
		"{{ENVIRONMENT}}":         environment,
		"{{DOMAIN}}":              domain,
		"{{PREFIX}}":              prefix,
		"{{MEMORY_USAGE_LIMIT}}":  envConfig.MemoryUsageLimit,
		"{{CPU_USAGE_LIMIT}}":     strings.TrimSuffix(envConfig.CPUUsageLimit, "%"),
		"{{GAME_SERVER_MINIMAL}}": fmt.Sprintf("%d", envConfig.GameServerMinimal),
	}

	if namespace != "" {
		replacements["{{NAMESPACE}}"] = namespace
	}

	// dynamic placeholders for images
	for imageID, imageConfig := range envConfig.Images {
		placeholder := fmt.Sprintf("{{IMAGE:%s}}", imageID)
		imageName := fmt.Sprintf("%s:%s", imageConfig.Image, imageConfig.Version)
		replacements[placeholder] = imageName
	}

	// dynamic placeholders for ports
	for portID, port := range envConfig.Ports {
		placeholder := fmt.Sprintf("{{PORT:%s}}", portID)
		replacements[placeholder] = fmt.Sprintf("%d", port)
	}

	// replace all placeholders
	result := content
	for placeholder, value := range replacements {
		result = strings.ReplaceAll(result, placeholder, value)
	}

	return result
}

func processDirectory(srcDir, dstDir string, envConfig *EnvironmentConfig, namespace, environment string) error {
	return filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if d.IsDir() {
			return nil
		}

		relPath, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return err
		}

		processedContent := replacePlaceholders(string(content), envConfig, namespace, environment)

		dstPath := filepath.Join(dstDir, relPath)
		err = os.MkdirAll(filepath.Dir(dstPath), 0755)
		if err != nil {
			return err
		}

		// split files by metadata.name if needed
		if strings.Contains(processedContent, "metadata:\n") && strings.Contains(processedContent, "name:") {
			err := splitByMetadataName(processedContent, dstPath)
			if err != nil {
				return fmt.Errorf("failed to split file %s: %w", relPath, err)
			}
			return nil // don't create the original file when splitting
		}

		return os.WriteFile(dstPath, []byte(processedContent), 0644)
	})
}

func splitByMetadataName(content, dstPath string) error {
	// split by YAML document separator ---
	documents := strings.Split(content, "---")
	baseName := strings.TrimSuffix(dstPath, filepath.Ext(dstPath))

	// create a folder with the base name (e.g., deployment/, service/, etc.)
	folderPath := baseName
	err := os.MkdirAll(folderPath, 0755)
	if err != nil {
		return fmt.Errorf("failed to create folder %s: %w", folderPath, err)
	}

	for _, document := range documents {
		document = strings.TrimSpace(document)
		if document == "" {
			continue
		}

		lines := strings.Split(document, "\n")
		var metadataName string

		// Find metadata.name in this document (handle separate lines)
		for i, line := range lines {
			line = strings.TrimSpace(line)
			if line == "metadata:" {
				// Look for name: in the next few lines
				for j := i + 1; j < len(lines) && j < i+5; j++ {
					nextLine := strings.TrimSpace(lines[j])
					if strings.HasPrefix(nextLine, "name:") {
						parts := strings.SplitN(nextLine, ":", 2)
						if len(parts) >= 2 {
							metadataName = strings.TrimSpace(parts[1])
							break
						}
					}
				}
				break
			}
		}

		if metadataName == "" {
			// Skip if no metadata.name found
			continue
		}

		// Create filename: {metadataName}.yaml inside the folder
		filename := fmt.Sprintf("%s.yaml", metadataName)
		filePath := filepath.Join(folderPath, filename)

		// Write the document with proper YAML separator
		fullContent := document
		if !strings.HasSuffix(fullContent, "\n") {
			fullContent += "\n"
		}

		err := os.WriteFile(filePath, []byte(fullContent), 0644)
		if err != nil {
			return err
		}
	}

	return nil
}

func processNamespaces(srcRoot, dstRoot string, envConfig *EnvironmentConfig, environment string) error {
	entries, err := os.ReadDir(srcRoot)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		dirName := entry.Name()
		if dirName == "config" || dirName == "enviroment" || dirName == "golbal" || dirName == "shared" {
			continue
		}

		srcDir := filepath.Join(srcRoot, dirName)
		dstDir := filepath.Join(dstRoot, dirName)

		log.PrintStep(2, "Processing namespace:", dirName)
		err = processDirectory(srcDir, dstDir, envConfig, dirName, environment)
		if err != nil {
			return fmt.Errorf("failed to process namespace %s: %w", dirName, err)
		}

		// process shared files for each namespace
		sharedSrc := filepath.Join(srcRoot, "shared")
		if _, err := os.Stat(sharedSrc); err == nil {
			sharedDst := dstDir
			err = processDirectory(sharedSrc, sharedDst, envConfig, dirName, environment)
			if err != nil {
				return fmt.Errorf("failed to process shared files for namespace %s: %w", dirName, err)
			}
		}
	}

	return nil
}
