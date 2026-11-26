//  MSAudio — 효과음 재생
//
//  assets/sfx/*.wav 를 미리 읽어 두고, 코어가 세워 둔 이벤트 비트를 보고
//  해당 소리를 낸다. 같은 소리가 겹쳐 날 수 있도록 플레이어를 몇 개씩 돌려 쓴다.

#import <Foundation/Foundation.h>
#include "ms_game.h"

@interface MSAudio : NSObject

+ (instancetype)shared;

/// 오디오 세션을 켜고 WAV 를 모두 읽는다. 하나라도 빠지면 로그에 남는다.
- (void)start;

/// 코어가 이번 틱에 세워 둔 이벤트 비트를 받아 소리를 낸다.
- (void)playEvents:(uint32_t)events enabled:(BOOL)enabled;

@end
