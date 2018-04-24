export RELEASE_NAME ?= 0.1~dev
export RELEASE ?= 1
export BOOT_TOOLS_BRANCH ?= master
export KERNEL_DIR ?= kernel

KERNEL_EXTRAVERSION ?= -rockchip-checkpoint_0.3-$(RELEASE)
KERNEL_DEFCONFIG ?= rockchip_linux_defconfig
KERNEL_MAKE ?= make -C $(KERNEL_DIR) \
	EXTRAVERSION=$(KERNEL_EXTRAVERSION) \
	KDEB_PKGVERSION=$(RELEASE_NAME) \
	ARCH=arm64 \
	HOSTCC=aarch64-linux-gnu-gcc \
	CROSS_COMPILE="ccache aarch64-linux-gnu-"
KERNEL_RELEASE ?= $(shell $(KERNEL_MAKE) -s kernelversion)

KERNEL_PACKAGE ?= linux-image-$(KERNEL_RELEASE)_$(RELEASE_NAME)_arm64.deb
KERNEL_HEADERS_PACKAGES ?= linux-headers-$(KERNEL_RELEASE)_$(RELEASE_NAME)_arm64.deb
PACKAGES := linux-rock64-package-$(RELEASE_NAME)_all.deb $(KERNEL_PACKAGE) $(KERNEL_HEADERS_PACKAGES)

IMAGE_SUFFIX := $(RELEASE_NAME)-$(RELEASE)

all: linux-rock64

info:
	echo version: $(KERNEL_VERSION)
	echo release: $(KERNEL_RELEASE)

linux-rock64-$(RELEASE_NAME)_arm64.deb: $(PACKAGES)
	fpm -s empty -t deb -n linux-rock64 -v $(RELEASE_NAME) \
		-p $@ \
		--deb-priority optional --category admin \
		--depends "linux-rock64-package (= $(RELEASE_NAME))" \
		--depends "linux-image-$(KERNEL_RELEASE) (= $(RELEASE_NAME))" \
		--depends "linux-headers-$(KERNEL_RELEASE) (= $(RELEASE_NAME))" \
		--force \
		--url https://gitlab.com/ayufan-rock64/linux-build \
		--description "Rock64 Linux virtual package: depends on kernel and compatibility package" \
		-m "Kamil Trzciński <ayufan@ayufan.eu>" \
		--license "MIT" \
		--vendor "Kamil Trzciński" \
		-a arm64

linux-rock64-package-$(RELEASE_NAME)_all.deb: package
	chmod -R go-w $<
	fpm -s dir -t deb -n linux-rock64-package -v $(RELEASE_NAME) \
		-p $@ \
		--deb-priority optional --category admin \
		--force \
		--depends figlet \
		--depends cron \
		--depends gdisk \
		--depends parted \
		--deb-compression bzip2 \
		--deb-field "Multi-Arch: foreign" \
		--after-install package/scripts/postinst.deb \
		--before-remove package/scripts/prerm.deb \
		--url https://gitlab.com/ayufan-rock64/linux-build \
		--description "Rock64 Linux support package" \
		--config-files /boot/efi/extlinux/ \
		-m "Kamil Trzciński <ayufan@ayufan.eu>" \
		--license "MIT" \
		--vendor "Kamil Trzciński" \
		-a all \
		package/root/=/

linux-rock64-package-$(RELEASE_NAME)_all.rpm: package
	chmod -R go-w $<
	fpm -s dir -t rpm -n linux-rock64-package -v $(RELEASE_NAME) \
		-p $@ \
		--force \
		--depends figlet \
		--depends cron \
		--depends gdisk \
		--depends parted \
		--after-install package/scripts/postinst.deb \
		--before-remove package/scripts/prerm.deb \
		--url https://gitlab.com/ayufan-rock64/linux-build \
		--description "Rock64 Linux support package" \
		--config-files /boot/efi/extlinux/ \
		-m "Kamil Trzciński <ayufan@ayufan.eu>" \
		--license "MIT" \
		--vendor "Kamil Trzciński" \
		-a all \
		package/root/=/

%.tar.xz: %.tar
	pxz -f -3 $<

%.img.xz: %.img
	pxz -f -3 $<

BUILD_SYSTEMS := artful zesty xenial jessie stretch
BUILD_VARIANTS := minimal mate i3 openmediavault
BUILD_ARCHS := armhf arm64
BUILD_MODELS := rock64

%-system.img: $(PACKAGES) linux-rock64-$(RELEASE_NAME)_arm64.deb
	sudo bash rootfs/build-system-image.sh \
		"$(shell readlink -f $@)" \
		"$(shell readlink -f $(subst -system.img,-boot.img,$@))" \
		"$(filter $(BUILD_SYSTEMS), $(subst -, ,$@))" \
		"$(filter $(BUILD_VARIANTS), $(subst -, ,$@))" \
		"$(filter $(BUILD_ARCHS), $(subst -, ,$@))" \
		"$(filter $(BUILD_MODELS), $(subst -, ,$@))" \
		$^

