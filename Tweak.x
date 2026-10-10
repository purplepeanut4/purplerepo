#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const PTDomain = @"com.purplesquarecube.purpletweaks";

static BOOL PTEnabled(NSString *key) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.purplesquarecube.purpletweaks.plist"];
    id value = prefs[key];
    return value ? [value boolValue] : NO;
}

%hook SBIconLabelImageParameters
- (BOOL)shouldShowLabel {
    if (PTEnabled(@"HideIconLabels")) return NO;
    return %orig;
}
%end

%hook SBIconListPageControl
- (void)setHidden:(BOOL)hidden {
    if (PTEnabled(@"HidePageDots")) hidden = YES;
    %orig(hidden);
}
%end

%hook SBDockView
- (void)setBackgroundAlpha:(double)alpha {
    if (PTEnabled(@"HideDockBackground")) alpha = 0.0;
    %orig(alpha);
}
%end

%hook SBFolderBackgroundView
- (void)setAlpha:(CGFloat)alpha {
    if (PTEnabled(@"TranslucentFolders")) alpha = MIN(alpha, 0.55);
    %orig(alpha);
}
%end

%hook SBIconView
- (void)layoutSubviews {
    %orig;
    if (PTEnabled(@"RoundedIcons")) {
        self.layer.cornerRadius = 14.0;
        self.layer.masksToBounds = YES;
    }
}
%end

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if (!PTEnabled(@"LiquidGlass")) return;
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Backdrop"] || [className containsString:@"Blur"]) {
        self.layer.cornerRadius = 16.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
    }
}
%end

%ctor {
    @autoreleasepool {
        %init;
    }
}