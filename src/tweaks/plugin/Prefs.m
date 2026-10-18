// PlugIn Settings pane - by purplepeanut4
#import "PKPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kDomain = @"com.purplesquarecube.plugin";

@interface PlugInRootListController : PSListController
@end

@implementation PlugInRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"PlugIn", @"A light show and a sound when you connect a charger.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Animation", @"Green when you plug in, orange when you unplug.")];
    [s addObject:PKList(self, kDomain, nil, @"Style", @"style", @1, @[@0, @1, @2], @[@"Off", @"Sweep", @"Pulse"])];
    [s addObject:PKSwitch(self, kDomain, nil, @"Also When Unplugging", @"unplug", YES)];
    [s addObject:PKGroup(@"Sound", @"System sounds follow your ringer switch.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Play a Sound", @"sound", YES)];
    [s addObject:PKList(self, kDomain, nil, @"Sound", @"soundID", @1100,
        @[@1100, @1103, @1104, @1108, @1111, @1113],
        @[@"Lock", @"Tink", @"Tock", @"Camera Shutter", @"Confirm", @"Begin Recording"])];
    [s addObject:PKGroup(nil, nil)];
    [s addObject:PKButton(self, @"Preview", @selector(preview))];
    _specifiers = s;
    return _specifiers;
}
- (void)preview { notify_post("com.purplesquarecube.plugin/preview"); }
@end
