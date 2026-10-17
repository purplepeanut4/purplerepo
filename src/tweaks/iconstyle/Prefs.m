// IconStyle Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.iconstyle";
static NSString *const kNotif  = @"com.purplesquarecube.iconstyle/prefsChanged";

@interface IconStyleRootListController : PSListController
@end

@implementation IconStyleRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"IconStyle", @"Give your app icons depth. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Shadow", @"Pick a coloured shadow for a glow instead.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Icon Shadow", @"shadow", YES)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Strength", @"opacity", 0.35, 0, 1)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Softness", @"radius", 8, 0, 24)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Drop", @"offset", 5, 0, 14)];
    [s addObject:PKList(self, kDomain, kNotif, @"Colour", @"color", @"000000",
        @[@"000000", @"7C3AED", @"1E66F5", @"FF5FA2", @"2BB673", @"FF9F1C", @"FFFFFF"],
        @[@"Black", @"Purple glow", @"Blue glow", @"Pink glow", @"Green glow", @"Orange glow", @"White glow"])];
    [s addObject:PKGroup(@"Size", @"Scales the icon pictures. Names and badges stay put.")];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Icon Size", @"scale", 1.0, 0.75, 1.2)];
    _specifiers = s;
    return _specifiers;
}
@end
