#import "MSAudio.h"
#import "MSLog.h"
#import <AVFoundation/AVFoundation.h>

/// 한 소리를 몇 개까지 겹쳐 낼지. 연사 때 소리가 끊기지 않게 한다.
static const NSInteger kVoicesPerSound = 4;

@interface MSAudio ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<AVAudioPlayer *> *> *pools;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *cursors;
@property (nonatomic, assign) BOOL ready;
@end

@implementation MSAudio

+ (instancetype)shared {
    static MSAudio *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[MSAudio alloc] init]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _pools = [NSMutableDictionary dictionary];
        _cursors = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)start {
    if (self.ready) return;

    NSError *err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if (![session setCategory:AVAudioSessionCategoryAmbient
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&err]) {
        [MSLog error:@"audio" nsError:err context:@"오디오 세션 카테고리 설정"];
    }
    if (![session setActive:YES error:&err]) {
        [MSLog error:@"audio" nsError:err context:@"오디오 세션 활성화"];
    }

    NSArray<NSString *> *names = @[@"shoot", @"grenade", @"explosion", @"jump",
                                   @"hit", @"pickup", @"slug", @"gameover"];
    NSInteger ok = 0, bad = 0;
    for (NSString *name in names) {
        NSString *path = [[NSBundle mainBundle].resourcePath
                          stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"assets/sfx/%@.wav", name]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [MSLog error:@"audio" domain:@"MSAudio" code:404
                     msg:[NSString stringWithFormat:@"효과음 파일이 없다 %@", path]];
            bad++;
            continue;
        }
        NSMutableArray *pool = [NSMutableArray array];
        for (NSInteger i = 0; i < kVoicesPerSound; i++) {
            NSError *perr = nil;
            AVAudioPlayer *p = [[AVAudioPlayer alloc]
                                initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&perr];
            if (!p) {
                [MSLog error:@"audio" nsError:perr
                     context:[NSString stringWithFormat:@"플레이어 생성 %@", name]];
                break;
            }
            p.volume = [name isEqualToString:@"shoot"] ? 0.55 : 0.8;
            [p prepareToPlay];
            [pool addObject:p];
        }
        if (pool.count) {
            self.pools[name] = pool;
            self.cursors[name] = @0;
            ok++;
        } else {
            bad++;
        }
    }
    self.ready = YES;
    [MSLog info:@"audio" fmt:@"효과음 준비 끝 성공=%ld 실패=%ld (소리당 %ld성부)",
                            (long)ok, (long)bad, (long)kVoicesPerSound];
}

- (void)play:(NSString *)name {
    NSMutableArray<AVAudioPlayer *> *pool = self.pools[name];
    if (!pool.count) {
        [MSLog throttled:@"audio" key:name fmt:@"효과음을 낼 수 없다 name=%@ (적재 실패)", name];
        return;
    }
    NSInteger idx = self.cursors[name].integerValue % pool.count;
    self.cursors[name] = @(idx + 1);
    AVAudioPlayer *p = pool[idx];
    p.currentTime = 0;
    [p play];
}

- (void)playEvents:(uint32_t)events enabled:(BOOL)enabled {
    if (!events) return;
    if (!self.ready) [self start];
    if (!enabled) return;

    if (events & MS_SFX_SHOOT)     [self play:@"shoot"];
    if (events & MS_SFX_GRENADE)   [self play:@"grenade"];
    if (events & MS_SFX_EXPLOSION) [self play:@"explosion"];
    if (events & MS_SFX_JUMP)      [self play:@"jump"];
    if (events & MS_SFX_HIT)       [self play:@"hit"];
    if (events & MS_SFX_PICKUP)    [self play:@"pickup"];
    if (events & MS_SFX_SLUG)      [self play:@"slug"];
    if (events & MS_SFX_GAMEOVER)  [self play:@"gameover"];
}

@end
