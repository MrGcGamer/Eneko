#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <GcUniversal/GcImagePickerUtils.h>
#import <GcUniversal/HelperFunctions.h>
#import <Cephei/HBPreferences.h>

HBPreferences* preferences = nil;

BOOL screenIsOn = YES;
BOOL isOnLowPower = NO;
BOOL supportsLowPowerMode = NO;

AVQueuePlayer* playerLS = nil;
AVPlayerLooper* playerLooperLS = nil;
AVPlayerLayer* playerLayerLS = nil;
UIView* dimBlurViewLS = nil;

UIView *LSContainerView = nil;

AVQueuePlayer* playerHS = nil;
AVPlayerLooper* playerLooperHS = nil;
AVPlayerLayer* playerLayerHS = nil;
UIView* dimBlurViewHS = nil;

AVQueuePlayer* playerCC = nil;
AVPlayerLooper* playerLooperCC = nil;
AVPlayerLayer* playerLayerCC = nil;
UIView* dimBlurViewCC = nil;

// lockscreen
BOOL enableLockscreenWallpaperSwitch = NO;
CGFloat lockscreenVolumeValue = 0.0;
CGFloat lockscreenBlurAmountValue = 0.0;
NSInteger lockscreenBlurModeValue = 0;
CGFloat lockscreenDimValue = 0.0;
CGFloat lockscreenOpacityValue = 1.0;

// homescreen
BOOL enableHomescreenWallpaperSwitch = NO;
CGFloat homescreenVolumeValue = 0.0;
CGFloat homescreenBlurAmountValue = 0.0;
NSInteger homescreenBlurModeValue = 0;
CGFloat homescreenDimValue = 0.0;
CGFloat homescreenOpacityValue = 1.0;

// control center
BOOL enableControlCenterWallpaperSwitch = NO;
CGFloat controlCenterVolumeValue = 0.0;
CGFloat controlCenterBlurAmountValue = 0.0;
NSInteger controlCenterBlurModeValue = 0;
CGFloat controlCenterDimValue = 0.0;
CGFloat controlCenterOpacityValue = 1.0;

// miscellaneous
BOOL muteWhenMusicPlaysSwitch = YES;
BOOL hideWhenLowPowerSwitch = YES;

@interface MTMaterialView : UIView
@property (nonatomic, assign) CGFloat weighting;
@end

@interface CCUIModularControlCenterOverlayViewController : UIViewController
@property (nonatomic,readonly) MTMaterialView * overlayBackgroundView;
@end

@interface SBFWallpaperView : UIView
@property (retain, nonatomic) UIView *contentView; // ivar: _contentView

// NEW
- (void)setupEneko:(NSInteger)isHome ;
@end

@interface SBWallpaperViewController : UIViewController
@property (retain, nonatomic) SBFWallpaperView *homescreenWallpaperView; // ivar: _homescreenWallpaperView
@property (retain, nonatomic) SBFWallpaperView *lockscreenWallpaperView; // ivar: _lockscreenWallpaperView
@property (retain, nonatomic) SBFWallpaperView *sharedWallpaperView; // ivar: _sharedWallpaperView
@end

@interface SBWallpaperEffectViewBase : UIView
@property (nonatomic,retain) UIView*/*<_SBFakeBlur>*/ blurView;
@end

@interface SBWallpaperEffectView : SBWallpaperEffectViewBase
@end

@interface SBCoverSheetPrimarySlidingViewController : UIViewController
@property (nonatomic,retain) SBWallpaperEffectView * panelWallpaperEffectView;
@end

@interface SBCoverSheetPresentationManager : NSObject
+(id)sharedInstance;
-(BOOL)isVisible;
@end

@interface SBControlCenterController : NSObject
+(id)sharedInstance;
-(BOOL)isVisible;
@end

@interface SBTelephonyManager : NSObject
+(id)sharedTelephonyManager;
-(BOOL)inCall;
@end