// TapLock Settings pane - by purplepeanut4
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.taplock";
static NSString *const kNotif  = @"com.purplesquarecube.taplock/prefsChanged";

@interface TapLockRootListController : PSListController
@end

@implementation TapLockRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"TapLock", @"Double-tap an empty spot to lock your device, so you don't have to reach for the power button.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Where", @"Taps on icons, widgets and folders are ignored.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Home Screen", @"home", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Dock", @"dock", YES)];
    _specifiers = s;
    return _specifiers;
}
@end
