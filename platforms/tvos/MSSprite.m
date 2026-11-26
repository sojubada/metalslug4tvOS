#import "MSSprite.h"
#import "MSLog.h"

@interface MSSpriteSheet ()
@property (nonatomic, assign) CGImageRef image;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) CGFloat frameWidth;
@property (nonatomic, assign) CGFloat frameHeight;
@property (nonatomic, assign) BOOL valid;
@end

@implementation MSSpriteSheet

- (void)dealloc {
    if (_image) CGImageRelease(_image);
}

@end

@interface MSSpriteStore ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, MSSpriteSheet *> *cache;
@end

@implementation MSSpriteStore

+ (instancetype)shared {
    static MSSpriteStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[MSSpriteStore alloc] init]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _cache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *)pathFor:(NSString *)relativePath {
    NSString *base = [NSBundle mainBundle].resourcePath;
    return [base stringByAppendingPathComponent:
            [NSString stringWithFormat:@"assets/%@.png", relativePath]];
}

- (MSSpriteSheet *)sheet:(NSString *)relativePath frames:(NSInteger)frames {
    MSSpriteSheet *hit = self.cache[relativePath];
    if (hit) return hit;

    MSSpriteSheet *sheet = [[MSSpriteSheet alloc] init];
    sheet.frameCount = MAX(1, frames);

    NSString *path = [self pathFor:relativePath];
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (!img || !img.CGImage) {
        sheet.valid = NO;
        [MSLog error:MSLogCatAsset
              domain:@"MSSpriteStore"
                code:404
                 msg:[NSString stringWithFormat:@"스프라이트를 읽지 못했다 path=%@", path]];
    } else {
        sheet.image = CGImageRetain(img.CGImage);
        CGFloat w = CGImageGetWidth(sheet.image);
        CGFloat h = CGImageGetHeight(sheet.image);
        sheet.frameWidth = w / (CGFloat)sheet.frameCount;
        sheet.frameHeight = h;
        sheet.valid = YES;
        [MSLog info:MSLogCatAsset
                fmt:@"적재 %@ %.0fx%.0f frames=%ld cell=%.0fx%.0f",
                    relativePath, w, h, (long)sheet.frameCount,
                    sheet.frameWidth, sheet.frameHeight];
    }
    self.cache[relativePath] = sheet;
    return sheet;
}

- (void)preloadAndAudit {
    NSDictionary<NSString *, NSNumber *> *manifest = @{
        @"Character/Player/Run":             @6,
        @"Character/Player/Jump":            @3,
        @"Character/Player/Fire":            @4,
        @"Character/Player/Hit":             @4,
        @"Character/Enemy/Soldier/Soldier_Run":    @4,
        @"Character/Enemy/Soldier/Soldier_Attack": @3,
        @"Character/Enemy/Soldier/Soldier_Death":  @4,
        @"Character/Enemy/Soldier/Grenadier":      @3,
        @"Character/Enemy/Soldier/Paratrooper":    @2,
        @"Character/Enemy/Vehicle/Tank":     @1,
        @"Character/Enemy/Vehicle/Heli":     @2,
        @"Character/Boss/Boss_Tank":         @1,
        @"Character/Boss/Boss_Cannon":       @1,
        @"Vehicle/Player/Slug":              @1,
        @"WeaponSFX/Explosion":              @6,
        @"WeaponSFX/Muzzle":                 @3,
        @"WeaponSFX/Bullets":                @4,
        @"WeaponSFX/Smoke":                  @5,
        @"WeaponSFX/Impact":                 @4,
        @"Item/Items":                       @8,
        @"Item/Hostage":                     @3,
        @"Map/Ground_Tile":                  @1,
        @"Map/BG_Far":                       @1,
        @"Map/BG_Mid":                       @6,
        @"Map/Bunker":                       @1,
        @"UI/Font_Numbers":                  @10,
        @"UI/HUD_Icons":                     @5,
    };
    NSInteger ok = 0, bad = 0;
    for (NSString *key in manifest) {
        MSSpriteSheet *s = [self sheet:key frames:manifest[key].integerValue];
        if (s.valid) ok++; else bad++;
    }
    [MSLog info:MSLogCatAsset fmt:@"스프라이트 점검 끝 성공=%ld 실패=%ld 번들=%@",
                                  (long)ok, (long)bad, [NSBundle mainBundle].resourcePath];
    if (bad > 0) {
        [MSLog warn:MSLogCatAsset
                fmt:@"빠진 스프라이트가 있어 해당 대상은 단색 도형으로 그린다 (%ld건)", (long)bad];
    }
}

@end

void MSDrawSpriteFrame(CGContextRef ctx, MSSpriteSheet *sheet, NSInteger frame,
                       CGRect dest, BOOL flipX, UIColor *tint, CGFloat alpha) {
    if (!sheet || !sheet.valid || !ctx) return;
    if (frame < 0) frame = 0;
    if (frame >= sheet.frameCount) frame = sheet.frameCount - 1;

    CGRect crop = CGRectMake(frame * sheet.frameWidth, 0,
                             sheet.frameWidth, sheet.frameHeight);
    CGImageRef piece = CGImageCreateWithImageInRect(sheet.image, crop);
    if (!piece) {
        [MSLog throttled:MSLogCatRender key:@"crop-fail"
                     fmt:@"프레임을 잘라내지 못했다 frame=%ld", (long)frame];
        return;
    }

    CGContextSaveGState(ctx);
    CGContextSetAlpha(ctx, alpha);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);  // 도트는 보간하지 않는다

    // UIKit 좌표는 y가 아래로 늘어나므로 이미지가 뒤집힌다. 뒤집어서 되돌린다.
    CGContextTranslateCTM(ctx, CGRectGetMinX(dest), CGRectGetMinY(dest));
    CGContextTranslateCTM(ctx, flipX ? dest.size.width : 0, dest.size.height);
    CGContextScaleCTM(ctx, flipX ? -1.0 : 1.0, -1.0);
    CGRect local = CGRectMake(0, 0, dest.size.width, dest.size.height);

    CGContextDrawImage(ctx, local, piece);

    if (tint) {
        // 피격 섬광 — 스프라이트 모양 그대로 색을 덮는다
        CGContextClipToMask(ctx, local, piece);
        CGContextSetFillColorWithColor(ctx, tint.CGColor);
        CGContextFillRect(ctx, local);
    }

    CGContextRestoreGState(ctx);
    CGImageRelease(piece);
}
