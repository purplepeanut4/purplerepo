// Tidy Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.tidy";
static NSString *const kNotif  = @"com.purplesquarecube.tidy/prefsChanged";

@interface TidyRootListController : PSListController
@end

@implementation TidyRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"Tidy", @"Clean up your Home Screen. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Hide", nil)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Icon Labels", @"labels", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Notification Badges", @"badges", NO)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Page Dots", @"dots", NO)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Dock Background", @"dock", NO)];
    [s addObject:PKGroup(@"Troubleshooting", @"Restarts SpringBoard. Handy if something looks stuck.")];
    [s addObject:PKButton(self, @"Respring", @selector(doRespring))];
    _specifiers = s;
    return _specifiers;
}
- (void)doRespring { notify_post("com.purplesquarecube.tidy/respring"); }
@end
