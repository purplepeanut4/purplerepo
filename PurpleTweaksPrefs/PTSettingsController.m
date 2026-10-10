#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PTSettingsController : PSListController
@end

@implementation PTSettingsController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Appearance"];
        [items addObject:group];
        NSArray *options = @[
            @[@"HideIconLabels", @"Hide Home Screen Icon Labels"],
            @[@"RoundedIcons", @"Rounded App Icon Corners"],
            @[@"TranslucentDock", @"Translucent Dock"],
            @[@"TranslucentFolders", @"Translucent Folders"],
            @[@"BlurSurfaces", @"Blur Selected Surfaces"],
            @[@"ReduceAnimations", @"Reduce Interface Animations"],
            @[@"HidePageDots", @"Hide Home Screen Page Dots"],
            @[@"HideDockBackground", @"Hide Dock Background"],
            @[@"DarkSurfaces", @"Dark Translucent Surfaces"],
            @[@"LiquidGlass", @"Liquid Glass-Inspired Style"]
        ];
        for (NSArray *option in options) {
            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:option[1]
                target:self set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:Nil cell:PSSwitchCell edit:Nil];
            [spec setProperty:option[0] forKey:@"key"];
            [spec setProperty:@"com.purplesquarecube.purpletweaks" forKey:@"defaults"];
            [spec setProperty:@NO forKey:@"default"];
            [items addObject:spec];
        }
        PSSpecifier *note = [PSSpecifier groupSpecifierWithName:@"Compatibility"];
        [note setProperty:@"Liquid Glass is an iOS 12-compatible visual approximation, not Apple's native newer system material. Some options depend on SpringBoard internals and may vary by device." forKey:@"footerText"];
        [items addObject:note];
        _specifiers = items;
    }
    return _specifiers;
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.purplesquarecube.purpletweaks.plist"] ?: [NSMutableDictionary dictionary];
    prefs[[specifier propertyForKey:@"key"]] = value;
    [prefs writeToFile:@"/var/mobile/Library/Preferences/com.purplesquarecube.purpletweaks.plist" atomically:YES];
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.purplesquarecube.purpletweaks.plist"];
    id value = prefs[[specifier propertyForKey:@"key"]];
    return value ?: [specifier propertyForKey:@"default"] ?: @NO;
}
@end