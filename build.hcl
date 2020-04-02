# docker buildx bake -f build.hcl --no-cache --progress plain 2>&1 | tee  multi.log
target "default" {
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v6", "linux/arm/v7"]
}
