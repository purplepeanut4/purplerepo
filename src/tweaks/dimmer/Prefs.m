// Dimmer Settings pane - by purplepeanut4
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.dimmer";
static NSString *const kNotif  = @"com.purplesquarecube.dimmer/prefsChanged";

@interface DimmerRootListController : PSListController
@end

@implementation DimmerRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    NSMutableArray *hv = [NSMutableArray array], *ht = [NSMutableArray array];
    for (int h = 0; h < 24; h++) {
        [hv addObject:@(h)];
        [ht addObject:[NSString stringWithFormat:@"%d:00 %@", h % 12 == 0 ? 12 : h % 12, h < 12 ? @"AM" : @"PM"]];
    }
    [s addObject:PKGroup(@"Dimmer", @"Makes the screen darker than the brightness slider allows, and warmer if you like. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Look", @"The overlay also shows in screenshots.")];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Extra Dimming", @"dim", 0.35, 0, 0.85)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Warm Tint", @"warm", 0.15, 0, 0.5)];
    [s addObject:PKGroup(@"Schedule", nil)];
    [s addObject:PKList(self, kDomain, kNotif, @"When", @"schedule", @0, @[@0, @1], @[@"Always", @"Custom Hours"])];
    [s addObject:PKList(self, kDomain, kNotif, @"From", @"start", @21, hv, ht)];
    [s addObject:PKList(self, kDomain, kNotif, @"Until", @"end", @7, hv, ht)];
    _specifiers = s;
    return _specifiers;
}
@end
