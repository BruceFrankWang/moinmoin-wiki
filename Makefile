.PHONY: build

DEPLOY_ACCOUNT := "brucefrankwang"
DEPLOY_IMAGE := "rpi-moinmoin"

docker_deploy:
    ifeq ($(tag),)
        @echo "Usage: make $@ tag=<tag>"
        @exit 1
    endif
    docker tag $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE):latest $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE):$(tag)
    docker push $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE):$(tag)