SHELL = bash -e
REVISION ?= 1
VERSION ?= 0.0.1
IMG := thedoh/somethingsoon
REGISTRY ?= docker.io
ARCHES ?= arm64 amd64

.PHONY: docker-build
docker-build:
	for a in $(ARCHES); do \
		docker build --build-arg=GOARCH=$$a -t $(IMG):$$a-$(VERSION) . ;\
		$(call set_image_arch,$(REGISTRY)/$(IMG):$$a-$(VERSION),$$a) ;\
		docker tag $(IMG):$$a-$(VERSION) $(IMG):$$a-latest ;\
	done

.PHONY: docker-multiarch
docker-multiarch: docker-build
	arches= ;\
	for a in $(ARCHES); do \
		arches="$$arches $(IMG):$$a-$(VERSION)" ;\
		docker push $(IMG):$$a-$(VERSION) ;\
	done ;\
	docker manifest create $(IMG):$(VERSION) $$arches  ;\
	for a in $(ARCHES); do \
		docker manifest annotate $(IMG):$(VERSION) $(IMG):$$a-$(VERSION) --os linux --arch $$a ;\
	done

.PHONY: docker-push
docker-push: docker-build docker-multiarch
	docker manifest push $(IMG):$(VERSION)

.PHONY: clean
clean:
	for a in $(ARCHES); do \
		docker rmi $(IMG):$$a-$(VERSION) || true ;\
		docker rmi $(IMG):$$a-latest || true ;\
	done ;\
	docker rmi $(IMG):latest || true ;\
	rm -rf ~/.docker/manifests/$(shell echo $(REGISTRY)/$(IMG) | tr '/' '_' | tr ':' '-')-$(VERSION) || true

# Set image Architecture in manifest and replace it in the local registry
# 1 image:tag
# 2 Set Architecture to
define set_image_arch
	cpwd=$$(pwd) ;\
	set -o errexit ;\
	set -o nounset ;\
	set -o pipefail ;\
	savedir=$$(mktemp -d) ;\
	chmod 700 $$savedir ;\
	mkdir -p $$savedir/change ;\
	docker save $(1) > $$savedir/image.tar ;\
	cd $$savedir/change ;\
	tar xf ../image.tar ;\
	jsonfile=$$(find $$savedir/change -name "*.json" -not -name manifest.json) ;\
	origarch=$$(cat $$jsonfile | jq -r .architecture) ;\
	if [[ $(2) != $$origarch ]]; then \
		docker rmi $(1) $(redirect) ;\
		echo "[set_image_arch] changing from $${origarch} to $(2) for $(1)" ;\
		sed -i -e "s,\"architecture\":\"$${origarch}\",\"architecture\":\"$(2)\"," $$jsonfile ;\
		tar cf - * | docker load $(redirect) ;\
		cd .. ;\
	fi ;\
	cd $$cpwd ;\
	\rm -rf -- $$savedir
endef
