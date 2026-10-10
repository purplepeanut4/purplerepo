#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
    else if (PTEnabled(@"TranslucentDock")) alpha = MIN(alpha, 0.5);
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
    NSString *className = NSStringFromClass([self class]);
    BOOL glassTarget = [className containsString:@"Backdrop"] || [className containsString:@"Blur"];
    if (PTEnabled(@"LiquidGlass") && glassTarget) {
        self.layer.cornerRadius = 16.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
    }
    if (PTEnabled(@"BlurSurfaces") && glassTarget && ![className containsString:@"Blur"]) {
        self.alpha = MIN(self.alpha, 0.82);
    }
    if (PTEnabled(@"DarkSurfaces") && glassTarget) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.55];
    }
}
%end

%ctor {
    @autoreleasepool {
        %init;
    }
}