# Docker multiarch images

# Known limitations

- Tested under Linux, Ubuntu 16.04 and Ubuntu 18.04
- there are some limitations on old 3.10 kernels
- not sure if you can have different docker buildx context per shell
  feels like it is changed :/

# Requirements

- ensure you have qemu-user package and it's dependencies

```bash
apt-get update && apt-get install -y qemu-user
```

- ensure you have docker version 19.03.x

```bash
$ docker --version
Docker version 19.03.8, build afacb8b7f0
```

- enable docker experimental CLI

```bash
$ export DOCKER_CLI_EXPERIMENTAL=enabled
```

- check if your docker buildx works

```bash
$ docker buildx version
github.com/docker/buildx v0.3.1-tp-docker 6db68d029599c6710a32aa7adcba8e5a344795a7
```

- linux only - adjust linux host so that it has proper binfmt_misc, notice that this needs to be re-run on host restart (unless you also install qemu-user-static on host but it may contain older versions)

```bash
$ uname -m
x86_64

$ docker run --rm -t arm64v8/ubuntu uname -m
standard_init_linux.go:211: exec user process caused "exec format error"

$ docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

$ docker run --rm -t arm64v8/ubuntu uname -m
aarch64
```

# Basic usage

- we assume that Dockerfile is in current directory
- default docker builder is used and it is usually limited to amd64

- use `docker buildx --platform=<platform>` to build specific images for given platform

```bash
$ docker buildx build -t test-multiarch --platform=linux/amd64 .
```

- check image that you created

```bash
$ docker inspect test-multiarch|grep Arch
        "Architecture": "amd64",
```

# Separate builder

Moreover default builder is not aware of the additional platforms if it is not restarted.
We may need to restart default builder so it picks up the binaries, or we can use new builder.

We will use separate builder.

- check available builders for your docker builder

```bash
$ docker buildx ls
NAME/NODE DRIVER/ENDPOINT STATUS  PLATFORMS
default * docker
  default default         running linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
```

- create a new builder named `test-multiarch`, notice that it is set as default (the asterisk)

```bash
$ docker buildx create --use --name test-multiarch
```

- let's see the builders again

```bash
$ docker buildx ls
NAME/NODE         DRIVER/ENDPOINT             STATUS   PLATFORMS
test-multiarch *  docker-container
  test-multiarch0 unix:///var/run/docker.sock inactive
default           docker
  default         default                     running  linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6

```

- inspect current builder

```bash
$ docker buildx inspect
Name:   test-multiarch
Driver: docker-container

Nodes:
Name:      test-multiarch0
Endpoint:  unix:///var/run/docker.sock
Status:    running
Platforms: linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
```

# Building multiple images at once

- use `docker buildx --platform=[<platform>,<platform>]` to build multiple images at once, but without exporting
  you will have to use `--push` or export them one by one because it is not supported yet

```bash
$ docker buildx build -t test-multiarch --platform=linux/amd64,linux/arm/v6,linux/arm/v7 .
```

- export each image to current docker host (should be quite fast because images are already built)

```bash
$ docker buildx build --load -t test-multiarch:amd64 --platform=linux/amd64 .
$ docker buildx build --load -t test-multiarch:armv6 --platform=linux/arm/v6 .
$ docker buildx build --load -t test-multiarch:armv7 --platform=linux/arm/v7 .
```

- check image that you created

```bash
$ docker inspect test-multiarch:armv7|grep Arch
        "Architecture": "arm",
```


# Merge multiple images into one manifest

TODO: merging manifest
This step is not needed if you used `--push` parameter.

Otherwise you can merge multiple images (layers) into the single manifest.
This way you can have different platforms pointing to the single image name,
making kubernetes deployments WAY easier.

# Advanced

## Using single remote host to build

Notice - if using `--load` it will push image to the docker on that remote host.

- ensure remote host has installed docker and so on - just like in requirements section
- ensure remote user is in docker group so he/she/AH-64 can access docker daemon
- TODO: ensure remote host can push to repos (pass creds)
- configure local system to use remote docker host, via SSH

```bash
export DOCKER_HOST=ssh://kaszpir@nyx-m6v
```

- run command to install binaries on remote host, required for new builder

```bash
$ docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

- create remote builder

```bash
$ docker buildx create --use --name nyx $DOCKER_HOST
nyx

$ docker buildx --use nyx
```

- inspect the builder, and use it

```bash
$ docker buildx ls
NAME/NODE         DRIVER/ENDPOINT             STATUS   PLATFORMS
default *         docker
  default         default                     running  linux/amd64, linux/386
