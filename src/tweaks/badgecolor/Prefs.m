// BadgeColor Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.badgecolor";
static NSString *const kNotif  = @"com.purplesquarecube.badgecolor/prefsChanged";

@interface BadgeColorRootListController : PSListController
@end

@implementation BadgeColorRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"BadgeColor", @"Change the look of the notification badges on your icons. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Look", nil)];
    [s addObject:PKList(self, kDomain, kNotif, @"Color", @"color", @"7C3AED",
        @[@"default", @"7C3AED", @"1E66F5", @"2BB673", @"FF9F1C", @"FF5FA2", @"14B8C4", @"3A3A3C", @"8E8E93"],
        @[@"Original Red", @"Purple", @"Blue", @"Green", @"Orange", @"Pink", @"Teal", @"Charcoal", @"Gray"])];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Size", @"size", 1.0, 0.6, 1.5)];
    _specifiers = s;
    return _specifiers;
}
@end
