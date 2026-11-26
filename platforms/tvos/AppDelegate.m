#import "AppDelegate.h"
#import "GameViewController.h"

@interface AppDelegate ()
@property (strong, nonatomic) GameViewController *rootVC;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.rootVC = [[GameViewController alloc] init];
    self.window.rootViewController = self.rootVC;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application { [self.rootVC saveGamePreferences]; }
- (void)applicationWillTerminate:(UIApplication *)application { [self.rootVC saveGamePreferences]; }
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application { [self.rootVC handleMemoryWarning]; }

@end
