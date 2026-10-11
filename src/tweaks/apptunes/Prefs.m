// AppTunes Settings pane - by purplesquarecube

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <notify.h>

// ---- Minimal declarations of the private Preferences framework ----
@interface PSSpecifier : NSObject
@property (nonatomic) SEL buttonAction;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                  target:(id)target
                                     set:(SEL)set
                                     get:(SEL)get
                                  detail:(Class)detail
                                    cell:(NSInteger)cell
                                    edit:(Class)edit;
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

// cell types
enum { ATCellGroup = 0, ATCellLink = 1, ATCellLinkList = 2, ATCellSlider = 5,
       ATCellSwitch = 6, ATCellButton = 13 };

static NSString *const kDomain   = @"com.purplesquarecube.apptunes";
static NSString *const kNotif    = @"com.purplesquarecube.apptunes/prefsChanged";
static NSString *const kSongsDir = @"/var/mobile/Library/AppTunes";

@interface AppTunesRootListController : PSListController <UIDocumentPickerDelegate>
@end

@implementation AppTunesRootListController

#pragma mark helpers

- (NSArray<NSString *> *)songFiles {
    NSArray *all = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kSongsDir error:nil] ?: @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in all) {
        if ([f hasPrefix:@"."]) continue;
        [out addObject:f];
    }
    return [out sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray<NSDictionary *> *)installedApps {
    NSMutableArray *result = [NSMutableArray array];
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    id ws = wsClass ? ((id (*)(id, SEL))objc_msgSend)(wsClass, NSSelectorFromString(@"defaultWorkspace")) : nil;
    SEL allSel = NSSelectorFromString(@"allInstalledApplications");
    if (!ws || ![ws respondsToSelector:allSel]) return result;

    NSArray *proxies = ((id (*)(id, SEL))objc_msgSend)(ws, allSel);
    NSMutableSet *seen = [NSMutableSet set];
    for (id p in proxies) {
        NSString *bid  = [p respondsToSelector:NSSelectorFromString(@"applicationIdentifier")]
            ? ((id (*)(id, SEL))objc_msgSend)(p, NSSelectorFromString(@"applicationIdentifier")) : nil;
        NSString *name = [p respondsToSelector:NSSelectorFromString(@"localizedName")]
            ? ((id (*)(id, SEL))objc_msgSend)(p, NSSelectorFromString(@"localizedName")) : nil;
        NSString *type = [p respondsToSelector:NSSelectorFromString(@"applicationType")]
            ? ((id (*)(id, SEL))objc_msgSend)(p, NSSelectorFromString(@"applicationType")) : nil;
        if (!bid.length || !name.length || [seen containsObject:bid]) continue;
        if (![type isEqualToString:@"User"] && ![type isEqualToString:@"System"]) continue;
        if ([bid isEqualToString:kDomain]) continue;

        // hide internal / hidden system apps
        SEL tagsSel = NSSelectorFromString(@"appTags");
        if ([p respondsToSelector:tagsSel]) {
            NSArray *tags = ((id (*)(id, SEL))objc_msgSend)(p, tagsSel);
            if ([tags isKindOfClass:[NSArray class]] && [tags containsObject:@"hidden"]) continue;
        }
        [seen addObject:bid];
        [result addObject:@{ @"id": bid, @"name": name }];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
}

- (UIImage *)iconForBundle:(NSString *)bid {
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![UIImage respondsToSelector:sel]) return nil;
    return ((UIImage *(*)(id, SEL, NSString *, int, CGFloat))objc_msgSend)(
        [UIImage class], sel, bid, 0, [UIScreen mainScreen].scale);
}

- (void)postChange {
    notify_post([kNotif UTF8String]);
}

