// QuietHUD Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.quiethud";
static NSString *const kNotif  = @"com.purplesquarecube.quiethud/prefsChanged";

@interface QuietHUDRootListController : PSListController
@end

@implementation QuietHUDRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"QuietHUD", @"Stop the pop-ups from covering your screen. The change itself (volume, brightness, silent mode) still happens.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Hide", nil)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Volume", @"volume", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Brightness", @"brightness", NO)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Ringer / Silent Switch", @"ringer", NO)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Rotation Lock", @"rotation", NO)];
    _specifiers = s;
    return _specifiers;
}
@end
