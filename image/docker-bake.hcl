# Builds the builder images: docker buildx bake [target...]
#
# Targets: linux-x86_64, linux-arm64, linux-musl-x86_64, linux-musl-arm64, or
# the groups linux and linux-musl. scripts/builder-image.sh sets IMAGE_TAG to
# the hash of this directory, the tag that the Linux builds use.
#
# Each dependency is its own stage, so with a layer cache that keeps every stage
# (CI uses --set '*.cache-to=type=gha,mode=max'), changing one recipe only
# rebuilds that dependency.

variable "IMAGE_REPO" {
  default = "ghcr.io/trubygems/traveling-ruby-builder"
}

variable "IMAGE_TAG" {
  default = "dev"
}

group "default" {
  targets = ["linux", "linux-musl"]
}

target "builder" {
  name = "${platform}-${arch}"
  matrix = {
    platform = ["linux", "linux-musl"]
    arch     = ["x86_64", "arm64"]
  }
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = [arch == "arm64" ? "linux/arm64" : "linux/amd64"]
  args = {
    DISTRO = platform == "linux" ? "centos7" : "alpine"
  }
  tags = ["${IMAGE_REPO}-${arch}:${platform == "linux" ? "centos7" : "alpine"}-${IMAGE_TAG}"]
}

group "linux" {
  targets = ["linux-x86_64", "linux-arm64"]
}

group "linux-musl" {
  targets = ["linux-musl-x86_64", "linux-musl-arm64"]
}
