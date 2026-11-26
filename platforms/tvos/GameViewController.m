#import "GameViewController.h"
#import "TVOSGameBridge.h"
#import <QuartzCore/QuartzCore.h>

@interface GameViewController ()
@property (strong, nonatomic) TVOSGameView *gameView;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (assign, nonatomic) ms_game_state_t gameState;
@property (assign, nonatomic) CFTimeInterval lastTimestamp;
@end

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    ms_switches_t sw = {
        .safe_mode_fallback   = false,
        .high_contrast_hud    = true,
        .sound_enabled        = true,
        .ui_scale_percent     = 150,
        .hi_res_upscale       = true,
        .render_scale_percent = 150,
        .remaster_tier        = 2
    };
    ms_game_init(&_gameState, 1, 0, sw);

    self.gameView = [[TVOSGameView alloc] initWithFrame:self.view.bounds];
    self.gameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.gameView.gameState = &_gameState;
    [self.gameView loadPreferencesFromDefaults];
    [self.gameView applyResolutionSettings];
    [self.view addSubview:self.gameView];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onFrame:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)onFrame:(CADisplayLink *)link {
    CFTimeInterval now = link.timestamp;
    float dt = (self.lastTimestamp > 0.0) ? (float)(now - self.lastTimestamp) : (1.0f / 60.0f);
    self.lastTimestamp = now;

    uint32_t mask = [self.gameView pollCombinedInputMask];
    ms_game_step(&_gameState, mask, dt);
    [self.gameView setNeedsDisplay];
}

- (void)saveGamePreferences { [self.gameView savePreferencesToDefaults]; }

- (void)handleMemoryWarning {
    _gameState.switches.safe_mode_fallback = true;
    _gameState.switches.hi_res_upscale = false;
    ms_recalc_resolution(&_gameState);
    [self.gameView applyResolutionSettings];
}

- (void)dealloc {
    [self.displayLink invalidate];
    ms_release_stage_assets(&_gameState);
}

@end
