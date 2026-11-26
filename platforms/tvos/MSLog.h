//  MSLog — 진단 로그 (DiagLog)
//
//  카테고리별로 남기고, 레벨은 info/warn/error 세 가지다.
//  한 번의 실행은 하나의 traceId 를 갖고, 모든 줄에 그 값이 붙는다.
//  오류는 domain·code·msg 를 반드시 함께 남긴다.
//
//  파일은 앱 내부 Documents/DiagLog/ 아래에 쌓인다.
//  (/var/mobile/Media 아래는 애플TV에서 앱이 쓸 수 없다)

#import <Foundation/Foundation.h>

/// 로그 카테고리. 새 영역을 만들면 여기에 추가한다.
extern NSString *const MSLogCatApp;      // 앱 생명주기
extern NSString *const MSLogCatAsset;    // 스프라이트 적재
extern NSString *const MSLogCatRender;   // 그리기
extern NSString *const MSLogCatInput;    // 키보드·게임패드·리모컨
extern NSString *const MSLogCatGame;     // 게임 진행
extern NSString *const MSLogCatPrefs;    // 설정 저장·복원

@interface MSLog : NSObject

/// 실행 하나를 식별하는 값. 모든 줄에 붙는다.
@property (class, nonatomic, readonly) NSString *traceId;
/// 현재 로그 파일 경로 (앱 내부). 문제 보고 시 이 파일을 꺼내면 된다.
@property (class, nonatomic, readonly) NSString *logPath;

+ (void)start;
+ (void)info:(NSString *)category fmt:(NSString *)fmt, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)warn:(NSString *)category fmt:(NSString *)fmt, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)error:(NSString *)category
       domain:(NSString *)domain
         code:(NSInteger)code
          msg:(NSString *)msg;
/// NSError 를 그대로 받아 domain·code·msg 로 풀어 남긴다.
+ (void)error:(NSString *)category nsError:(NSError *)err context:(NSString *)context;
/// 같은 줄이 초당 수십 번 찍히는 것을 막는다 (그리기 경로용).
+ (void)throttled:(NSString *)category key:(NSString *)key fmt:(NSString *)fmt, ... NS_FORMAT_FUNCTION(3, 4);

@end
