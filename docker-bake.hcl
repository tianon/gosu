// Go version
variable "GO_VERSION" {
  default = "1.14"
}

// GitHub reference as defined in GitHub Actions (eg. refs/head/master))
variable "GITHUB_REF" {
  default = ""
}

target "go-version" {
  args = {
    GO_VERSION = GO_VERSION
  }
}

// Special target: https://github.com/crazy-max/ghaction-docker-meta#bake-definition
target "ghaction-docker-meta" {
  tags = ["gosu:local"]
}

group "default" {
  targets = ["image-local"]
}

group "validate" {
  targets = ["lint", "vendor-validate"]
}

target "lint" {
  inherits = ["go-version"]
  dockerfile = "./hack/lint.Dockerfile"
  target = "lint"
}

target "vendor-validate" {
  inherits = ["go-version"]
  dockerfile = "./hack/vendor.Dockerfile"
  target = "validate"
}

target "vendor-update" {
  inherits = ["go-version"]
  dockerfile = "./hack/vendor.Dockerfile"
  target = "update"
  output = ["."]
}

group "test" {
  targets = ["test-alpine", "test-debian"]
}

target "test-alpine" {
  inherits = ["go-version"]
  target = "test-alpine"
}

target "test-debian" {
  inherits = ["go-version"]
  target = "test-debian"
}

target "artifact" {
  args = {
    GIT_REF = GITHUB_REF
  }
  inherits = ["go-version"]
  target = "artifacts"
  output = ["./dist"]
}

target "artifact-all" {
  inherits = ["artifact"]
  platforms = [
    "linux/amd64",
    "linux/arm/v5",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64",
    "linux/386",
    "linux/ppc64le",
    "linux/s390x",
    "linux/mips/hardfloat",
    "linux/mips/softfloat",
    "linux/mipsle/hardfloat",
    "linux/mipsle/softfloat",
    "linux/mips64/hardfloat",
    "linux/mips64/softfloat",
    "linux/mips64le/hardfloat",
    "linux/mips64le/softfloat"
  ]
}

target "image" {
  inherits = ["go-version", "ghaction-docker-meta"]
}

target "image-local" {
  inherits = ["image"]
  output = ["type=docker"]
}

target "image-all" {
  inherits = ["image"]
  platforms = [
    "linux/amd64",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64",
    "linux/386",
    "linux/ppc64le"
  ]
}
