#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#include "ms_game.h"

@interface TVOSGameView : UIView
@property (nonatomic, assign) ms_game_state_t *gameState;
@property (nonatomic, assign) uint32_t activeInputMask;
- (void)loadPreferencesFromDefaults;
- (void)savePreferencesToDefaults;
- (void)applyResolutionSettings;
- (uint32_t)pollCombinedInputMask;
@end