- (void)showAlert:(NSString *)title message:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                               message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark specifiers

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *s = [NSMutableArray array];
    NSArray *songs = [self songFiles];
    NSString *notif = kNotif;

    // --- General ---
    PSSpecifier *g1 = [PSSpecifier groupSpecifierWithName:@"General"];
    [s addObject:g1];

    PSSpecifier *en = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:ATCellSwitch edit:nil];
    [en setProperty:kDomain forKey:@"defaults"];
    [en setProperty:@"enabled" forKey:@"key"];
    [en setProperty:@YES forKey:@"default"];
    [en setProperty:notif forKey:@"PostNotification"];
    [s addObject:en];

    PSSpecifier *loop = [PSSpecifier preferenceSpecifierNamed:@"Loop Songs" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:ATCellSwitch edit:nil];
    [loop setProperty:kDomain forKey:@"defaults"];
    [loop setProperty:@"loop" forKey:@"key"];
    [loop setProperty:@YES forKey:@"default"];
    [loop setProperty:notif forKey:@"PostNotification"];
    [s addObject:loop];

    PSSpecifier *vol = [PSSpecifier preferenceSpecifierNamed:@"Volume" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:ATCellSlider edit:nil];
    [vol setProperty:kDomain forKey:@"defaults"];
    [vol setProperty:@"volume" forKey:@"key"];
    [vol setProperty:@0.8f forKey:@"default"];
    [vol setProperty:@0.0f forKey:@"min"];
    [vol setProperty:@1.0f forKey:@"max"];
    [vol setProperty:notif forKey:@"PostNotification"];
    [s addObject:vol];

    // --- Songs ---
    PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"Songs"];
    [g2 setProperty:[NSString stringWithFormat:@"%lu song%@ imported. Audio files (MP3, M4A, WAV...) are kept in %@.",
                     (unsigned long)songs.count, songs.count == 1 ? @"" : @"s", kSongsDir]
             forKey:@"footerText"];
    [s addObject:g2];

    PSSpecifier *imp = [PSSpecifier preferenceSpecifierNamed:@"Import a Song..." target:self
        set:NULL get:NULL detail:nil cell:ATCellButton edit:nil];
    imp.buttonAction = @selector(importSong);
    [s addObject:imp];

    if (songs.count) {
        PSSpecifier *del = [PSSpecifier preferenceSpecifierNamed:@"Delete a Song..." target:self
            set:NULL get:NULL detail:nil cell:ATCellButton edit:nil];
        del.buttonAction = @selector(deleteSong);
        [s addObject:del];
    }

    // --- Apps ---
    PSSpecifier *g3 = [PSSpecifier groupSpecifierWithName:@"Apps"];
    [g3 setProperty:@"Pick a song for each app. It plays while that app is open and stops when you leave it."
             forKey:@"footerText"];
    [s addObject:g3];

    NSMutableArray *values = [NSMutableArray arrayWithObject:@""];
    NSMutableArray *titles = [NSMutableArray arrayWithObject:@"None"];
    for (NSString *f in songs) {
        [values addObject:f];
        [titles addObject:[f stringByDeletingPathExtension]];
    }

    for (NSDictionary *app in [self installedApps]) {
        PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:app[@"name"] target:self
            set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
            detail:[PSListItemsController class] cell:ATCellLinkList edit:nil];
        [sp setProperty:kDomain forKey:@"defaults"];
        [sp setProperty:[@"app." stringByAppendingString:app[@"id"]] forKey:@"key"];
        [sp setProperty:@"" forKey:@"default"];
        [sp setProperty:notif forKey:@"PostNotification"];
        [sp setProperty:app[@"name"] forKey:@"label"];
        [sp setValues:values titles:titles];
        UIImage *icon = [self iconForBundle:app[@"id"]];
        if (icon) [sp setProperty:icon forKey:@"iconImage"];
        [s addObject:sp];
    }

    _specifiers = s;
    return _specifiers;
}

#pragma mark import / delete

- (void)importSong {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.audio"]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    if (@available(iOS 11.0, *)) picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:kSongsDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *firstError = nil;
    for (NSURL *url in urls) {
        BOOL scoped = [url startAccessingSecurityScopedResource];
        NSString *name = [[url lastPathComponent] stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
        NSString *base = [name stringByDeletingPathExtension];
        NSString *ext  = [name pathExtension];
        NSString *dest = [kSongsDir stringByAppendingPathComponent:name];
        int n = 2;
        while ([fm fileExistsAtPath:dest]) {
            NSString *alt = ext.length ? [NSString stringWithFormat:@"%@ %d.%@", base, n, ext]
                                       : [NSString stringWithFormat:@"%@ %d", base, n];
            dest = [kSongsDir stringByAppendingPathComponent:alt];
            n++;
        }
        NSError *err = nil;
        if (![fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:&err] && !firstError) firstError = err.localizedDescription;
        if (scoped) [url stopAccessingSecurityScopedResource];
    }

    _specifiers = nil;
    [self reloadSpecifiers];
    [self postChange];

    if (firstError) {
        [self showAlert:@"Couldn't import" message:firstError];
    }
}

- (void)deleteSong {
    NSArray *songs = [self songFiles];
    if (!songs.count) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Delete which song?"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *f in songs) {
        [sheet addAction:[UIAlertAction actionWithTitle:[f stringByDeletingPathExtension]
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *a) {
            [[NSFileManager defaultManager] removeItemAtPath:[kSongsDir stringByAppendingPathComponent:f] error:nil];
            self->_specifiers = nil;
            [self reloadSpecifiers];
            [self postChange];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