out/u-boot/uboot.img: u-boot/configs/rock64-rk3328_defconfig
	build/mk-uboot.sh rk3328-rock64

%.img: %-system.img out/u-boot/uboot.img
	build/mk-image.sh -c rk3328 -t system -r "$<" -b "$(subst -system.img,-boot.img,$<)" -o "$@.tmp"
	mv "$@.tmp" "$@"

$(KERNEL_PACKAGE): kernel/arch/arm64/configs/$(KERNEL_DEFCONFIG)
	echo -n > kernel/.scmversion
	$(KERNEL_MAKE) $(KERNEL_DEFCONFIG)
	$(KERNEL_MAKE) bindeb-pkg -j$(shell nproc)

$(KERNEL_HEADERS_PACKAGES): $(KERNEL_PACKAGE)

.PHONY: kernelpkg
kernelpkg: $(KERNEL_PACKAGE) $(KERNEL_HEADERS_PACKAGES)

.PHONY: kernel
kernel: kernelpkg

.PHONY: u-boot
u-boot: out/u-boot/uboot.img

.PHONY: linux-package
linux-package: linux-rock64-package-$(RELEASE_NAME)_all.deb linux-rock64-package-$(RELEASE_NAME)_all.rpm

.PHONY: linux-virtual
linux-virtual: linux-rock64-$(RELEASE_NAME)_arm64.deb

.PHONY: xenial-minimal-rock64
xenial-minimal-rock64: xenial-minimal-rock64-$(IMAGE_SUFFIX)-armhf.img.xz xenial-minimal-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: xenial-mate-rock64
xenial-mate-rock64: xenial-mate-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: xenial-i3-rock64
xenial-i3-rock64: xenial-i3-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: jessie-minimal-rock64
jessie-minimal-rock64: jessie-minimal-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: jessie-openmediavault-rock64
jessie-openmediavault-rock64: jessie-openmediavault-rock64-$(IMAGE_SUFFIX)-armhf.img.xz jessie-openmediavault-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: stretch-minimal-rock64
stretch-minimal-rock64: stretch-minimal-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: xenial-rock64
xenial-rock64: xenial-minimal-rock64 xenial-mate-rock64 xenial-i3-rock64

.PHONY: artful-minimal-rock64
artful-minimal-rock64: artful-minimal-rock64-$(IMAGE_SUFFIX)-armhf.img.xz artful-minimal-rock64-$(IMAGE_SUFFIX)-arm64.img.xz

.PHONY: artful-rock64
artful-rock64: artful-minimal-rock64

.PHONY: stretch-rock64
stretch-rock64: stretch-minimal-rock64

.PHONY: jessie-rock64
jessie-rock64: jessie-minimal-rock64 jessie-openmediavault-rock64

.PHONY: linux-rock64
linux-rock64: artful-rock64 xenial-rock64 stretch-rock64 jessie-rock64 linux-virtual

.PHONY: pull-trees
pull-trees:
	git subtree pull --prefix build https://github.com/rockchip-linux/build debian
	git subtree pull --prefix build https://github.com/rock64-linux/build debian

.PHONY: kernel-menuconfig
kernel-menuconfig:
	$(KERNEL_MAKE) $(KERNEL_DEFCONFIG)
	$(KERNEL_MAKE) HOSTCC=gcc menuconfig
	$(KERNEL_MAKE) savedefconfig
	cp $(KERNEL_DIR)/defconfig $(KERNEL_DIR)/arch/arm64/configs/$(KERNEL_DEFCONFIG)

REMOTE_HOST ?= rock64.home

kernel-build:
	$(KERNEL_MAKE) Image dtbs -j$(shell nproc)

kernel-build-with-modules:
	$(KERNEL_MAKE) Image modules dtbs -j$(shell nproc)
	$(KERNEL_MAKE) modules_install INSTALL_MOD_PATH=$(shell pwd)/tmp/linux_modules

kernel-update:
	rsync --partial --checksum -rv $(KERNEL_DIR)/arch/arm64/boot/Image root@$(REMOTE_HOST):$(REMOTE_DIR)/boot/efi/Image
	rsync --partial --checksum -rv $(KERNEL_DIR)/arch/arm64/boot/dts/rockchip/rk3328-rock64.dtb root@$(REMOTE_HOST):$(REMOTE_DIR)/boot/efi/dtb
	rsync --partial --checksum -av tmp/linux_modules/lib/ root@$(REMOTE_HOST):$(REMOTE_DIR)/lib

shell:
	rm kernel
	ln -s linux-kernel/ kernel
	docker build -q -t rock64-linux:build-environment environment/
	docker run -it -v $(CURDIR):$(CURDIR) -w $(CURDIR) rock64-linux:build-environment
