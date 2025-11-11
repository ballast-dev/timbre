IMAGE := "ghcr.io/ballast-dev/timbre"
_:
  @just --list

img:
    docker build -t {{IMAGE}} -< Dockerfile
    