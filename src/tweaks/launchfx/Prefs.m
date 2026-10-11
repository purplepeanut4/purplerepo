// LaunchFX Settings pane - by purplesquarecube

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "LFXEngine.h"

// ---- Minimal declarations of the private Preferences framework ----
@interface PSSpecifier : NSObject
@property (nonatomic) SEL buttonAction;
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
- (void)reloadSpecifiers;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end

@interface PSListItemsController : PSListController
@end

enum { LFXCellLinkList = 2, LFXCellSlider = 5, LFXCellSwitch = 6, LFXCellButton = 13 };

static NSString *const kDomain = @"com.purplesquarecube.launchfx";

@interface LaunchFXRootListController : PSListController
@end

@implementation LaunchFXRootListController

- (id)prefValue:(NSString *)key {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                       (__bridge CFStringRef)kDomain));
}

- (NSArray<NSDictionary *> *)installedApps {
    NSMutableArray *result = [NSMutableArray array];
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    id ws = wsClass ? ((id (*)(id, SEL))objc_msgSend)(wsClass, NSSelectorFromString(@"defaultWorkspace")) : nil;
    SEL allSel = NSSelectorFromString(@"allInstalledApplications");
    if (!ws || ![ws respondsToSelector:allSel]) return result;

    NSArray *proxies = ((id (*)(id, SEL))objc_msgSend)(ws, allSel);
    NSMutableSet *seen = [NSMutableSet set];
    for (id p in proxies) {
        NSString *bid  = [p respondsToSelector:NSSelectorFromString(@"applicationIdentifier")]
            ? ((id (*)(id, SEL))objc_msgSend)(p, NSSelectorFromString(@"applicationIdentifier")) : nil;
        NSString *name = [p respondsToSelector:NSSelectorFromString(@"localizedName")]
            ? ((id (*)(id, SEL))objc_msgSend)(p, NSSelectorFromString(@"localizedName")) : nil;
        NSString *type = [p respondsToSelector:NSSelectorFromString(@"applicationType")]
            ? ((id (*)(id, SEL))objc_msgSend)(p, NSSelectorFromString(@"applicationType")) : nil;
        if (!bid.length || !name.length || [seen containsObject:bid]) continue;
        if (![type isEqualToString:@"User"] && ![type isEqualToString:@"System"]) continue;

        SEL tagsSel = NSSelectorFromString(@"appTags");
        if ([p respondsToSelector:tagsSel]) {
            NSArray *tags = ((id (*)(id, SEL))objc_msgSend)(p, tagsSel);
            if ([tags isKindOfClass:[NSArray class]] && [tags containsObject:@"hidden"]) continue;
        }
        [seen addObject:bid];
        [result addObject:@{ @"id": bid, @"name": name }];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
}

- (UIImage *)iconForBundle:(NSString *)bid {
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![UIImage respondsToSelector:sel]) return nil;
    return ((UIImage *(*)(id, SEL, NSString *, int, CGFloat))objc_msgSend)(
        [UIImage class], sel, bid, 0, [UIScreen mainScreen].scale);
}

