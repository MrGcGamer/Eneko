#import "Eneko.h"

#define isLockscreenVisible [[objc_getClass("SBCoverSheetPresentationManager") sharedInstance] isVisible]
#define isControlCenterVisible [[objc_getClass("SBControlCenterController") sharedInstance] isVisible]
#define isInCall [[objc_getClass("SBTelephonyManager") sharedTelephonyManager] inCall]

%group Main

    %hook SBFWallpaperView
    %new
    - (void)setupEneko:(NSInteger)isHome {
        NSURL* url = [GcImagePickerUtils videoURLFromDefaults:@"love.litten.enekopreferences" withKey:(isHome == 1) ? @"homescreenWallpaper" : @"lockscreenWallpaper"];
        if (!url) return;

        __block UIView *containerView = [UIView new];

        NSInteger blurMode = (isHome == 1) ? homescreenBlurModeValue : lockscreenBlurModeValue;
        CGFloat blurValue = (isHome == 1) ? homescreenBlurAmountValue : lockscreenBlurAmountValue;
        CGFloat dimValue = (isHome == 1) ? homescreenDimValue : lockscreenDimValue;

        // UIView * (^setupBlur)(__strong UIView **) = ^UIView *(__strong UIView **destination) {
        UIView * (^setupBlur)() = ^UIView *() {
            if (blurValue == 0.0 && dimValue == 0.0) return nil;

            // dim and blur superview
            __strong UIView *dest = [UIView new];
            [containerView addSubview:dest];
            [dest anchorEqualsToView:containerView];

            // blur
            if (blurValue != 0.0) {
                UIBlurEffect *blur = [UIBlurEffect effectWithStyle:((blurMode) ? UIBlurEffectStyleDark : UIBlurEffectStyleLight)];

                UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
                [dest addSubview:blurView];
                [blurView anchorEqualsToView:dest];
                [blurView setAlpha:blurValue];
            }

            // dim
            if (dimValue != 0.0) {
                UIView* dimView = [UIView new];
                [dest addSubview:dimView];
                [dimView anchorEqualsToView:dest];
                [dimView setBackgroundColor:[UIColor blackColor]];
                [dimView setAlpha:dimValue];
            }

            return dest;

        };

        [self.contentView addSubview:containerView];
        [containerView anchorCenterX:[self.contentView centerXAnchor] centerY:[self.contentView centerYAnchor] size:(CGSize){[UIScreen mainScreen].bounds.size.width*1.15,[UIScreen mainScreen].bounds.size.height*1.15}];

        __block AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:url];

        CGFloat volume = (isHome == 1) ? homescreenVolumeValue : lockscreenVolumeValue;
        CGFloat opacity = (isHome == 1) ? homescreenOpacityValue : lockscreenOpacityValue;

        typedef void (^SetupPlayer)(__strong AVQueuePlayer **, __strong AVPlayerLooper **, __strong AVPlayerLayer **);

        SetupPlayer setupPlayer = ^void (__strong AVQueuePlayer **player, __strong AVPlayerLooper **looper, __strong AVPlayerLayer **layer) {

            *player = [AVQueuePlayer playerWithPlayerItem:playerItem];
            [*player setPreventsDisplaySleepDuringVideoPlayback:NO];
            if (volume == 0.0) [playerHS setMuted:YES];
            else [*player setVolume:volume];
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];

            *looper = [AVPlayerLooper playerLooperWithPlayer:*player templateItem:playerItem];

            *layer = [AVPlayerLayer playerLayerWithPlayer:*player];
            [*layer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            [*layer setFrame:(CGRect){{0,0},{[UIScreen mainScreen].bounds.size.width*1.15,[UIScreen mainScreen].bounds.size.height*1.15}}];
            [*layer setOpacity:opacity];
            [[containerView layer] insertSublayer:*layer atIndex:0];

        };

        if (isHome == 1) {
            setupPlayer(&playerHS, &playerLooperHS, &playerLayerHS);
            dimBlurViewHS = setupBlur();
        } else if (isHome == 2) {
            LSContainerView = containerView;
            setupPlayer(&playerLS, &playerLooperLS, &playerLayerLS);
            dimBlurViewLS = setupBlur();
        } else if (isHome == 0) { // shared / FakeLS
            setupBlur();
        }

        [self addObserver:self forKeyPath:@"hidden" options:NSKeyValueObservingOptionNew context:NULL];

    }
    %new
    - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
      if (![keyPath isEqualToString:@"hidden"]) return;

      BOOL hidden = [(NSString *)[change valueForKey:NSKeyValueChangeNewKey] boolValue];
      BOOL isHome = (self.contentView.subviews[0].layer.sublayers[0] == playerLayerHS);

      AVQueuePlayer *player = (isHome) ? playerHS : playerLS;
      player.rate = !hidden;

    }
    %end

    %hook SBWallpaperViewController
    - (void)viewDidLoad {
        %orig;
        if (self.sharedWallpaperView) { // we got a problem siir
            // Yaw
        } else {
            if (enableHomescreenWallpaperSwitch)
                [self.homescreenWallpaperView setupEneko:1];
            if (enableLockscreenWallpaperSwitch)
                [self.lockscreenWallpaperView setupEneko:2];
        }

    }
    %end

    %hook SBCoverSheetPrimarySlidingViewController
    -(void)_createPanelWallpaperEffectViewIfNeeded {
        %orig;
        if (!enableLockscreenWallpaperSwitch) return;
        [self.panelWallpaperEffectView addObserver:self forKeyPath:@"hidden" options:NSKeyValueObservingOptionNew context:NULL];
        [[self.panelWallpaperEffectView.blurView valueForKey:@"_wallpaperView"] setupEneko:0];
    }
    %new
    - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
        if (![keyPath isEqualToString:@"hidden"]) return;

        BOOL hidden = [(NSString *)[change valueForKey:NSKeyValueChangeNewKey] boolValue];
        SBFWallpaperView *wpView = (SBFWallpaperView *)[self.panelWallpaperEffectView.blurView valueForKey:@"_wallpaperView"];
        if (!hidden) {
            UIView *containerView;
            if (wpView.contentView.subviews && (containerView = wpView.contentView.subviews[0])) {
                [containerView.layer insertSublayer:playerLayerLS atIndex:0];
                playerLS.rate = 1;
            }
        } else {
            [LSContainerView.layer insertSublayer:playerLayerLS atIndex:0];
            playerLS.rate = [[objc_getClass("SBCoverSheetPresentationManager") sharedInstance] isVisible];
        }

    }
    %end

    %hook CSCoverSheetView
    - (void)_layoutWallpaperEffectView {
        NO;
    }
    %end

    %hook CCUIModularControlCenterOverlayViewController
    BOOL HSPrev, LSPrev;
    - (void)viewWillAppear:(BOOL)animated {
        %orig;

        if (enableHomescreenWallpaperSwitch) {
            HSPrev = playerHS;
            playerHS.rate = 0;
        }

        if (enableLockscreenWallpaperSwitch) {
            LSPrev = playerLS;
            playerLS.rate = 0;
        }

    }

    - (void)viewWillDisappear:(BOOL)animated {
        %orig;

        if (playerHS && enableHomescreenWallpaperSwitch)
            playerHS.rate = HSPrev;
        if (playerLS && enableLockscreenWallpaperSwitch)
            playerLS.rate = LSPrev;
    }
    %end

