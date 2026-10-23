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

    [s addObject:PKGroup(@"Sheer", @"An iOS 12 take on Liquid Glass: clear glass panels with a bright rim, light bending at the edge, a floating capsule dock, and highlights that move as you tilt. Changes apply instantly.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];

    [s addObject:PKGroup(@"Glass", @"Clear is thin, see-through glass. Standard is thicker glass that keeps some of the blur, with a stronger rim.")];
    [s addObject:PKList(self, kDomain, kNotif, @"Type", @"style", @0, @[@0, @1], @[@"Clear", @"Standard"])];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Clear Every Blur", @"all", YES)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Blur Left Behind (Clear)", @"blur", 0.12, 0, 1)];
    [s addObject:PKGroup(nil, @"Clear Every Blur also clears the full-screen blurs: Control Center's background, the lock screen, the app switcher and the dock. Turn it off to clear only the panels below.")];

    [s addObject:PKGroup(@"Apply Glass To", @"If something looks wrong, turn that one off.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Dock (floating capsule)", @"dock", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Folders", @"folders", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Notifications & Control Center", @"panels", YES)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"App Icons", @"icons", NO)];

    [s addObject:PKGroup(@"Light", @"Clear glass can be hard to read over bright wallpapers. Add some blur or a dark tint if so.")];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Rim Light", @"edge", 0.85, 0, 1)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Refraction", @"refract", 0.6, 0, 1)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Shine", @"shine", 0.45, 0, 1)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Floating Shadow", @"depth", 0.5, 0, 1)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Tilt Highlights", @"tilt", YES)];

    [s addObject:PKGroup(@"Shape and Tint", nil)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Dock Roundness", @"dockRadius", 60, 8, 60)];
    [s addObject:PKList(self, kDomain, kNotif, @"Glass Tint", @"tint", @0,
        @[@0, @1, @2, @3], @[@"None", @"Light", @"Dark", @"Purple"])];

    _specifiers = s;
    return _specifiers;
}
@end
