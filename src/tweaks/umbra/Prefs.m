// Umbra Settings pane - by purplepeanut4
#import "PKPrefs.h"
#import <objc/message.h>

static NSString *const kDomain = @"com.purplesquarecube.umbra";
static NSString *const kNotif  = @"com.purplesquarecube.umbra/prefsChanged";

@interface UmbraRootListController : PSListController
@end

@implementation UmbraRootListController

- (NSArray<NSDictionary *> *)installedApps {
    NSMutableArray *result = [NSMutableArray array];
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    id ws = wsClass ? ((id (*)(id, SEL))objc_msgSend)(wsClass, NSSelectorFromString(@"defaultWorkspace")) : nil;
    SEL allSel = NSSelectorFromString(@"allInstalledApplications");
    if (!ws || ![ws respondsToSelector:allSel]) return result;
    NSMutableSet *seen = [NSMutableSet set];
    for (id p in ((id (*)(id, SEL))objc_msgSend)(ws, allSel)) {
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

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    NSMutableArray *hv = [NSMutableArray array], *ht = [NSMutableArray array];
    for (int h = 0; h < 24; h++) {
        [hv addObject:@(h)];
        [ht addObject:[NSString stringWithFormat:@"%d:00 %@", h % 12 == 0 ? 12 : h % 12, h < 12 ? @"AM" : @"PM"]];
    }

    [s addObject:PKGroup(@"Umbra", @"A dark mode for iOS 12. It uses iOS's Smart Invert, so app backgrounds go dark and pictures and videos are left alone in most apps. A few apps may still show inverted photos.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Dark Mode", @"enabled", NO)];

    [s addObject:PKGroup(@"Schedule", nil)];
    [s addObject:PKList(self, kDomain, kNotif, @"When", @"schedule", @0, @[@0, @1], @[@"Always", @"Custom Hours"])];
    [s addObject:PKList(self, kDomain, kNotif, @"From", @"start", @20, hv, ht)];
    [s addObject:PKList(self, kDomain, kNotif, @"Until", @"end", @7, hv, ht)];

    [s addObject:PKGroup(@"Home Screen", @"Off by default: the Home Screen and lock screen keep their normal look and only apps go dark.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Also Dark on the Home Screen and System UI", @"system", NO)];

    [s addObject:PKGroup(@"Apps", @"Switch an app off to keep it light.")];
    for (NSDictionary *app in [self installedApps]) {
        PSSpecifier *sp = PKSwitch(self, kDomain, kNotif, app[@"name"], [@"app." stringByAppendingString:app[@"id"]], YES);
        [sp setProperty:app[@"name"] forKey:@"label"];
        UIImage *icon = [self iconForBundle:app[@"id"]];
        if (icon) [sp setProperty:icon forKey:@"iconImage"];
        [s addObject:sp];
    }
    _specifiers = s;
    return _specifiers;
}
@end