%end

%group ControlCenter

    %hook CCUIModularControlCenterOverlayViewController
    - (void)viewDidLoad { // add player to the control center
        %orig;

        NSURL* url = [GcImagePickerUtils videoURLFromDefaults:@"love.litten.enekopreferences" withKey:@"controlCenterWallpaper"];
        if (!url) return;

        AVPlayerItem* playerItem = [AVPlayerItem playerItemWithURL:url];

        playerCC = [AVQueuePlayer playerWithPlayerItem:playerItem];
        [playerCC setPreventsDisplaySleepDuringVideoPlayback:NO];
        if (controlCenterVolumeValue == 0.0) [playerCC setMuted:YES];
        else [playerCC setVolume:controlCenterVolumeValue];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];

        playerLooperCC = [AVPlayerLooper playerLooperWithPlayer:playerCC templateItem:playerItem];

        playerLayerCC = [AVPlayerLayer playerLayerWithPlayer:playerCC];
        [playerLayerCC setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        [playerLayerCC setFrame:[[[self view] layer] bounds]];
        [playerLayerCC setOpacity:controlCenterOpacityValue];
        [[[self view] layer] insertSublayer:playerLayerCC atIndex:1];


        // dim and blur superview
        if (controlCenterBlurAmountValue != 0.0 || controlCenterDimValue != 0.0) {
            dimBlurViewCC = [UIView new];
            [[self view] insertSubview:dimBlurViewCC atIndex:2];
            [dimBlurViewCC anchorEqualsToView:[self view]];

            // blur
            if (controlCenterBlurAmountValue != 0.0) {
                UIBlurEffect *blur = [UIBlurEffect effectWithStyle:((controlCenterBlurModeValue) ? UIBlurEffectStyleDark : UIBlurEffectStyleLight)];

                UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
                [dimBlurViewCC addSubview:blurView];
                [blurView anchorEqualsToView:dimBlurViewCC];
                [blurView setAlpha:controlCenterBlurAmountValue];
            }

            // dim
            if (controlCenterDimValue != 0.0) {
                UIView* dimView = [UIView new];
                [dimBlurViewCC addSubview:dimView];
                [dimView anchorEqualsToView:dimBlurViewCC];
                [dimView setBackgroundColor:[UIColor blackColor]];
                [dimView setAlpha:controlCenterDimValue];
            }
        }

    }

    - (void)viewWillAppear:(BOOL)animated {
        %orig;

        MTMaterialView *backgroundView = [self overlayBackgroundView];

        [backgroundView addObserver:self forKeyPath:@"weighting" options:NSKeyValueObservingOptionNew context:NULL];

        if (playerCC && enableControlCenterWallpaperSwitch)
            playerCC.rate = 1;

    }

    - (void)viewWillDisappear:(BOOL)animated {
        %orig;

        MTMaterialView *backgroundView = [self overlayBackgroundView];

        if ([backgroundView observationInfo])
            [backgroundView removeObserver:self forKeyPath:@"weighting"];

        if (playerCC && enableControlCenterWallpaperSwitch)
            playerCC.rate = 0;
    }
    %new
    - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
        if (![keyPath isEqualToString:@"weighting"]) return;

        CGFloat weighting = [(NSString *)[change valueForKey:NSKeyValueChangeNewKey] doubleValue];

        playerLayerCC.opacity = weighting;

    }
    %end

