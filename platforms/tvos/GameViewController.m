#import "GameViewController.h"
#import "TVOSGameBridge.h"
#import "MSSprite.h"
#import "MSAudio.h"
#import "MSLog.h"
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
    [MSLog start];
    [MSLog info:MSLogCatApp fmt:@"게임 시작 — 로그 %@", MSLog.logPath];
    [[MSSpriteStore shared] preloadAndAudit];
    [[MSAudio shared] start];

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

    [MSLog info:MSLogCatGame fmt:@"스테이지 %d 시작 hp=%d 수류탄=%d 지면=%.0f 세계폭=%.0f",
          _gameState.stage_index, _gameState.player.hp, _gameState.player.grenade_count,
          (double)MS_GROUND_Y, (double)MS_WORLD_WIDTH];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onFrame:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)onFrame:(CADisplayLink *)link {
    CFTimeInterval now = link.timestamp;
    float dt = (self.lastTimestamp > 0.0) ? (float)(now - self.lastTimestamp) : (1.0f / 60.0f);
    self.lastTimestamp = now;

    uint32_t mask = [self.gameView pollCombinedInputMask];
    BOOL wasOver = _gameState.game_over;
    ms_game_step(&_gameState, mask, dt);

    [[MSAudio shared] playEvents:_gameState.sfx_events
                         enabled:_gameState.switches.sound_enabled];

    if (!wasOver && _gameState.game_over) {
        [MSLog info:MSLogCatGame fmt:@"게임 오버 score=%d best=%d tick=%u",
              _gameState.score, _gameState.best_score, _gameState.tick_count];
        [self saveGamePreferences];
    }

    [self.gameView setNeedsDisplay];
}

- (void)saveGamePreferences { [self.gameView savePreferencesToDefaults]; }

- (void)handleMemoryWarning {
    [MSLog warn:MSLogCatApp fmt:@"메모리 경고 — 안전 모드로 내린다 (현재 %zuMB 추정)",
          _gameState.approx_mem_bytes / (1024 * 1024)];
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
