// Shared helpers for purplesquarecube tweaks (SpringBoard side)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>

static inline id PKPref(NSString *domain, NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                       (__bridge CFStringRef)domain));
}
static inline BOOL PKBool(NSString *domain, NSString *key, BOOL def) {
    id v = PKPref(domain, key); return v ? [v boolValue] : def;
}
static inline double PKDouble(NSString *domain, NSString *key, double def) {
    id v = PKPref(domain, key); return v ? [v doubleValue] : def;
}
static inline NSInteger PKInt(NSString *domain, NSString *key, NSInteger def) {
    id v = PKPref(domain, key); return v ? [v integerValue] : def;
}
static inline void PKSync(NSString *domain) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
}

// Override an instance method on `cls` without touching a superclass's implementation.
static inline BOOL PKHook(const char *clsName, SEL sel, IMP newImp, IMP *orig) {
    Class cls = objc_getClass(clsName);
    if (!cls) { NSLog(@"[purplesquarecube] class %s not found", clsName); return NO; }
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { NSLog(@"[purplesquarecube] %s missing %s", clsName, sel_getName(sel)); return NO; }
    IMP o = method_getImplementation(m);
    if (!class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) {
        o = method_setImplementation(m, newImp);
    }
    *orig = o;
    return YES;
}

// Same, for class (+) methods.
static inline BOOL PKHookClassMethod(const char *clsName, SEL sel, IMP newImp, IMP *orig) {
    Class meta = objc_getMetaClass(clsName);
    if (!meta) return NO;
    Method m = class_getClassMethod(objc_getClass(clsName), sel);
    if (!m) return NO;
    IMP o = method_getImplementation(m);
    if (!class_addMethod(meta, sel, newImp, method_getTypeEncoding(m))) {
        o = method_setImplementation(m, newImp);
    }
    *orig = o;
    return YES;
}

static inline id PKIvar(id obj, NSString *name) {
    @try { return [obj valueForKey:name]; } @catch (NSException *e) { return nil; }
}

static inline void PKWalk(UIView *v, void (^block)(UIView *)) {
    block(v);
    for (UIView *s in [v.subviews copy]) PKWalk(s, block);
}

static inline void PKWalkAllWindows(void (^block)(UIView *)) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) PKWalk(w, block);
}

static inline void PKOnNotify(const char *name, void (^handler)(void)) {
    int tok;
    notify_register_dispatch(name, &tok, dispatch_get_main_queue(), ^(int t) { handler(); });
}

// A small pill-shaped notice at the top of the screen, above everything.
static inline void PKShowPill(NSString *text, UIColor *ring, NSTimeInterval seconds) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static UIWindow *win = nil;
        [win setHidden:YES];
        CGRect b = [UIScreen mainScreen].bounds;
        UILabel *l = [UILabel new];
        l.text = text; l.textColor = [UIColor whiteColor];
        l.font = [UIFont boldSystemFontOfSize:14];
        l.numberOfLines = 2; l.textAlignment = NSTextAlignmentCenter;
        CGSize sz = [l sizeThatFits:CGSizeMake(b.size.width - 90, 120)];
        CGFloat w = MIN(b.size.width - 24, sz.width + 40), h = sz.height + 22;
        win = [[UIWindow alloc] initWithFrame:CGRectMake((b.size.width - w) / 2, 34, w, h)];
        win.windowLevel = 1000060;
        win.userInteractionEnabled = NO;
        win.backgroundColor = [UIColor clearColor];
        UIView *pill = [[UIView alloc] initWithFrame:win.bounds];
        pill.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.95];
        pill.layer.cornerRadius = MIN(h / 2, 24);
        pill.layer.borderWidth = 1.5;
        pill.layer.borderColor = ring.CGColor;
        l.frame = CGRectInset(pill.bounds, 18, 11);
        [pill addSubview:l];
        [win addSubview:pill];
        win.alpha = 0;
        win.hidden = NO;
        pill.transform = CGAffineTransformMakeTranslation(0, -18);
        UIWindow *mine = win;
        [UIView animateWithDuration:0.28 animations:^{ mine.alpha = 1; pill.transform = CGAffineTransformIdentity; }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{ mine.alpha = 0; }
                             completion:^(BOOL f) { if (mine == win) { mine.hidden = YES; } }];
        });
    });
}
