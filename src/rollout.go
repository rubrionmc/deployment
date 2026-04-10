package main

// usage: deployment rollout <env> <path/or/dot>
func runRollout(args []string) {
	// todo: build these steps

	// step1: find owner and repo / image example in bash: bitte in go machen
	// OWNER=$(echo "$REMOTE_URL" | sed -E 's#(git@github.com:|https://github.com/)([^/]+)/([^/.]+)(\.git)?#\2#')
	// REPO=$(echo "$REMOTE_URL"  | sed -E 's#(git@github.com:|https://github.com/)([^/]+)/([^/.]+)(\.git)?#\3#')
	//
	// IMAGE="ghcr.io/${OWNER}/${REPO}"

	// step2: tmp local dev version erstellen
	// pattern: rollout-<timestamp>

	// step3: clean up all local dev tags witch same image

	// step4: build image with local dev tag
	// docker build --build-arg MODE=dev -t IMAGE:VERSION.

	// step5: docker image in minikube registry pushen

	// step6: add local version in overwrite map

	// step7: redeploy with overwrite map

	// todo: add tag overwrite map unter %RUBRION_DEPLOYMENT_DIR%/.runtime/run/rollout.yaml
	// format is image: "local-version"
}