```

- build image

```bash
$ docker buildx build -t donkeycar:v3.1.1-arm32v7 --platform=linux/arm/v7 .
```

## Using multiple hosts

- ensure to unset `DOCKER_HOST`, create new builder named `farm`, check current builders

```bash
$ unset DOCKER_HOST
$ docker buildx create --name farm
farm
$ docker buildx ls
NAME/NODE         DRIVER/ENDPOINT             STATUS   PLATFORMS
farm              docker-container
  farm0           unix:///var/run/docker.sock inactive
default *         docker
  default         default                     running  linux/amd64, linux/386
```

- add new host to the `farm` builder, notice that this is rasebrry pi, see how it changed

```bash
$ docker buildx create --name farm --append ssh://pi@hormes
farm

$ docker buildx ls
NAME/NODE         DRIVER/ENDPOINT             STATUS   PLATFORMS
farm              docker-container
  farm0           unix:///var/run/docker.sock inactive
  farm1           ssh://pi@hormes             inactive
default *         docker
  default         default                     running  linux/amd64, linux/386

```

- use the `farm` builder

```bash
$ docker buildx use farm
$ docker buildx ls
NAME/NODE         DRIVER/ENDPOINT             STATUS   PLATFORMS
farm *            docker-container
  farm0           unix:///var/run/docker.sock inactive
  farm1           ssh://kaszpir@nyx-m6v       inactive
default           docker
  default         default                     running  linux/amd64, linux/386
```

- inspect builder, also ensure to start it by using `--bootstrap`

```bash
$ docker buildx inspect --bootstrap
Name:   farm
Driver: docker-container

Nodes:
Name:      farm0
Endpoint:  unix:///var/run/docker.sock
Status:    running
Platforms: linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6

Name:      farm1
Endpoint:  ssh://pi@hormes
Status:    running
Platforms: linux/arm/v7, linux/arm/v6
```


- run the build

```bash
$ docker buildx build --platform=linux/arm/v6,linux/arm/v7,linux/arm64,linux/amd64 .
```

- in another shell check the builder status

```bash
$ docker buildx ls
NAME/NODE DRIVER/ENDPOINT             STATUS  PLATFORMS
farm *    docker-container
  farm0   unix:///var/run/docker.sock running linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
  farm1   ssh://pi@hormes             running linux/arm/v7, linux/arm/v6
```


Known limitation:

Unfortunately this still will run arm bulds on `farm0` node.
Also recreateing build context with `--platform linux/amd64` will not limit host to the architecture.

Let's dig in into `docker context`

```bash
$ docker context ls
NAME                DESCRIPTION                               DOCKER ENDPOINT               KUBERNETES ENDPOINT                ORCHESTRATOR
default *           Current DOCKER_HOST based configuration   unix:///var/run/docker.sock   https://127.0.0.1:6443 (default)   swarm

```

- add new contexts to the docker

```bash
$ docker context create hormes --description "rpi direct" --docker "host=ssh://pi@hormes"
hormes
Successfully created context "hormes"
$ docker context create nyx --description "nyx" --docker "host=ssh://kaszpir@nyx-m6v"
nyx
Successfully created context "nyx"

$ docker context ls
NAME                DESCRIPTION                               DOCKER ENDPOINT               KUBERNETES ENDPOINT                ORCHESTRATOR
default *           Current DOCKER_HOST based configuration   unix:///var/run/docker.sock   https://127.0.0.1:6443 (default)   swarm
hormes              rpi direct                                ssh://pi@hormes
nyx                 nyx                                       ssh://kaszpir@nyx-m6v
```

- notice that the hosts are auto added to docker buildx, but runnning `docker buildx ls` will show that the nodes are offline

```bash
$ docker buildx ls
NAME/NODE DRIVER/ENDPOINT             STATUS   PLATFORMS
farm *    docker-container
  farm0   unix:///var/run/docker.sock inactive
hormes    docker
  hormes  hormes                      Cannot connect to the Docker daemon at http://docker. Is the docker daemon running?: driver not connecting
nyx       docker
  nyx     nyx                         Cannot connect to the Docker daemon at http://docker. Is the docker daemon running?: driver not connecting
default   docker
  default default                     running linux/amd64, linux/386
```

- so let's use nyx context, to trigger if it's alive, well it is

```
$ docker context use nyx
nyx
Current context is now "nyx"

$ docker info
...
Server:
...
 Kernel Version: 4.15.0-91-generic
 Operating System: Ubuntu 18.04.4 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 12
 Total Memory: 23.53GiB
 Name: nyx-m6v