%end

%group Eneko

    %hook SBBacklightController
    - (void)turnOnScreenFullyWithBacklightSource:(long long)arg1 { // play when screen turned on
        %orig;

        screenIsOn = YES;
        if (!isLockscreenVisible) return;
        if ((hideWhenLowPowerSwitch && isOnLowPower) || isInCall) return;
        if (enableLockscreenWallpaperSwitch) [playerLS play];
        if (enableHomescreenWallpaperSwitch) [playerHS pause];
        if (enableControlCenterWallpaperSwitch) [playerCC pause];

    }
    %end

    %hook SBLockScreenManager
    - (void)lockUIFromSource:(int)arg1 withOptions:(id)arg2 { // pause all players when locked
        %orig;

        screenIsOn = NO;
        if (enableLockscreenWallpaperSwitch) [playerLS pause];
        if (enableHomescreenWallpaperSwitch) [playerHS pause];
        if (enableControlCenterWallpaperSwitch) [playerCC pause];

    }
    %end

    %hook SBMediaController
    - (BOOL)isPlaying { // mute players when music is playing

        if (lockscreenVolumeValue == 0.0 && homescreenVolumeValue == 0.0 && controlCenterVolumeValue == 0.0) return %orig;

        BOOL orig = %orig;

        if (orig) {
            if (enableLockscreenWallpaperSwitch && lockscreenVolumeValue != 0.0 && muteWhenMusicPlaysSwitch) [playerLS setVolume:0.0];
            if (enableHomescreenWallpaperSwitch && homescreenVolumeValue != 0.0 && muteWhenMusicPlaysSwitch) [playerHS setVolume:0.0];
            if (enableControlCenterWallpaperSwitch && controlCenterVolumeValue != 0.0 && muteWhenMusicPlaysSwitch) [playerCC setVolume:0.0];
        } else {
            if (enableLockscreenWallpaperSwitch && lockscreenVolumeValue != 0.0 && muteWhenMusicPlaysSwitch) [playerLS setVolume:lockscreenVolumeValue];
            if (enableHomescreenWallpaperSwitch && homescreenVolumeValue != 0.0 && muteWhenMusicPlaysSwitch) [playerHS setVolume:homescreenVolumeValue];
            if (enableControlCenterWallpaperSwitch && controlCenterVolumeValue != 0.0 && muteWhenMusicPlaysSwitch) [playerCC setVolume:controlCenterVolumeValue];
        }

        return orig;

    }
    %end

    %hook TUCall
    - (int)status { // pause when user is getting a call and play when the call ends
        if (hideWhenLowPowerSwitch && isOnLowPower) return %orig;

        int orig = %orig;

        if (orig != 6) {
            if (enableLockscreenWallpaperSwitch) [playerLS pause];
            if (enableHomescreenWallpaperSwitch) [playerHS pause];
            if (enableControlCenterWallpaperSwitch) [playerCC pause];
        } else if (orig == 6) {
            if (isLockscreenVisible) {
                if (enableLockscreenWallpaperSwitch && screenIsOn) [playerLS play];
                if (enableHomescreenWallpaperSwitch) [playerHS pause];
            } else if (!isLockscreenVisible) {
                if (enableHomescreenWallpaperSwitch) [playerHS play];
                if (enableLockscreenWallpaperSwitch) [playerLS pause];
            }
            [playerCC pause];
        }

        return orig;

    }
    %end

    %hook SiriUIBackgroundBlurView
    - (void)removeFromSuperview { // play when siri was dismissed (ios 14)
        %orig;

        if ((hideWhenLowPowerSwitch && isOnLowPower) || isInCall) return;

        if (enableLockscreenWallpaperSwitch && isLockscreenVisible) [playerLS play];
        else if (enableHomescreenWallpaperSwitch && !isLockscreenVisible) [playerHS play];
        [playerCC pause];

    }
    %end

    %hook SiriUISiriStatusView
    - (void)removeFromSuperview { // play when siri was dismissed (ios 13)
        %orig;

        if ((hideWhenLowPowerSwitch && isOnLowPower) || isInCall) return;

        if (enableLockscreenWallpaperSwitch && isLockscreenVisible) [playerLS play];
        else if (enableHomescreenWallpaperSwitch && !isLockscreenVisible) [playerHS play];
        [playerCC pause];

    }
    %end

    %hook SBDashBoardCameraPageViewController
    - (void)viewWillAppear:(BOOL)animated { // pause when lockscreen camera appears
        %orig;

        if ((hideWhenLowPowerSwitch && isOnLowPower) || isInCall) return;
        if (enableLockscreenWallpaperSwitch && isLockscreenVisible) [playerLS pause];

    }

    - (void)viewWillDisappear:(BOOL)animated { // play when lockscreen camera disappears
        %orig;

        if ((hideWhenLowPowerSwitch && isOnLowPower) || isInCall) return;
        if (enableLockscreenWallpaperSwitch && isLockscreenVisible) [playerLS play];

    }
    %end

    %hook CSModalButton
    - (void)didMoveToWindow { // pause when alarm/timer fires
        %orig;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (enableLockscreenWallpaperSwitch) [playerLS pause];
            if (enableHomescreenWallpaperSwitch) [playerHS pause];
            if (enableControlCenterWallpaperSwitch) [playerCC pause];
        });

    }

    - (void)removeFromSuperview { // pause when alarm/timer was dismissed
        %orig;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (enableLockscreenWallpaperSwitch && screenIsOn) [playerLS play];
            if (enableHomescreenWallpaperSwitch) [playerHS pause];
            if (enableControlCenterWallpaperSwitch) [playerCC pause];
        });

    }
    %end

    %hook SBLockScreenEmergencyCallViewController
    - (void)viewWillAppear:(BOOL)animated { // pause when emergency call pad appears
        %orig;

        if (enableLockscreenWallpaperSwitch) [playerLS pause];

    }

    - (void)viewWillDisappear:(BOOL)animated { // play when emergency call pad disappears
        %orig;

        if ((hideWhenLowPowerSwitch && isOnLowPower) || isInCall) return;
        if (enableLockscreenWallpaperSwitch) [playerLS play];

    }
    %end

    %hook NSProcessInfo
    - (BOOL)isLowPowerModeEnabled { // hide when low power mode is enabled
        if (!hideWhenLowPowerSwitch) return %orig;

        if (!supportsLowPowerMode) {
            isOnLowPower = NO;
            return %orig;
        }

        isOnLowPower = %orig;

        if (isOnLowPower) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (enableLockscreenWallpaperSwitch) {
                    [playerLayerLS setHidden:YES];
                    if (dimBlurViewLS) [dimBlurViewLS setHidden:YES];
                    [playerLS pause];
                }
                if (enableHomescreenWallpaperSwitch) {
                    [playerLayerHS setHidden:YES];
                    if (dimBlurViewHS) [dimBlurViewHS setHidden:YES];
                    [playerHS pause];
                }
                if (enableControlCenterWallpaperSwitch) {
                    [playerLayerCC setHidden:YES];
                    if (dimBlurViewCC) [dimBlurViewCC setHidden:YES];
                    [playerCC pause];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (enableLockscreenWallpaperSwitch && isLockscreenVisible && !isControlCenterVisible) [playerLS play];
                else if (enableHomescreenWallpaperSwitch && !isLockscreenVisible && !isControlCenterVisible) [playerHS play];
                else if (enableControlCenterWallpaperSwitch && isControlCenterVisible) [playerCC play];
                [playerLayerLS setHidden:NO];
                [playerLayerHS setHidden:NO];
                [playerLayerCC setHidden:NO];
                if (dimBlurViewLS) [dimBlurViewLS setHidden:NO];
                if (dimBlurViewHS) [dimBlurViewHS setHidden:NO];
                if (dimBlurViewCC) [dimBlurViewCC setHidden:NO];
            });
        }

        return isOnLowPower;

    }
    %end

