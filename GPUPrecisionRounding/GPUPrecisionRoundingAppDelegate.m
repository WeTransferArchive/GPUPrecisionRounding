#import "GPUPrecisionRoundingAppDelegate.h"

@implementation GPUPrecisionRoundingAppDelegate
@synthesize glView=_glView;

@synthesize window=_window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];

    // Override point for customization after application launch.
    CGRect screenBounds = [[UIScreen mainScreen] bounds];    
    self.glView = [[[OpenGLView alloc] initWithFrame:screenBounds withScaleFactor:[UIScreen mainScreen].scale] autorelease];
    [self.window addSubview:_glView];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

- (void)dealloc
{
    [_glView release];
    [_window release];
    [super dealloc];
}

@end
