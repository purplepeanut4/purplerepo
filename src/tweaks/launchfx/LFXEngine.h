// LaunchFX animation engine - by purplesquarecube
// Shared by the SpringBoard tweak and the Settings preview.
#import <UIKit/UIKit.h>

#define LFX_COUNT 50

#ifdef __cplusplus
extern "C" {
#endif

// The 50 animation names, in order (index 0...49)
NSArray<NSString *> *LFXAnimationNames(void);

// "RRGGBB" -> UIColor (falls back to purple)
UIColor *LFXColorFromHex(NSString *hex);

// Cover the screen, wait `hold` seconds, then reveal over `duration` seconds.
// `origin` is where the effect grows from (the tapped icon), in screen points.
void LFXPlay(NSInteger index, UIColor *color, CGPoint origin,
             CFTimeInterval hold, CFTimeInterval duration, void (^completion)(void));

// Stop anything currently playing and remove the overlay.
void LFXCancel(void);

#ifdef __cplusplus
}
#endif