...
 Username: kaszpir
...

$ docker buildx ls
WARN[0007] commandConn.CloseWrite: commandconn: failed to wait: signal: killed
WARN[0007] commandConn.CloseWrite: commandconn: failed to wait: signal: killed
WARN[0007] commandConn.CloseRead: commandconn: failed to wait: signal: killed
WARN[0007] commandConn.CloseWrite: commandconn: failed to wait: signal: killed
NAME/NODE DRIVER/ENDPOINT             STATUS   PLATFORMS
farm      docker-container
  farm0   unix:///var/run/docker.sock inactive
hormes    docker
  hormes  hormes                      Cannot connect to the Docker daemon at http://docker. Is the docker daemon running?: driver not connecting
nyx *     docker
  nyx     nyx                         running linux/amd64, linux/386
default   docker
  default default                     running linux/amd64, linux/386


```

- switching context to hormes will unfortunatly render nyx unavailable

- let's create new buldx, notice that `linux/amd64, linux/arm64,` (yes, twice) is set under nyx node

```bash
$ docker buildx create --name farm hormes
$ docker buildx create --name farm nyx --append
$ docker buildx use farm
$ docker buildx inspect --bootstrap
[+] Building 4.5s (1/2)
[+] Building 5.2s (2/2) FINISHED
 => [farm1 internal] booting buildkit                                                   3.3s
 => => pulling image moby/buildkit:buildx-stable-1                                      2.2s
 => => creating container buildx_buildkit_farm1                                         1.0s
 => [farm0 internal] booting buildkit                                                   5.0s
 => => pulling image moby/buildkit:buildx-stable-1                                      2.5s
 => => creating container buildx_buildkit_farm0                                         2.5s
Name:   farm
Driver: docker-container

Nodes:
Name:      farm0
Endpoint:  hormes
Status:    running
Platforms: linux/arm/v7, linux/arm/v6

Name:      farm1
Endpoint:  nyx
Status:    running
Platforms: linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6

```

```bash
docker rm farm
docker buildx create --name farm --node farm0 --platform linux/arm/v7,linux/arm/v6,linux/arm --driver-opt=network=host hormes
docker buildx create --append --name farm --node farm1 --platform linux/amd64,linux/arm64 --driver-opt=network=host nyx
```

```bash
$ docker buildx inspect --bootstrap
Name:   farm
Driver: docker-container

Nodes:
Name:      farm0
Endpoint:  hormes
Status:    running
Platforms: linux/arm/v7, linux/arm/v6

Name:      farm1
Endpoint:  nyx
Status:    running
Platforms: linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6

$ docker buildx ls
NAME/NODE DRIVER/ENDPOINT  STATUS  PLATFORMS
farm *    docker-container         
  farm0   hormes           running linux/arm/v7, linux/arm/v6, linux/arm/v7, linux/arm/v7, linux/arm/v6
  farm1   nyx              running linux/amd64, linux/arm64, linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
hormes    docker                   
  hormes  hormes           running linux/arm/v7, linux/arm/v6
nyx       docker                   
  nyx     nyx              running linux/amd64, linux/386
default   docker                   
  default default          running linux/amd64, linux/386

```


- build multiple images using docker buildx bake, it requires HCL file (not sure if possible to pass platform via docker-compose yaml file)

```bash
docker buildx bake -f build.hcl --no-cache --progress plain 2>&1 | tee  multi.log
```


##  Hype tech

TODO:
- use kubernetes! :feelsgood:
- WATCH OUT FOR CURRNET KUBECONFIG CONTEXT, that is, don't build on prodution cluster ;D
- [kubernetes as builder](https://github.com/docker/buildx/pull/167)


```bash
$ docker buildx create --driver kubernetes --driver-opt replicas=3 --use
$ ocker buildx build -t foo --load .
```

# References

- [docker buildx docs](https://docs.docker.com/buildx/working-with-buildx/) - but this is quite enigmatic
- [github docker/buildx](https://github.com/docker/buildx) - yeah go and read the source...
- [building multi architecture docker images with buildx](https://medium.com/@artur.klauser/building-multi-architecture-docker-images-with-buildx-27d80f7e2408) - very worth to read
- [qemu-user-static](https://github.com/multiarch/qemu-user-static)
- [mirailabs.io blog](https://mirailabs.io/blog/multiarch-docker-with-buildx/)
- [docker multiple arch in travis](https://sanisimov.com/2019/03/building-docker-images-for-multiple-architectures/)
