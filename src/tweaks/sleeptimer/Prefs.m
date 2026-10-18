// SleepTimer Settings pane - by purplepeanut4
#import "PKPrefs.h"

static NSString *const kDomain = @"com.purplesquarecube.sleeptimer";

@interface SleepTimerRootListController : PSListController
@end

@implementation SleepTimerRootListController

- (NSString *)status {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    id end = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("endsAt"), (__bridge CFStringRef)kDomain));
    if (end && [end doubleValue] > [[NSDate date] timeIntervalSince1970]) {
        NSDateFormatter *f = [NSDateFormatter new];
        f.timeStyle = NSDateFormatterShortStyle;
        f.dateStyle = NSDateFormatterNoStyle;
        return [NSString stringWithFormat:@"Timer running. Playback stops at %@.",
                [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[end doubleValue]]]];
    }
    return @"Pick a time and tap Start. Music and videos pause when it ends.";
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"Sleep Timer", [self status])];
    NSArray *mins = @[@5, @10, @15, @20, @30, @45, @60, @90, @120];
    NSMutableArray *titles = [NSMutableArray array];
    for (NSNumber *m in mins) {
        int v = m.intValue;
        [titles addObject:v >= 60 && v % 60 == 0 ? [NSString stringWithFormat:@"%d hour%@", v / 60, v == 60 ? @"" : @"s"]
                                                 : [NSString stringWithFormat:@"%d minutes", v]];
    }
    [s addObject:PKList(self, kDomain, nil, @"Stop After", @"minutes", @30, mins, titles)];
    [s addObject:PKSwitch(self, kDomain, nil, @"Lock the Device When It Ends", @"lock", YES)];
    [s addObject:PKGroup(nil, nil)];
    [s addObject:PKButton(self, @"Start Timer", @selector(startTimer))];
    [s addObject:PKButton(self, @"Cancel Timer", @selector(cancelTimer))];
    _specifiers = s;
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)refreshSoon {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_specifiers = nil;
        [self reloadSpecifiers];
    });
}
- (void)startTimer  { notify_post("com.purplesquarecube.sleeptimer/start");  [self refreshSoon]; }
- (void)cancelTimer { notify_post("com.purplesquarecube.sleeptimer/cancel"); [self refreshSoon]; }
@end
