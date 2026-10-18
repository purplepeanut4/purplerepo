// Sheer Settings pane - by purplepeanut4
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.liquidglass";
static NSString *const kNotif  = @"com.purplesquarecube.liquidglass/prefsChanged";

@interface LiquidGlassRootListController : PSListController
@end

@implementation LiquidGlassRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];

    [s addObject:PKGroup(@"Sheer", @"Turns frosted blur into clear glass. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];

    [s addObject:PKGroup(@"Style", @"Clear fades out the system blur so you can see straight through. Frosted keeps it.")];
    [s addObject:PKList(self, kDomain, kNotif, @"Glass", @"style", @0, @[@0, @1], @[@"Clear", @"Frosted"])];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Clear Every Blur", @"all", YES)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Blur Left Behind (Clear)", @"blur", 0.12, 0, 1)];
    [s addObject:PKGroup(nil, @"Clear Every Blur also clears the full-screen blurs: Control Center's background, the lock screen, the app switcher and the dock. Turn it off to clear only the panels listed below.")];

    [s addObject:PKGroup(@"Apply Glass To", @"If something looks wrong, turn that one off.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Dock", @"dock", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Folders", @"folders", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Notifications & Control Center", @"panels", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"App Icons", @"icons", NO)];

    [s addObject:PKGroup(@"Look", @"Clear glass can be hard to read over bright wallpapers. Add some blur or a dark tint if so.")];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Edge Glow", @"edge", 0.8, 0, 1)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Shine", @"shine", 0.45, 0, 1)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Tilt Shine", @"tilt", YES)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Dock Corner Radius", @"dockRadius", 28, 8, 44)];
    [s addObject:PKList(self, kDomain, kNotif, @"Glass Tint", @"tint", @0,
        @[@0, @1, @2, @3], @[@"None", @"Light", @"Dark", @"Purple"])];

    _specifiers = s;
    return _specifiers;
}
@end
