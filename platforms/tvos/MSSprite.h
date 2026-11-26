//  MSSprite — 스프라이트 아틀라스 적재와 그리기
//
//  assets/ 에 들어 있는 아틀라스(프레임을 가로로 이어 붙인 PNG)를 한 번만
//  읽어 두고, 프레임 번호로 잘라 그린다. 도트가 뭉개지지 않도록 확대는
//  니어리스트로 한다.

#import <UIKit/UIKit.h>

@interface MSSpriteSheet : NSObject
@property (nonatomic, readonly) CGImageRef image;
@property (nonatomic, readonly) NSInteger frameCount;
@property (nonatomic, readonly) CGFloat frameWidth;
@property (nonatomic, readonly) CGFloat frameHeight;
/// 적재에 실패했으면 NO. 이 경우 렌더러는 단색 대체 도형을 그린다.
@property (nonatomic, readonly) BOOL valid;
@end

@interface MSSpriteStore : NSObject

+ (instancetype)shared;

/// 번들의 assets/<상대경로>.png 를 읽는다. 예: @"Character/Player/Run"
/// 같은 경로를 다시 부르면 캐시에서 돌려준다.
- (MSSpriteSheet *)sheet:(NSString *)relativePath frames:(NSInteger)frames;

/// 앱 시작 시 한 번 호출해 어떤 파일이 있고 없는지 로그로 남긴다.
- (void)preloadAndAudit;

@end

/// 프레임 하나를 사각형에 맞춰 그린다. flipX 면 좌우를 뒤집는다.
/// tint 가 nil 이 아니면 그 색으로 덮어 그린다 (피격 섬광용).
void MSDrawSpriteFrame(CGContextRef ctx, MSSpriteSheet *sheet, NSInteger frame,
                       CGRect dest, BOOL flipX, UIColor *tint, CGFloat alpha);