%end

%ctor {

    preferences = [[HBPreferences alloc] initWithIdentifier:@"love.litten.enekopreferences"];

    if (![preferences boolForKey:@"Enabled" default:NO]) return;

    // lockscreen
    [preferences registerBool:&enableLockscreenWallpaperSwitch default:NO forKey:@"enableLockscreenWallpaper"];
    if (enableLockscreenWallpaperSwitch) {
        [preferences registerFloat:&lockscreenVolumeValue default:0.0 forKey:@"lockscreenVolume"];
        [preferences registerFloat:&lockscreenBlurAmountValue default:0.0 forKey:@"lockscreenBlurAmount"];
        [preferences registerInteger:&lockscreenBlurModeValue default:0 forKey:@"lockscreenBlurMode"];
        [preferences registerFloat:&lockscreenDimValue default:0.0 forKey:@"lockscreenDim"];
        [preferences registerFloat:&lockscreenOpacityValue default:1.0 forKey:@"lockscreenOpacity"];
    }

    // homescreen
    [preferences registerBool:&enableHomescreenWallpaperSwitch default:NO forKey:@"enableHomescreenWallpaper"];
    if (enableHomescreenWallpaperSwitch) {
        [preferences registerFloat:&homescreenVolumeValue default:0.0 forKey:@"homescreenVolume"];
        [preferences registerFloat:&homescreenBlurAmountValue default:0.0 forKey:@"homescreenBlurAmount"];
        [preferences registerInteger:&homescreenBlurModeValue default:0 forKey:@"homescreenBlurMode"];
        [preferences registerFloat:&homescreenDimValue default:0.0 forKey:@"homescreenDim"];
        [preferences registerFloat:&homescreenOpacityValue default:1.0 forKey:@"homescreenOpacity"];
    }

    // control center
    [preferences registerBool:&enableControlCenterWallpaperSwitch default:NO forKey:@"enableControlCenterWallpaper"];
    if (enableControlCenterWallpaperSwitch) {
        [preferences registerFloat:&controlCenterVolumeValue default:0.0 forKey:@"controlCenterVolume"];
        [preferences registerFloat:&controlCenterBlurAmountValue default:0.0 forKey:@"controlCenterBlurAmount"];
        [preferences registerInteger:&controlCenterBlurModeValue default:0 forKey:@"controlCenterBlurMode"];
        [preferences registerFloat:&controlCenterDimValue default:0.0 forKey:@"controlCenterDim"];
        [preferences registerFloat:&controlCenterOpacityValue default:1.0 forKey:@"controlCenterOpacity"];
    }

    // miscellaneous
    [preferences registerBool:&muteWhenMusicPlaysSwitch default:YES forKey:@"muteWhenMusicPlays"];
    [preferences registerBool:&hideWhenLowPowerSwitch default:YES forKey:@"hideWhenLowPower"];

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if ([deviceModel containsString:@"iPhone"]) supportsLowPowerMode = YES;

    if (enableLockscreenWallpaperSwitch || enableHomescreenWallpaperSwitch) %init(Main);
    if (enableControlCenterWallpaperSwitch) %init(ControlCenter);
    if (enableLockscreenWallpaperSwitch || enableHomescreenWallpaperSwitch || enableControlCenterWallpaperSwitch) %init(Eneko);

}