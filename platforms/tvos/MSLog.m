#import "MSLog.h"

NSString *const MSLogCatApp    = @"app";
NSString *const MSLogCatAsset  = @"asset";
NSString *const MSLogCatRender = @"render";
NSString *const MSLogCatInput  = @"input";
NSString *const MSLogCatGame   = @"game";
NSString *const MSLogCatPrefs  = @"prefs";

static NSString *gTraceId = nil;
static NSString *gLogPath = nil;
static NSFileHandle *gHandle = nil;
static dispatch_queue_t gQueue = nil;
static NSMutableDictionary<NSString *, NSNumber *> *gLastSeen = nil;
static NSDateFormatter *gStamp = nil;

@implementation MSLog

+ (NSString *)traceId { return gTraceId ?: @"-"; }
+ (NSString *)logPath { return gLogPath ?: @""; }

+ (void)start {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gQueue = dispatch_queue_create("ms.diaglog", DISPATCH_QUEUE_SERIAL);
        gLastSeen = [NSMutableDictionary dictionary];

        uint32_t a = arc4random(), b = arc4random();
        gTraceId = [NSString stringWithFormat:@"%08x%08x", a, b];

        gStamp = [[NSDateFormatter alloc] init];
        gStamp.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

        NSString *docs = NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *dir = [docs stringByAppendingPathComponent:@"DiagLog"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        NSDateFormatter *fileFmt = [[NSDateFormatter alloc] init];
        fileFmt.dateFormat = @"yyyyMMdd-HHmmss";
        gLogPath = [dir stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"metalslug-%@.log",
                     [fileFmt stringFromDate:[NSDate date]]]];
        [[NSFileManager defaultManager] createFileAtPath:gLogPath contents:nil attributes:nil];
        gHandle = [NSFileHandle fileHandleForWritingAtPath:gLogPath];

        [self pruneOldLogsIn:dir keep:8];
    });
}

/// 오래된 로그는 8개만 남긴다. 애플TV 저장 공간을 갉아먹지 않도록.
+ (void)pruneOldLogsIn:(NSString *)dir keep:(NSUInteger)keep {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [[fm contentsOfDirectoryAtPath:dir error:nil]
        sortedArrayUsingSelector:@selector(compare:)];
    if (files.count <= keep) return;
    for (NSUInteger i = 0; i + keep < files.count; i++) {
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:files[i]] error:nil];
    }
}

+ (void)writeLevel:(NSString *)level category:(NSString *)cat line:(NSString *)line {
    if (!gQueue) [self start];
    NSString *row = [NSString stringWithFormat:@"%@ [%@] %-6s %-6s %@\n",
                     [gStamp stringFromDate:[NSDate date]], gTraceId,
                     level.UTF8String, cat.UTF8String, line];
    NSLog(@"%@", row);   // 콘솔에도 남겨 기기 연결 없이 확인할 수 있게 한다
    dispatch_async(gQueue, ^{
        @try { [gHandle writeData:[row dataUsingEncoding:NSUTF8StringEncoding]]; }
        @catch (__unused NSException *e) { }
    });
}

+ (void)info:(NSString *)category fmt:(NSString *)fmt, ... {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    [self writeLevel:@"info" category:category line:s];
}

+ (void)warn:(NSString *)category fmt:(NSString *)fmt, ... {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    [self writeLevel:@"warn" category:category line:s];
}

+ (void)error:(NSString *)category
       domain:(NSString *)domain
         code:(NSInteger)code
          msg:(NSString *)msg {
    [self writeLevel:@"error" category:category
                line:[NSString stringWithFormat:@"domain=%@ code=%ld msg=%@",
                      domain, (long)code, msg]];
}

+ (void)error:(NSString *)category nsError:(NSError *)err context:(NSString *)context {
    [self error:category
         domain:err.domain ?: @"unknown"
           code:err.code
            msg:[NSString stringWithFormat:@"%@ — %@", context,
                 err.localizedDescription ?: @"(no description)"]];
}

+ (void)throttled:(NSString *)category key:(NSString *)key fmt:(NSString *)fmt, ... {
    if (!gQueue) [self start];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    @synchronized (gLastSeen) {
        NSNumber *last = gLastSeen[key];
        if (last && now - last.doubleValue < 2.0) return;
        gLastSeen[key] = @(now);
    }
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    [self writeLevel:@"warn" category:category line:s];
}

@end
