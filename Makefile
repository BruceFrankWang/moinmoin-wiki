.PHONY: build

DEPLOY_ACCOUNT := "brucefrankwang"
DEPLOY_IMAGE := "rpi-moinmoin"

build:
    docker run --rm --privileged multiarch/qemu-user-static:register --reset
    docker build -t $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE) .

docker_deploy:
    ifeq ($(tag),)
        @echo "Usage: make $@ tag=<tag>"
        @exit 1
    endif
    ifneq ($(tag), latest)
        docker tag $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE):latest $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE):$(tag)
    endif
    docker push $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE):$(tag)