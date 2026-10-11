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
