include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PurpleTweaksPrefs
PurpleTweaksPrefs_FILES = PTSettingsController.m
PurpleTweaksPrefs_INSTALL_PATH = /Library/PreferenceBundles
PurpleTweaksPrefs_FRAMEWORKS = UIKit
PurpleTweaksPrefs_PRIVATE_FRAMEWORKS = Preferences
PurpleTweaksPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/PurpleTweaksPrefs.plist"$(ECHO_END)
