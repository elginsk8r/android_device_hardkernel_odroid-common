#
# Copyright (C) 2018 Hardkernel Co,. Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ifneq ($(filter odroidn2, $(TARGET_DEVICE)),)

FACTORY_PATH := device/hardkernel/odroid-common/factory
DEVICE_FACTORY_PATH := device/hardkernel/$(TARGET_DEVICE)/factory
MKFS_FAT := device/hardkernel/odroid-common/build/tools/mkfs.fat

INSTALLED_SELFINSTALLER_TARGET := $(PRODUCT_OUT)/selfinstall-$(TARGET_DEVICE).img

SELFINSTALL_DIR := $(PRODUCT_OUT)/selfinstall
SELFINSTALL_BOOTLOADER_MESSAGE := $(SELFINSTALL_DIR)/misc.img
SELFINSTALL_UPDATE_PACKAGE := $(SELFINSTALL_DIR)/cache/update.zip
SELFINSTALL_CACHE_DIR := $(SELFINSTALL_DIR)/cache
SELFINSTALL_CACHEIMAGE_TARGET := $(SELFINSTALL_DIR)/cache.img
SELFINSTALL_SPARSE_CACHEIMAGE_TARGET := $(SELFINSTALL_DIR)/cache.ext4
SELFINSTALL_DOSIMAGE_TARGET := $(SELFINSTALL_DIR)/dos.img

$(SELFINSTALL_BOOTLOADER_MESSAGE):
	$(hide) mkdir -p $(dir $@)
	$(hide) dd if=/dev/zero of=$@ bs=16 count=4	# 64 Bytes
	$(hide) echo "recovery" >> $@
	$(hide) echo "--update_package=/cache/update.zip" >> $@

$(SELFINSTALL_UPDATE_PACKAGE): $(SIGNAPK_JAR)
	$(JAVA) -Djava.library.path=$$(dirname $(SIGNAPK_JNI_LIBRARY_PATH)) -jar $(SIGNAPK_JAR) \
		-w $(DEFAULT_KEY_CERT_PAIR).x509.pem $(DEFAULT_KEY_CERT_PAIR).pk8 $(FACTORY_PATH)/update.zip $@

$(SELFINSTALL_CACHE_DIR): $(INSTALLED_CACHEIMAGE_TARGET) $(SELFINSTALL_UPDATE_PACKAGE)
	mkdir -p $(dir $@)
	$(hide) $(ACP) $(PRODUCT_OUT)/cache/ $@

$(SELFINSTALL_SPARSE_CACHEIMAGE_TARGET): $(SELFINSTALL_CACHE_DIR)
	PATH=$(subst $(space),:,$(sort $(dir $(MKEXTUSERIMG)))):$$PATH \
		$(MKEXTUSERIMG) -s $< $@ ext4 cache $(BOARD_CACHEIMAGE_PARTITION_SIZE) -L cache

$(SELFINSTALL_CACHEIMAGE_TARGET): $(SELFINSTALL_SPARSE_CACHEIMAGE_TARGET)
	$(SIMG2IMG) $(SELFINSTALL_SPARSE_CACHEIMAGE_TARGET) $@

$(SELFINSTALL_DOSIMAGE_TARGET): $(INSTALLED_RECOVERYIMAGE_TARGET)
	$(hide) dd if=/dev/zero of=$@ bs=512 count=66526
	$(hide) $(MKFS_FAT) -F16 -n VFAT $@
	$(hide) $(FAT16COPY) $@ $(FACTORY_PATH)/boot.ini

$(INSTALLED_SELFINSTALLER_TARGET): \
	$(SELFINSTALL_BOOTLOADER_MESSAGE) \
	$(INSTALLED_2NDBOOTLOADER_TARGET) \
	$(INSTALLED_BOOTIMAGE_TARGET) \
	$(INSTALLED_RECOVERYIMAGE_TARGET) \
	$(SELFINSTALL_CACHEIMAGE_TARGET) \
	$(SELFINSTALL_DOSIMAGE_TARGET)
	$(call pretty,"Target selfinstaller image: $@")
	$(hide) dd if=/dev/urandom of=$@ conv=fsync bs=512 seek=1920 count=144 # 72K Bytes
ifneq ("$(wildcard $(FACTORY_PATH)/u-boot.bin)","")
	$(hide) dd if=$(FACTORY_PATH)/u-boot.bin of=$@ conv=fsync bs=512 seek=1
else ifneq ("$(wildcard $(DEVICE_FACTORY_PATH)/u-boot.bin)","")
	$(hide) dd if=$(DEVICE_FACTORY_PATH)/u-boot.bin of=$@ conv=fsync bs=512 seek=1
endif
	$(hide) dd if=$(SELFINSTALL_BOOTLOADER_MESSAGE) of=$@ conv=fsync bs=512 seek=2056
	$(hide) dd if=$(FACTORY_PATH)/logo.gz of=$@ conv=fsync bs=512 seek=2064
	$(hide) dd if=$(PRODUCT_OUT)/dtb.img of=$@ conv=fsync bs=512 seek=6160
	$(hide) dd if=$(INSTALLED_BOOTIMAGE_TARGET) of=$@ conv=fsync bs=512 seek=6416
	$(hide) dd if=$(INSTALLED_RECOVERYIMAGE_TARGET) of=$@ conv=fsync bs=512 seek=39184
	$(hide) dd if=$(SELFINSTALL_CACHEIMAGE_TARGET) of=$@ bs=512 seek=88336
	$(hide) dd if=$(SELFINSTALL_DOSIMAGE_TARGET) of=$@ conv=fsync bs=512 seek=2185488 count=66526
	$(hide) echo -e "n\np\n1\n" "2185488\n2251023\n" "t\n4\nw\n" | fdisk $@ > /dev/null
	$(hide) sync
	@echo "Made selfinstaller image: $@"

.PHONY: selfinstaller
selfinstaller: $(INSTALLED_SELFINSTALLER_TARGET)

endif