#pragma mark specifiers

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];

    // --- General ---
    PSSpecifier *g1 = [PSSpecifier groupSpecifierWithName:@"General"];
    [g1 setProperty:@"Plays when you tap an app icon on the Home Screen or Dock." forKey:@"footerText"];
    [s addObject:g1];

    PSSpecifier *en = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:LFXCellSwitch edit:nil];
    [en setProperty:kDomain forKey:@"defaults"];
    [en setProperty:@"enabled" forKey:@"key"];
    [en setProperty:@YES forKey:@"default"];
    [s addObject:en];

    PSSpecifier *shuf = [PSSpecifier preferenceSpecifierNamed:@"Random Animation Each Time" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:LFXCellSwitch edit:nil];
    [shuf setProperty:kDomain forKey:@"defaults"];
    [shuf setProperty:@"shuffle" forKey:@"key"];
    [shuf setProperty:@NO forKey:@"default"];
    [s addObject:shuf];

    // --- Animation ---
    PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"Animation"];
    [g2 setProperty:@"Choose from 50 effects. Tap Preview to try one right here." forKey:@"footerText"];
    [s addObject:g2];

    NSArray *names = LFXAnimationNames();
    NSMutableArray *aVals = [NSMutableArray array], *aTitles = [NSMutableArray array];
    for (NSUInteger i = 0; i < names.count; i++) {
        [aVals addObject:@(i)];
        [aTitles addObject:[NSString stringWithFormat:@"%lu. %@", (unsigned long)(i + 1), names[i]]];
    }
    PSSpecifier *anim = [PSSpecifier preferenceSpecifierNamed:@"Animation" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:[PSListItemsController class] cell:LFXCellLinkList edit:nil];
    [anim setProperty:kDomain forKey:@"defaults"];
    [anim setProperty:@"animation" forKey:@"key"];
    [anim setProperty:@0 forKey:@"default"];
    [anim setProperty:@"Animation" forKey:@"label"];
    [anim setValues:aVals titles:aTitles];
    [s addObject:anim];

    PSSpecifier *prev = [PSSpecifier preferenceSpecifierNamed:@"Preview Animation" target:self
        set:NULL get:NULL detail:nil cell:LFXCellButton edit:nil];
    prev.buttonAction = @selector(previewAnimation);
    [s addObject:prev];

    PSSpecifier *dur = [PSSpecifier preferenceSpecifierNamed:@"Duration" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:LFXCellSlider edit:nil];
    [dur setProperty:kDomain forKey:@"defaults"];
    [dur setProperty:@"duration" forKey:@"key"];
    [dur setProperty:@0.6 forKey:@"default"];
    [dur setProperty:@0.25 forKey:@"min"];
    [dur setProperty:@1.5 forKey:@"max"];
    [dur setProperty:@YES forKey:@"showValue"];
    [s addObject:dur];

    NSArray *colorVals   = @[@"7C3AED", @"auto", @"000000", @"FFFFFF", @"1E66F5", @"E5383B",
                             @"2BB673", @"FF5FA2", @"FF9F1C", @"14B8C4", @"8E8E93"];
    NSArray *colorTitles = @[@"Purple", @"Match App Icon", @"Black", @"White", @"Blue", @"Red",
                             @"Green", @"Pink", @"Orange", @"Teal", @"Gray"];
    PSSpecifier *col = [PSSpecifier preferenceSpecifierNamed:@"Cover Color" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:[PSListItemsController class] cell:LFXCellLinkList edit:nil];
    [col setProperty:kDomain forKey:@"defaults"];
    [col setProperty:@"color" forKey:@"key"];
    [col setProperty:@"7C3AED" forKey:@"default"];
    [col setProperty:@"Cover Color" forKey:@"label"];
    [col setValues:colorVals titles:colorTitles];
    [s addObject:col];

    // --- Apps ---
    PSSpecifier *g3 = [PSSpecifier groupSpecifierWithName:@"Apps"];
    [g3 setProperty:@"Turn off an app here to open it with the normal iOS animation." forKey:@"footerText"];
    [s addObject:g3];

    for (NSDictionary *app in [self installedApps]) {
        PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:app[@"name"] target:self
            set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
            detail:nil cell:LFXCellSwitch edit:nil];
        [sp setProperty:kDomain forKey:@"defaults"];
        [sp setProperty:[@"app." stringByAppendingString:app[@"id"]] forKey:@"key"];
        [sp setProperty:@YES forKey:@"default"];
        [sp setProperty:app[@"name"] forKey:@"label"];
        UIImage *icon = [self iconForBundle:app[@"id"]];
        if (icon) [sp setProperty:icon forKey:@"iconImage"];
        [s addObject:sp];
    }

    _specifiers = s;
    return _specifiers;
}

#pragma mark preview

- (void)previewAnimation {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    NSInteger idx = [[self prefValue:@"animation"] integerValue];
    if ([[self prefValue:@"shuffle"] boolValue]) idx = arc4random_uniform(LFX_COUNT);

    id dp = [self prefValue:@"duration"];
    double dur = dp ? [dp doubleValue] : 0.6;

    NSString *hex = [self prefValue:@"color"];
    if (![hex isKindOfClass:[NSString class]] || [hex isEqualToString:@"auto"]) hex = @"7C3AED";

    CGRect b = [UIScreen mainScreen].bounds;
    CGPoint origin = CGPointMake(b.size.width * 0.5, b.size.height * 0.75);
    LFXPlay(idx, LFXColorFromHex(hex), origin, 0.15, dur, nil);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    LFXCancel();
}

@end
