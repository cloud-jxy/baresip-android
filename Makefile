#
# Makefile
#
# Copyright (C) 2014 Creytiv.com
#

# Paths to your Android SDK/NDK
NDK_PATH  := /Users/jxy/Library/Android/sdk/ndk-bundle
# NDK_PATH  := /Users/jxy/android-ndk-r11c
SDK_PATH  := /Users/jxy/Library/Android/sdk

PLATFORM  := android-17

# Path to install binaries on your Android-device
TARGET_PATH=/data/local/tmp

# Config path where .baresip directory is located
CONFIG_PATH=/data/local/tmp


OS        := $(shell uname -s | tr "[A-Z]" "[a-z]")

ifeq ($(OS),linux)
	HOST_OS   := linux-x86_64
endif
ifeq ($(OS),darwin)
	HOST_OS   := darwin-x86_64
endif


# Tools
SYSROOT   := $(NDK_PATH)/platforms/$(PLATFORM)/arch-arm/usr
PREBUILT  := $(NDK_PATH)/toolchains/arm-linux-androideabi-4.9/prebuilt
BIN       := $(PREBUILT)/$(HOST_OS)/bin
CC        := $(BIN)/arm-linux-androideabi-gcc
CXX       := $(BIN)/arm-linux-androideabi-g++
RANLIB    := $(BIN)/arm-linux-androideabi-ranlib
AR        := $(BIN)/arm-linux-androideabi-ar
ADB       := $(SDK_PATH)/platform-tools/adb
PWD       := $(shell pwd)

# Compiler and Linker Flags
#
# NOTE: use -isystem to avoid warnings in system header files
CFLAGS    := \
	-isystem $(SYSROOT)/include/ \
	-I$(PWD)/openssl/include \
	-march=armv7-a \
	-I$(PWD)/openssl/include \
	-I$(PWD)/libav \
	-I$(PWD)/libvpx \
	-mfloat-abi=softfp -mfpu=neon \
	-I$(PWD) \
	-fPIE -fPIC \
	-DCONFIG_PATH='\"$(CONFIG_PATH)\"'
LFLAGS    := -L$(SYSROOT)/lib/ \
	-L$(PWD)/openssl \
	-L$(PWD)/libav2/libavcodec \
	-L$(PWD)/libav2/libavdevice \
	-L$(PWD)/libav2/libavfilter \
	-L$(PWD)/libav2/libavformat \
	-L$(PWD)/libav2/libavutil \
	-L$(PWD)/libav2/libavresample \
	-L$(PWD)/libav2/libswscale \
	-L$(PWD)/libvpx \
	-L$(PWD)/SDL2-2.0.7/build/android/obj/local/armeabi \
	-fPIE -pie
LFLAGS    += --sysroot=$(NDK_PATH)/platforms/$(PLATFORM)/arch-arm


COMMON_FLAGS := CC=$(CC) \
		CXX=$(CXX) \
		RANLIB=$(RANLIB) \
		EXTRA_CFLAGS="$(CFLAGS) -DANDROID" \
		EXTRA_CXXFLAGS="$(CFLAGS) -DANDROID" \
		EXTRA_LFLAGS="$(LFLAGS)" \
		SYSROOT=$(SYSROOT) \
		SYSROOT_ALT= \
		HAVE_LIBRESOLV= \
		HAVE_PTHREAD=1 \
		HAVE_PTHREAD_RWLOCK=1 \
		HAVE_LIBPTHREAD= \
		HAVE_INET_PTON=1 \
		HAVE_INET6=1 \
		PEDANTIC= \
		OS=linux ARCH=arm \
		USE_OPENSSL=yes \
		USE_OPENSSL_DTLS=yes \
		USE_OPENSSL_SRTP=yes \
		ANDROID=yes

default:	baresip

libre.a: Makefile
	@rm -f re/libre.*
	@make $@ -C re $(COMMON_FLAGS)

librem.a:	Makefile libre.a
	@rm -f rem/librem.*
	@make $@ -C rem $(COMMON_FLAGS)

.PHONY: baresip
baresip:	Makefile librem.a libre.a
	@rm -f baresip/baresip baresip/src/static.c
	PKG_CONFIG_LIBDIR="$(SYSROOT)/lib/pkgconfig" \
	make $@ -C baresip $(COMMON_FLAGS) STATIC=1 \
		LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem \
	        MOD_AUTODETECT= \
		EXTRA_MODULES="g711 stdio opensles dtls_srtp avcodec avformat " \


.PHONY: selftest
selftest:	Makefile librem.a libre.a
	@rm -f baresip/selftest baresip/src/static.c
	PKG_CONFIG_LIBDIR="$(SYSROOT)/lib/pkgconfig" \
	make selftest -C baresip $(COMMON_FLAGS) STATIC=1 \
		LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem \
	        MOD_AUTODETECT=
	$(ADB) push baresip/selftest $(TARGET_PATH)/selftest
	$(ADB) shell "cd $(TARGET_PATH) && ./selftest "


install:	baresip
	$(ADB) push baresip/baresip $(TARGET_PATH)/baresip

config:
	$(ADB) push .baresip $(TARGET_PATH)/.baresip
	$(ADB) push baresip/share $(TARGET_PATH)/share

clean:
	make clean -C baresip
	make clean -C rem
	make clean -C re

.PHONY: openssl
openssl:
	cd openssl && \
		CC=$(CC) RANLIB=$(RANLIB) AR=$(AR) \
		./Configure android-armv7 && \
		ANDROID_DEV=$(SYSROOT) make build_libs

emulator:
	@$(SDK_PATH)/tools/emulator -avd test

shell:
	@$(ADB) shell

info:
	make $@ -C re $(COMMON_FLAGS)

dump:
	@echo "NDK_PATH = $(NDK_PATH)"
	@echo "SDK_PATH = $(SDK_PATH)"
	@echo "HOST_OS  = $(HOST_OS)"

#
# additional targets for `retest'
#

test: retest
.PHONY: retest
retest:		Makefile librem.a libre.a
	@rm -f retest/retest
	@make $@ -C retest $(COMMON_FLAGS) LIBRE_SO=$(PWD)/re \
		LIBREM_PATH=$(PWD)/rem
	$(ADB) push retest/retest $(TARGET_PATH)/retest
	$(ADB) push retest/data $(TARGET_PATH)/data
	$(ADB) shell "cd $(TARGET_PATH) && ./retest -r -v"
