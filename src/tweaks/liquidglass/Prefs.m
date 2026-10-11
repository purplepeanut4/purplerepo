// Liquid Glass Settings pane - by purplesquarecube

#import <UIKit/UIKit.h>

// ---- Minimal declarations of the private Preferences framework ----
@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                  target:(id)target
                                     set:(SEL)set
                                     get:(SEL)get
                                  detail:(Class)detail
                                    cell:(NSInteger)cell
                                    edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@interface PSListController : UIViewController {
    NSMutableArray *_specifiers;
}
- (NSArray *)specifiers;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end

@interface PSListItemsController : PSListController
@end

enum { LGCellLinkList = 2, LGCellSlider = 5, LGCellSwitch = 6 };

static NSString *const kDomain = @"com.purplesquarecube.liquidglass";
static NSString *const kNotif  = @"com.purplesquarecube.liquidglass/prefsChanged";

@interface LiquidGlassRootListController : PSListController
@end

@implementation LiquidGlassRootListController

- (PSSpecifier *)switchNamed:(NSString *)name key:(NSString *)key def:(BOOL)def {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:LGCellSwitch edit:nil];
    [s setProperty:kDomain forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:@(def) forKey:@"default"];
    [s setProperty:kNotif forKey:@"PostNotification"];
    return s;
}

- (PSSpecifier *)sliderNamed:(NSString *)name key:(NSString *)key def:(double)def min:(double)mn max:(double)mx {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:LGCellSlider edit:nil];
    [s setProperty:kDomain forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:@(def) forKey:@"default"];
    [s setProperty:@(mn) forKey:@"min"];
    [s setProperty:@(mx) forKey:@"max"];
    [s setProperty:@YES forKey:@"showValue"];
    [s setProperty:kNotif forKey:@"PostNotification"];
    return s;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];

    PSSpecifier *g0 = [PSSpecifier groupSpecifierWithName:@"Liquid Glass"];
    [g0 setProperty:@"Adds a glass edge, soft shine and tilt-reactive highlight to the interface. Changes apply instantly." forKey:@"footerText"];
    [s addObject:g0];
    [s addObject:[self switchNamed:@"Enabled" key:@"enabled" def:YES]];

    PSSpecifier *g1 = [PSSpecifier groupSpecifierWithName:@"Apply Glass To"];
    [g1 setProperty:@"If something looks wrong, turn that one off." forKey:@"footerText"];
    [s addObject:g1];
    [s addObject:[self switchNamed:@"Dock" key:@"dock" def:YES]];
    [s addObject:[self switchNamed:@"Folders" key:@"folders" def:YES]];
    [s addObject:[self switchNamed:@"Notifications & Control Center" key:@"panels" def:YES]];
    [s addObject:[self switchNamed:@"App Icons" key:@"icons" def:NO]];

    PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"Look"];
    [s addObject:g2];
    [s addObject:[self sliderNamed:@"Edge Glow" key:@"edge" def:0.8 min:0 max:1]];
    [s addObject:[self sliderNamed:@"Shine" key:@"shine" def:0.45 min:0 max:1]];
    [s addObject:[self switchNamed:@"Tilt Shine" key:@"tilt" def:YES]];
    [s addObject:[self sliderNamed:@"Dock Corner Radius" key:@"dockRadius" def:28 min:8 max:44]];

    PSSpecifier *tint = [PSSpecifier preferenceSpecifierNamed:@"Glass Tint" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:[PSListItemsController class] cell:LGCellLinkList edit:nil];
    [tint setProperty:kDomain forKey:@"defaults"];
    [tint setProperty:@"tint" forKey:@"key"];
    [tint setProperty:@1 forKey:@"default"];
    [tint setProperty:@"Glass Tint" forKey:@"label"];
    [tint setProperty:kNotif forKey:@"PostNotification"];
    [tint setValues:@[@0, @1, @2, @3] titles:@[@"None", @"Light", @"Dark", @"Purple"]];
    [s addObject:tint];

    _specifiers = s;
    return _specifiers;
}

@end
