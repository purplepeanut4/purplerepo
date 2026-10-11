// BatteryLine Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.batteryline";
static NSString *const kNotif  = @"com.purplesquarecube.batteryline/prefsChanged";

@interface BatteryLineRootListController : PSListController
@end

@implementation BatteryLineRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"BatteryLine", @"A thin line that shows your battery level on top of every app. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];

    [s addObject:PKGroup(@"Look", nil)];
    [s addObject:PKList(self, kDomain, kNotif, @"Position", @"position", @0, @[@0, @1], @[@"Top", @"Bottom"])];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Thickness", @"thickness", 3, 1, 8)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Opacity", @"opacity", 0.9, 0.2, 1)];
    [s addObject:PKList(self, kDomain, kNotif, @"Color", @"color", @"auto",
        @[@"auto", @"7C3AED", @"FFFFFF", @"34C759", @"1E66F5", @"FF5FA2", @"FF9F1C"],
        @[@"Automatic", @"Purple", @"White", @"Green", @"Blue", @"Pink", @"Orange"])];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Show Empty Track", @"track", NO)];

    [s addObject:PKGroup(@"Charging", @"Automatic color turns green while charging, orange under 50% and red under 20%.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Only Show While Charging", @"onlyCharging", NO)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Pulse While Charging", @"pulse", YES)];
    _specifiers = s;
    return _specifiers;
}
@end
