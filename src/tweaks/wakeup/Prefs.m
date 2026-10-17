// WakeUp Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.wakeup";

@interface WakeUpRootListController : PSListController
@end

@implementation WakeUpRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"WakeUp", @"Turns the screen on when the charger state changes, so you can see that it's charging.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"When", nil)];
    [s addObject:PKSwitch(self, kDomain, nil, @"Plugging In", @"plug", YES)];
    [s addObject:PKSwitch(self, kDomain, nil, @"Unplugging", @"unplug", NO)];
    _specifiers = s;
    return _specifiers;
}
@end
