TARGET := iphone:clang:latest:12.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PurpleTweaks
PurpleTweaks_FILES = Tweak.x
PurpleTweaks_CFLAGS = -fobjc-arc
PurpleTweaks_FRAMEWORKS = UIKit
PurpleTweaks_PRIVATE_FRAMEWORKS = Preferences
PurpleTweaks_LIBRARIES = substrate
PurpleTweaks_EXTRA_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += PurpleTweaksPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
