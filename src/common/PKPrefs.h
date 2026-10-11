// Shared helpers for purplesquarecube Settings panes
#import <UIKit/UIKit.h>
#import <notify.h>
#import <spawn.h>

@interface PSSpecifier : NSObject
@property (nonatomic) SEL buttonAction;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get
                                  detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@interface PSListController : UIViewController {
    NSMutableArray *_specifiers;
}
- (NSArray *)specifiers;
- (void)reloadSpecifiers;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end

@interface PSListItemsController : PSListController
@end

enum { PKCellLinkList = 2, PKCellSlider = 5, PKCellSwitch = 6, PKCellButton = 13 };

static inline PSSpecifier *PKGroup(NSString *name, NSString *footer) {
    PSSpecifier *g = [PSSpecifier groupSpecifierWithName:name];
    if (footer) [g setProperty:footer forKey:@"footerText"];
    return g;
}

static inline PSSpecifier *PKSwitch(id target, NSString *domain, NSString *notif,
                                    NSString *name, NSString *key, BOOL def) {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:target
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:PKCellSwitch edit:nil];
    [s setProperty:domain forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:@(def) forKey:@"default"];
    if (notif) [s setProperty:notif forKey:@"PostNotification"];
    return s;
}

static inline PSSpecifier *PKSlider(id target, NSString *domain, NSString *notif,
                                    NSString *name, NSString *key, double def, double mn, double mx) {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:target
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:PKCellSlider edit:nil];
    [s setProperty:domain forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:@(def) forKey:@"default"];
    [s setProperty:@(mn) forKey:@"min"];
    [s setProperty:@(mx) forKey:@"max"];
    [s setProperty:@YES forKey:@"showValue"];
    if (notif) [s setProperty:notif forKey:@"PostNotification"];
    return s;
}

static inline PSSpecifier *PKList(id target, NSString *domain, NSString *notif, NSString *name,
                                  NSString *key, id def, NSArray *values, NSArray *titles) {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:target
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:[PSListItemsController class] cell:PKCellLinkList edit:nil];
    [s setProperty:domain forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:def forKey:@"default"];
    [s setProperty:name forKey:@"label"];
    if (notif) [s setProperty:notif forKey:@"PostNotification"];
    [s setValues:values titles:titles];
    return s;
}

static inline PSSpecifier *PKButton(id target, NSString *name, SEL action) {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:target
        set:NULL get:NULL detail:nil cell:PKCellButton edit:nil];
    s.buttonAction = action;
    return s;
}
