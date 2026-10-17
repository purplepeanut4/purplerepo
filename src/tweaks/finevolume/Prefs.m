// FineVolume Settings pane - by purplesquarecube
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.finevolume";
static NSString *const kNotif  = @"com.purplesquarecube.finevolume/prefsChanged";

@interface FineVolumeRootListController : PSListController
@end

@implementation FineVolumeRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"FineVolume", @"Each press of a volume button changes the volume by a smaller amount. 100% is the normal step; 25% gives you four times as many steps.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Step Size", nil)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Step", @"step", 0.5, 0.1, 1.0)];
    _specifiers = s;
    return _specifiers;
}
@end
