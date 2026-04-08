### Command Usage 

```bash
# Install dependencies and setup environment (run this command only once)
deployment.sh install
```

```bash
# Validate install without starting stoping or modifying the application
deployment.sh hello
```

```bash
# Start the application with the specified enviroment
deployment.sh start <env> 
# e.g., deployment.yaml.sh start lab
```

```bash
# Stop the application
deployment.sh status
```

```bash
# Deploy a specific pod with the optional -f flag to overwrite existing pods
deployment.sh deploy <pod> [-f]
```

```bash
# Overwirte a specific image with a new local image
deployment.sh overwrite <image>
```

```bash
# Stop the application
deployment.sh stop
```

### Placeholders for the deployments
#### Static Placeholders
> {{NAMESPACE}}: The namespace where the application is deployed without the prefix (e.g. proxy, infra, ...).

> {{ENVIROMENT}}: The environment to deploy (e.g. dev, staging, prod).

> {{DOMAIN}}: The domain name for the application (e.g. rubrion.lab).
> 
> {{PREFIX}}: The domain name for the application but with a - (e.g. rubrion-lab).

> {{MEMORY_USAGE_LIMIT}}: The memory limit for the hole cluster (e.g. 16GiB).

> {{CPU_USAGE_LIMIT}}: The CPU limit for the hole cluster (e.g. 600) (100% = 1 CPU Core).

> {{GAME_SERVER_MINIMAL}}: The minimal number of game servers to be deployed (e.g. 2).

#### Dynamic Placeholders
> {{IMAGE:imageid}}: The hole image name with the tag (e.g. myapp:latest)
> 
> {{PORT:portid}}: The hole image name with the tag (e.g. myapp:latest)

```dir
k8s/

  global/
    namespace.yaml
    resourcequota.yaml

  env/
    prod.yaml
    staging.yaml
    dev.yaml

  proxy/
    deployment.yaml
    service.yaml

  game/
    statefulset.yaml
    service.yaml
    pvc.yaml

  infra/
    postgres.yaml
    redis.yaml

  api/
    deployment.yaml
    service.yaml
    ingress.yaml

  web/
    deployment.yaml
    service.yaml
    ingress.yaml
```