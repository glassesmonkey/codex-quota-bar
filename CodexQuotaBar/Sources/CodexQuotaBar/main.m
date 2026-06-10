#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#import <dispatch/dispatch.h>
#import <math.h>

static NSString *const UsageEndpoint = @"https://chatgpt.com/backend-api/wham/usage";
static NSString *const ErrorDomain = @"CodexQuotaBar";

static double ClampPercent(double value) {
    if (!isfinite(value)) return 0;
    return fmin(100, fmax(0, value));
}

static NSString *CleanString(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length ? trimmed : nil;
}

static NSNumber *CleanNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSString.class]) {
        double parsed = [(NSString *)value doubleValue];
        return isfinite(parsed) ? @(parsed) : nil;
    }
    return nil;
}

static BOOL AppUsesChinese(void) {
    NSString *language = NSLocale.preferredLanguages.firstObject.lowercaseString ?: @"";
    return [language hasPrefix:@"zh"];
}

static NSString *L(NSString *key) {
    static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *tables;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tables = @{
            @"en": @{
                @"reset.unavailable": @"Reset time unavailable",
                @"reset.in.at": @"Reset in %@ at %@",
                @"auth.missing_token": @"auth.json is missing tokens.access_token",
                @"auth.expired": @"Codex auth is expired or not accepted (HTTP %ld)",
                @"usage.http_failed": @"Usage request failed with HTTP %ld",
                @"usage.not_json": @"Usage response was not JSON",
                @"prediction.collecting": @"Collecting planning data",
                @"prediction.collecting_detail": @"A few refreshes will make the forecast steadier.",
                @"prediction.pace_empty": @"Pace --",
                @"prediction.low": @"Low confidence",
                @"prediction.medium": @"Medium confidence",
                @"prediction.high": @"High confidence",
                @"prediction.no_trend": @"No burn trend yet",
                @"prediction.no_trend_detail": @"7d usage has not increased enough to project depletion.",
                @"prediction.pace_zero": @"Pace 0%/h",
                @"prediction.early_empty": @"Early estimate: empty in %@",
                @"prediction.early_reset": @"Early estimate: lasts through reset",
                @"prediction.early_before_detail": @"Based on the current cycle only; empty around %@ if this pace holds.",
                @"prediction.early_after_detail": @"Based on the current cycle only; empty in %@ after reset.",
                @"prediction.runout": @"7d runout in %@",
                @"prediction.lasts_reset": @"7d likely lasts through reset",
                @"prediction.before_detail": @"Projected empty around %@, before the current reset.",
                @"prediction.after_detail": @"At this pace, empty in %@, after the current reset.",
                @"prediction.pace": @"Pace %.2f%%/h",
                @"burst.unknown": @"5h burst unknown",
                @"burst.high": @"5h burst high",
                @"burst.moderate": @"5h burst moderate",
                @"burst.calm": @"5h burst calm",
                @"dial.left": @"left",
                @"quota.used": @"%ld%% used",
                @"quota.no_data": @"No data",
                @"panel.planning": @"Planning outlook",
                @"app.title": @"Codex Quota",
                @"app.current_account": @"CURRENT ACCOUNT",
                @"account.default": @"Codex account",
                @"account.auth_refreshed": @"Auth refreshed %@",
                @"window.fast": @"Fast window",
                @"window.weekly": @"Weekly window",
                @"button.refresh": @"Refresh",
                @"button.auth": @"Auth",
                @"button.quit": @"Quit",
                @"status.sync": @"SYNC",
                @"status.check": @"CHECK",
                @"status.proxy": @"PROXY",
                @"status.live": @"LIVE",
                @"footer.updated": @"Updated %@%@",
                @"footer.via_proxy": @" via proxy",
                @"footer.reading": @"Reading Codex quota",
                @"footer.waiting": @"Waiting for data",
                @"error.unable_auth": @"Unable to read Codex auth.json",
                @"error.unable_auth_short": @"Unable to read auth",
            },
            @"zh": @{
                @"reset.unavailable": @"重置时间不可用",
                @"reset.in.at": @"%@后重置 %@",
                @"auth.missing_token": @"auth.json 缺少 tokens.access_token",
                @"auth.expired": @"Codex 授权已过期或不可用 (HTTP %ld)",
                @"usage.http_failed": @"额度请求失败 (HTTP %ld)",
                @"usage.not_json": @"额度接口返回不是 JSON",
                @"prediction.collecting": @"正在积累规划数据",
                @"prediction.collecting_detail": @"多刷新几次后，预测会更稳定。",
                @"prediction.pace_empty": @"速度 --",
                @"prediction.low": @"低置信度",
                @"prediction.medium": @"中置信度",
                @"prediction.high": @"高置信度",
                @"prediction.no_trend": @"暂时没有消耗趋势",
                @"prediction.no_trend_detail": @"7天额度增长还不够，暂时无法预测耗尽时间。",
                @"prediction.pace_zero": @"速度 0%/小时",
                @"prediction.early_empty": @"早期估算：%@后耗尽",
                @"prediction.early_reset": @"早期估算：可撑到重置",
                @"prediction.early_before_detail": @"仅基于当前周期；若保持此速度，约 %@ 耗尽。",
                @"prediction.early_after_detail": @"仅基于当前周期；约 %@后耗尽，晚于本次重置。",
                @"prediction.runout": @"7天额度 %@后耗尽",
                @"prediction.lasts_reset": @"7天额度大概率可撑到重置",
                @"prediction.before_detail": @"预计约 %@ 耗尽，早于当前重置时间。",
                @"prediction.after_detail": @"按当前速度约 %@ 后耗尽，晚于本次重置。",
                @"prediction.pace": @"速度 %.2f%%/小时",
                @"burst.unknown": @"5小时压力未知",
                @"burst.high": @"5小时压力高",
                @"burst.moderate": @"5小时压力中",
                @"burst.calm": @"5小时压力低",
                @"dial.left": @"剩余",
                @"quota.used": @"已用 %ld%%",
                @"quota.no_data": @"无数据",
                @"panel.planning": @"用量规划",
                @"app.title": @"Codex 额度",
                @"app.current_account": @"当前账号",
                @"account.default": @"Codex 账号",
                @"account.auth_refreshed": @"凭证刷新 %@",
                @"window.fast": @"5小时窗口",
                @"window.weekly": @"7天窗口",
                @"button.refresh": @"刷新",
                @"button.auth": @"凭证",
                @"button.quit": @"退出",
                @"status.sync": @"同步",
                @"status.check": @"检查",
                @"status.proxy": @"代理",
                @"status.live": @"在线",
                @"footer.updated": @"已更新 %@%@",
                @"footer.via_proxy": @"，代理",
                @"footer.reading": @"正在读取 Codex 额度",
                @"footer.waiting": @"等待数据",
                @"error.unable_auth": @"无法读取 Codex auth.json",
                @"error.unable_auth_short": @"无法读取授权",
            },
        };
    });
    NSDictionary *table = tables[AppUsesChinese() ? @"zh" : @"en"];
    return table[key] ?: tables[@"en"][key] ?: key;
}

static NSDate *DateFromEpoch(id value) {
    NSNumber *number = CleanNumber(value);
    if (!number) return nil;
    double raw = number.doubleValue;
    if (raw > 10000000000.0) raw = raw / 1000.0;
    return [NSDate dateWithTimeIntervalSince1970:raw];
}

static NSString *DurationText(NSTimeInterval seconds) {
    seconds = fmax(0, seconds);
    NSInteger minutes = (NSInteger)llround(seconds / 60.0);
    BOOL zh = AppUsesChinese();
    if (minutes < 60) return zh ? [NSString stringWithFormat:@"%ld分钟", (long)MAX(1, minutes)] : [NSString stringWithFormat:@"%ldm", (long)MAX(1, minutes)];
    NSInteger hours = minutes / 60;
    NSInteger remMinutes = minutes % 60;
    if (hours < 24) {
        if (zh) return remMinutes ? [NSString stringWithFormat:@"%ld小时%ld分钟", (long)hours, (long)remMinutes] : [NSString stringWithFormat:@"%ld小时", (long)hours];
        return remMinutes ? [NSString stringWithFormat:@"%ldh %ldm", (long)hours, (long)remMinutes] : [NSString stringWithFormat:@"%ldh", (long)hours];
    }
    NSInteger days = hours / 24;
    NSInteger remHours = hours % 24;
    if (zh) return remHours ? [NSString stringWithFormat:@"%ld天%ld小时", (long)days, (long)remHours] : [NSString stringWithFormat:@"%ld天", (long)days];
    return remHours ? [NSString stringWithFormat:@"%ldd %ldh", (long)days, (long)remHours] : [NSString stringWithFormat:@"%ldd", (long)days];
}

static NSString *ClockText(NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"HH:mm";
    });
    return [formatter stringFromDate:date];
}

static NSString *ShortDateTime(NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = AppUsesChinese() ? @"M月d日 HH:mm" : @"MMM d HH:mm";
    });
    return [formatter stringFromDate:date];
}

static NSString *NowClockText(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"HH:mm:ss";
    });
    return [formatter stringFromDate:NSDate.date];
}

static NSString *ResetText(NSDate *date) {
    if (!date) return L(@"reset.unavailable");
    return [NSString stringWithFormat:L(@"reset.in.at"), DurationText([date timeIntervalSinceNow]), ClockText(date)];
}

static NSData *Base64URLDecode(NSString *value) {
    NSString *base64 = [[value stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
        stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSUInteger padding = (4 - base64.length % 4) % 4;
    if (padding) base64 = [base64 stringByPaddingToLength:base64.length + padding withString:@"=" startingAtIndex:0];
    return [[NSData alloc] initWithBase64EncodedString:base64 options:0];
}

static NSString *SHA256String(NSString *input) {
    if (!input.length) return @"default";
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [out appendFormat:@"%02x", digest[i]];
    return out;
}

static NSDate *ParseISODate(NSString *value) {
    if (!value.length) return nil;
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *date = [formatter dateFromString:value];
    if (date) return date;
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    return [formatter dateFromString:value];
}

@interface QuotaWindow : NSObject
@property(nonatomic, copy) NSString *label;
@property(nonatomic) double usedPercent;
@property(nonatomic) double remainingPercent;
@property(nonatomic, strong) NSDate *resetAt;
@property(nonatomic) double windowSeconds;
@end
@implementation QuotaWindow
@end

@interface Prediction : NSObject
@property(nonatomic, copy) NSString *headline;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, copy) NSString *pace;
@property(nonatomic, copy) NSString *burst;
@property(nonatomic, copy) NSString *confidence;
@property(nonatomic) NSInteger sampleCount;
@end
@implementation Prediction
@end

@interface AuthInfo : NSObject
@property(nonatomic, strong) NSURL *path;
@property(nonatomic, copy) NSString *authMode;
@property(nonatomic, copy) NSString *accessToken;
@property(nonatomic, copy) NSString *accountId;
@property(nonatomic, copy) NSString *email;
@property(nonatomic, strong) NSDate *lastRefresh;
@end
@implementation AuthInfo
@end

@interface UsageResult : NSObject
@property(nonatomic, strong) QuotaWindow *primary;
@property(nonatomic, strong) QuotaWindow *secondary;
@property(nonatomic, copy) NSString *plan;
@property(nonatomic) BOOL usedProxy;
@end
@implementation UsageResult
@end

@interface QuotaSnapshot : NSObject
@property(nonatomic, strong) QuotaWindow *primary;
@property(nonatomic, strong) QuotaWindow *secondary;
@property(nonatomic, strong) Prediction *prediction;
@property(nonatomic, copy) NSString *plan;
@property(nonatomic, copy) NSString *authPath;
@property(nonatomic, copy) NSString *authMode;
@property(nonatomic, copy) NSString *accountId;
@property(nonatomic, copy) NSString *email;
@property(nonatomic, strong) NSDate *authLastRefresh;
@property(nonatomic, strong) NSDate *lastUpdated;
@property(nonatomic, copy) NSString *errorMessage;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL usedProxy;
@end
@implementation QuotaSnapshot
+ (instancetype)empty {
    QuotaSnapshot *snapshot = [QuotaSnapshot new];
    snapshot.authPath = [NSHomeDirectory() stringByAppendingPathComponent:@".codex/auth.json"];
    return snapshot;
}
@end

@interface AuthStore : NSObject
- (AuthInfo *)readAuth:(NSError **)error;
@end

@implementation AuthStore
- (AuthInfo *)readAuth:(NSError **)error {
    NSURL *path = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@".codex/auth.json"]];
    NSData *data = [NSData dataWithContentsOfURL:path options:0 error:error];
    if (!data) return nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:NSDictionary.class]) return nil;

    NSDictionary *tokens = json[@"tokens"];
    NSString *access = CleanString(tokens[@"access_token"]);
    if (!access) {
        if (error) *error = [NSError errorWithDomain:ErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: L(@"auth.missing_token")}];
        return nil;
    }

    NSDictionary *identity = [self identityFromAccessToken:access];
    AuthInfo *auth = [AuthInfo new];
    auth.path = path;
    auth.authMode = CleanString(json[@"auth_mode"]);
    auth.accessToken = access;
    auth.accountId = CleanString(tokens[@"account_id"]) ?: CleanString(identity[@"accountId"]);
    auth.email = CleanString(identity[@"email"]);
    auth.lastRefresh = ParseISODate(CleanString(json[@"last_refresh"]));
    return auth;
}

- (NSDictionary *)identityFromAccessToken:(NSString *)token {
    NSArray<NSString *> *parts = [token componentsSeparatedByString:@"."];
    if (parts.count != 3) return @{};
    NSData *data = Base64URLDecode(parts[1]);
    if (!data) return @{};
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![payload isKindOfClass:NSDictionary.class]) return @{};
    NSDictionary *auth = payload[@"https://api.openai.com/auth"];
    NSDictionary *profile = payload[@"https://api.openai.com/profile"];
    return @{
        @"accountId": CleanString(auth[@"chatgpt_account_id"]) ?: @"",
        @"email": CleanString(profile[@"email"]) ?: @"",
    };
}
@end

static NSString *WindowLabel(double seconds, NSString *fallback) {
    NSInteger hours = (NSInteger)llround(seconds / 3600.0);
    if (hours >= 168) return @"7d";
    if (hours >= 24 && hours % 24 == 0) return [NSString stringWithFormat:@"%ldd", (long)(hours / 24)];
    if (hours > 0) return [NSString stringWithFormat:@"%ldh", (long)hours];
    return fallback;
}

static QuotaWindow *BuildWindow(NSDictionary *raw, double fallbackSeconds, NSString *fallbackLabel) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    double seconds = CleanNumber(raw[@"limit_window_seconds"]).doubleValue ?: fallbackSeconds;
    double used = ClampPercent(CleanNumber(raw[@"used_percent"]).doubleValue);
    QuotaWindow *window = [QuotaWindow new];
    window.label = WindowLabel(seconds, fallbackLabel);
    window.usedPercent = used;
    window.remainingPercent = ClampPercent(100.0 - used);
    window.resetAt = DateFromEpoch(raw[@"reset_at"]);
    window.windowSeconds = seconds;
    return window;
}

@interface UsageClient : NSObject
- (void)fetchWithAuth:(AuthInfo *)auth completion:(void (^)(UsageResult *, NSError *))completion;
@end

@implementation UsageClient
- (void)fetchWithAuth:(AuthInfo *)auth completion:(void (^)(UsageResult *, NSError *))completion {
    [self fetchWithAuth:auth useProxy:NO completion:^(UsageResult *result, NSError *error) {
        if (error && [self shouldRetryWithProxy:error]) {
            [self fetchWithAuth:auth useProxy:YES completion:completion];
            return;
        }
        completion(result, error);
    }];
}

- (void)fetchWithAuth:(AuthInfo *)auth useProxy:(BOOL)useProxy completion:(void (^)(UsageResult *, NSError *))completion {
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest = 8;
    config.timeoutIntervalForResource = 8;
    config.waitsForConnectivity = NO;
    if (useProxy) {
        config.connectionProxyDictionary = @{
            @"HTTPEnable": @YES,
            @"HTTPProxy": @"127.0.0.1",
            @"HTTPPort": @7890,
            @"HTTPSEnable": @YES,
            @"HTTPSProxy": @"127.0.0.1",
            @"HTTPSPort": @7890,
        };
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:UsageEndpoint]];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 8;
    [request setValue:[@"Bearer " stringByAppendingString:auth.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"codex-quota-bar" forHTTPHeaderField:@"User-Agent"];
    if (auth.accountId.length) [request setValue:auth.accountId forHTTPHeaderField:@"ChatGPT-Account-Id"];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            [session finishTasksAndInvalidate];
            return;
        }

        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status < 200 || status >= 300) {
            NSString *message = (status == 401 || status == 403)
                ? [NSString stringWithFormat:L(@"auth.expired"), (long)status]
                : [NSString stringWithFormat:L(@"usage.http_failed"), (long)status];
            completion(nil, [NSError errorWithDomain:ErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey: message}]);
            [session finishTasksAndInvalidate];
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![json isKindOfClass:NSDictionary.class]) {
            completion(nil, error ?: [NSError errorWithDomain:ErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: L(@"usage.not_json")}]);
            [session finishTasksAndInvalidate];
            return;
        }

        NSDictionary *rateLimit = json[@"rate_limit"];
        UsageResult *result = [UsageResult new];
        result.primary = BuildWindow(rateLimit[@"primary_window"], 18000, @"5h");
        result.secondary = BuildWindow(rateLimit[@"secondary_window"], 604800, @"7d");
        result.plan = CleanString(json[@"plan_type"]);
        NSNumber *balance = CleanNumber(json[@"credits"][@"balance"]);
        if (balance) {
            NSString *balanceText = [NSString stringWithFormat:@"$%.2f", balance.doubleValue];
            result.plan = result.plan.length ? [NSString stringWithFormat:@"%@ (%@)", result.plan, balanceText] : balanceText;
        }
        result.usedProxy = useProxy;
        completion(result, nil);
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}

- (BOOL)shouldRetryWithProxy:(NSError *)error {
    if (![error.domain isEqualToString:NSURLErrorDomain]) return NO;
    switch (error.code) {
        case NSURLErrorTimedOut:
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorSecureConnectionFailed:
            return YES;
        default:
            return NO;
    }
}
@end

@interface HistoryStore : NSObject
@property(nonatomic, strong) NSURL *fileURL;
- (void)appendSnapshot:(QuotaSnapshot *)snapshot accountKey:(NSString *)accountKey;
- (Prediction *)predictionForSnapshot:(QuotaSnapshot *)snapshot accountKey:(NSString *)accountKey;
@end

@implementation HistoryStore
- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [base URLByAppendingPathComponent:@"CodexQuotaBar" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    _fileURL = [dir URLByAppendingPathComponent:@"usage-history.json"];
    return self;
}

- (NSArray<NSDictionary *> *)records {
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
    if (!data) return @[];
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *records = [root isKindOfClass:NSDictionary.class] ? root[@"records"] : nil;
    return [records isKindOfClass:NSArray.class] ? records : @[];
}

- (void)saveRecords:(NSArray<NSDictionary *> *)records {
    NSDictionary *root = @{@"version": @1, @"records": records};
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToURL:self.fileURL options:NSDataWritingAtomic error:nil];
}

- (void)appendSnapshot:(QuotaSnapshot *)snapshot accountKey:(NSString *)accountKey {
    if (!snapshot.primary && !snapshot.secondary) return;
    NSMutableArray *records = [[self records] mutableCopy];
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSMutableDictionary *record = [@{
        @"timestamp": @(now),
        @"accountKey": accountKey ?: @"default",
    } mutableCopy];
    if (snapshot.primary) {
        record[@"primaryUsed"] = @(snapshot.primary.usedPercent);
        record[@"primaryRemaining"] = @(snapshot.primary.remainingPercent);
        if (snapshot.primary.resetAt) record[@"primaryResetAt"] = @(snapshot.primary.resetAt.timeIntervalSince1970);
    }
    if (snapshot.secondary) {
        record[@"secondaryUsed"] = @(snapshot.secondary.usedPercent);
        record[@"secondaryRemaining"] = @(snapshot.secondary.remainingPercent);
        if (snapshot.secondary.resetAt) record[@"secondaryResetAt"] = @(snapshot.secondary.resetAt.timeIntervalSince1970);
    }
    [records addObject:record];

    NSTimeInterval cutoff = now - 14 * 24 * 3600;
    NSPredicate *recent = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return CleanNumber(item[@"timestamp"]).doubleValue >= cutoff;
    }];
    records = [[records filteredArrayUsingPredicate:recent] mutableCopy];
    if (records.count > 3000) {
        records = [[records subarrayWithRange:NSMakeRange(records.count - 3000, 3000)] mutableCopy];
    }
    [self saveRecords:records];
}

- (Prediction *)predictionForSnapshot:(QuotaSnapshot *)snapshot accountKey:(NSString *)accountKey {
    Prediction *prediction = [Prediction new];
    prediction.headline = L(@"prediction.collecting");
    prediction.detail = L(@"prediction.collecting_detail");
    prediction.pace = L(@"prediction.pace_empty");
    prediction.burst = [self burstTextForSnapshot:snapshot];
    prediction.confidence = L(@"prediction.low");

    if (!snapshot.secondary) return prediction;

    NSArray *all = [[self records] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        NSString *key = CleanString(item[@"accountKey"]) ?: @"default";
        if (![key isEqualToString:(accountKey ?: @"default")]) return NO;
        if (!CleanNumber(item[@"secondaryUsed"])) return NO;
        if (!snapshot.secondary.resetAt) return YES;
        NSNumber *reset = CleanNumber(item[@"secondaryResetAt"]);
        return !reset || fabs(reset.doubleValue - snapshot.secondary.resetAt.timeIntervalSince1970) < 2 * 3600;
    }]];

    NSArray *records = [all sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        double left = CleanNumber(a[@"timestamp"]).doubleValue;
        double right = CleanNumber(b[@"timestamp"]).doubleValue;
        return left < right ? NSOrderedAscending : (left > right ? NSOrderedDescending : NSOrderedSame);
    }];
    prediction.sampleCount = records.count;

    NSMutableArray<NSDictionary *> *rates = [NSMutableArray array];
    for (NSUInteger i = 1; i < records.count; i++) {
        NSDictionary *prev = records[i - 1];
        NSDictionary *next = records[i];
        double dtHours = (CleanNumber(next[@"timestamp"]).doubleValue - CleanNumber(prev[@"timestamp"]).doubleValue) / 3600.0;
        double delta = CleanNumber(next[@"secondaryUsed"]).doubleValue - CleanNumber(prev[@"secondaryUsed"]).doubleValue;
        if (dtHours < 0.08 || delta < 0.03) continue;
        double rate = delta / dtHours;
        if (rate <= 0 || rate > 15) continue;
        [rates addObject:@{@"rate": @(rate), @"timestamp": CleanNumber(next[@"timestamp"]) ?: @(NSDate.date.timeIntervalSince1970)}];
    }

    double rate = [self robustRateFromRates:rates];
    BOOL usedFallback = NO;
    if (rate <= 0) {
        rate = [self fallbackWeeklyRateForSnapshot:snapshot];
        usedFallback = rate > 0;
    }

    if (rate <= 0) {
        prediction.headline = L(@"prediction.no_trend");
        prediction.detail = L(@"prediction.no_trend_detail");
        prediction.pace = L(@"prediction.pace_zero");
        prediction.confidence = L(@"prediction.low");
        return prediction;
    }

    NSTimeInterval hoursToEmpty = (100.0 - snapshot.secondary.usedPercent) / rate;
    NSDate *projected = [NSDate dateWithTimeIntervalSinceNow:hoursToEmpty * 3600.0];
    NSString *duration = DurationText(hoursToEmpty * 3600.0);
    BOOL beforeReset = snapshot.secondary.resetAt && [projected compare:snapshot.secondary.resetAt] == NSOrderedAscending;
    BOOL earlyEstimate = usedFallback;
    if (earlyEstimate) {
        prediction.headline = beforeReset ? [NSString stringWithFormat:L(@"prediction.early_empty"), duration] : L(@"prediction.early_reset");
        prediction.detail = beforeReset
            ? [NSString stringWithFormat:L(@"prediction.early_before_detail"), ShortDateTime(projected)]
            : [NSString stringWithFormat:L(@"prediction.early_after_detail"), duration];
    } else {
        prediction.headline = beforeReset ? [NSString stringWithFormat:L(@"prediction.runout"), duration] : L(@"prediction.lasts_reset");
        prediction.detail = beforeReset
            ? [NSString stringWithFormat:L(@"prediction.before_detail"), ShortDateTime(projected)]
            : [NSString stringWithFormat:L(@"prediction.after_detail"), duration];
    }
    prediction.pace = [NSString stringWithFormat:L(@"prediction.pace"), rate];

    if (!usedFallback && rates.count >= 8) prediction.confidence = L(@"prediction.high");
    else if (!usedFallback && rates.count >= 3) prediction.confidence = L(@"prediction.medium");
    else prediction.confidence = L(@"prediction.low");
    return prediction;
}

- (double)robustRateFromRates:(NSArray<NSDictionary *> *)rates {
    if (rates.count < 2) return 0;
    NSArray<NSNumber *> *values = [[rates valueForKey:@"rate"] sortedArrayUsingSelector:@selector(compare:)];
    double median = values[values.count / 2].doubleValue;
    double maxAllowed = fmax(median * 4.0, median + 1.0);
    double weighted = 0;
    double weights = 0;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    for (NSDictionary *entry in rates) {
        double rate = CleanNumber(entry[@"rate"]).doubleValue;
        if (rate > maxAllowed) continue;
        double ageHours = fmax(0, (now - CleanNumber(entry[@"timestamp"]).doubleValue) / 3600.0);
        double weight = exp(-ageHours / 48.0);
        weighted += rate * weight;
        weights += weight;
    }
    return weights > 0 ? weighted / weights : 0;
}

- (double)fallbackWeeklyRateForSnapshot:(QuotaSnapshot *)snapshot {
    if (!snapshot.secondary.resetAt || snapshot.secondary.usedPercent <= 0.3) return 0;
    NSDate *cycleStart = [snapshot.secondary.resetAt dateByAddingTimeInterval:-7 * 24 * 3600];
    double elapsedHours = [NSDate.date timeIntervalSinceDate:cycleStart] / 3600.0;
    if (elapsedHours < 1) return 0;
    return snapshot.secondary.usedPercent / elapsedHours;
}

- (NSString *)burstTextForSnapshot:(QuotaSnapshot *)snapshot {
    if (!snapshot.primary) return L(@"burst.unknown");
    if (snapshot.primary.remainingPercent < 15) return L(@"burst.high");
    if (snapshot.primary.remainingPercent < 40) return L(@"burst.moderate");
    return L(@"burst.calm");
}
@end

@interface QuotaViewModel : NSObject
@property(nonatomic, strong) QuotaSnapshot *snapshot;
@property(nonatomic, copy) void (^onChange)(QuotaSnapshot *);
- (void)refresh;
@end

@implementation QuotaViewModel {
    AuthStore *_authStore;
    UsageClient *_usageClient;
    HistoryStore *_historyStore;
    BOOL _refreshing;
}
- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _snapshot = [QuotaSnapshot empty];
    _authStore = [AuthStore new];
    _usageClient = [UsageClient new];
    _historyStore = [HistoryStore new];
    return self;
}

- (void)setSnapshotAndNotify:(QuotaSnapshot *)snapshot {
    _snapshot = snapshot;
    if (self.onChange) self.onChange(snapshot);
}

- (void)refresh {
    if (_refreshing) return;
    _refreshing = YES;
    self.snapshot.loading = YES;
    self.snapshot.errorMessage = nil;
    if (self.onChange) self.onChange(self.snapshot);

    NSError *authError = nil;
    AuthInfo *auth = [_authStore readAuth:&authError];
    if (!auth) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_refreshing = NO;
            self.snapshot.loading = NO;
            self.snapshot.errorMessage = authError.localizedDescription ?: L(@"error.unable_auth");
            if (self.onChange) self.onChange(self.snapshot);
        });
        return;
    }

    [_usageClient fetchWithAuth:auth completion:^(UsageResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_refreshing = NO;
            if (error) {
                self.snapshot.loading = NO;
                self.snapshot.errorMessage = error.localizedDescription;
                if (self.onChange) self.onChange(self.snapshot);
                return;
            }

            QuotaSnapshot *next = [QuotaSnapshot empty];
            next.primary = result.primary;
            next.secondary = result.secondary;
            next.plan = result.plan;
            next.authPath = auth.path.path;
            next.authMode = auth.authMode;
            next.accountId = auth.accountId;
            next.email = auth.email;
            next.authLastRefresh = auth.lastRefresh;
            next.lastUpdated = NSDate.date;
            next.usedProxy = result.usedProxy;
            NSString *accountKey = SHA256String(auth.accountId ?: auth.email ?: @"default");
            [self->_historyStore appendSnapshot:next accountKey:accountKey];
            next.prediction = [self->_historyStore predictionForSnapshot:next accountKey:accountKey];
            [self setSnapshotAndNotify:next];
        });
    }];
}
@end

static NSColor *Color(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
}

@interface DialView : NSView
@property(nonatomic) double value;
@property(nonatomic, copy) NSString *label;
@property(nonatomic, strong) NSColor *accent;
@end
@implementation DialView
- (instancetype)init { self = [super initWithFrame:NSZeroRect]; if (self) { _label = @"--"; _accent = NSColor.systemGreenColor; } return self; }
- (void)setValue:(double)value { _value = ClampPercent(value); self.needsDisplay = YES; }
- (void)setLabel:(NSString *)label { _label = label ?: @"--"; self.needsDisplay = YES; }
- (void)setAccent:(NSColor *)accent { _accent = accent ?: NSColor.systemGreenColor; self.needsDisplay = YES; }
- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = NSInsetRect(self.bounds, 4, 4);
    NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
    CGFloat radius = MIN(NSWidth(rect), NSHeight(rect)) / 2.0;
    NSBezierPath *track = [NSBezierPath bezierPath];
    [track appendBezierPathWithArcWithCenter:center radius:radius startAngle:0 endAngle:360];
    track.lineWidth = 7;
    [[NSColor.whiteColor colorWithAlphaComponent:0.11] setStroke];
    [track stroke];
    NSBezierPath *progress = [NSBezierPath bezierPath];
    [progress appendBezierPathWithArcWithCenter:center radius:radius startAngle:90 endAngle:90 - 360 * self.value clockwise:YES];
    progress.lineWidth = 7;
    progress.lineCapStyle = NSLineCapStyleRound;
    [self.accent setStroke];
    [progress stroke];
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentCenter;
    NSDictionary *top = @{NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightBold], NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.92], NSParagraphStyleAttributeName: style};
    NSDictionary *bottom = @{NSFontAttributeName: [NSFont systemFontOfSize:9 weight:NSFontWeightMedium], NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.42], NSParagraphStyleAttributeName: style};
    [self.label drawInRect:NSMakeRect(0, NSMidY(self.bounds) + 1, NSWidth(self.bounds), 16) withAttributes:top];
    [L(@"dial.left") drawInRect:NSMakeRect(0, NSMidY(self.bounds) - 13, NSWidth(self.bounds), 13) withAttributes:bottom];
}
@end

@interface BarView : NSView
@property(nonatomic) double value;
@property(nonatomic, strong) NSColor *accent;
@end
@implementation BarView
- (instancetype)init { self = [super initWithFrame:NSZeroRect]; if (self) _accent = NSColor.systemGreenColor; return self; }
- (void)setValue:(double)value { _value = ClampPercent(value); self.needsDisplay = YES; }
- (void)setAccent:(NSColor *)accent { _accent = accent ?: NSColor.systemGreenColor; self.needsDisplay = YES; }
- (void)drawRect:(NSRect)dirtyRect {
    CGFloat radius = NSHeight(self.bounds) / 2.0;
    [[NSColor.whiteColor colorWithAlphaComponent:0.10] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:radius yRadius:radius] fill];
    CGFloat width = self.value <= 0 ? 0 : MAX(8, NSWidth(self.bounds) * self.value);
    if (width <= 0) return;
    [self.accent setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0, 0, width, NSHeight(self.bounds)) xRadius:radius yRadius:radius] fill];
}
@end

static NSTextField *Label(CGFloat size, NSFontWeight weight, NSColor *color, BOOL mono) {
    NSTextField *label = [NSTextField labelWithString:@""];
    label.font = mono ? [NSFont monospacedDigitSystemFontOfSize:size weight:weight] : [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

@interface PanelView : NSView
@property(nonatomic, strong) NSColor *fill;
@property(nonatomic, strong) NSColor *border;
@end
@implementation PanelView
- (instancetype)initWithFill:(NSColor *)fill border:(NSColor *)border {
    self = [super initWithFrame:NSZeroRect];
    if (!self) return nil;
    _fill = fill;
    _border = border;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 8;
    self.layer.backgroundColor = fill.CGColor;
    self.layer.borderColor = border.CGColor;
    self.layer.borderWidth = 1;
    return self;
}
@end

@interface QuotaRowView : PanelView
- (instancetype)initWithTitle:(NSString *)title fallback:(NSString *)fallback;
- (void)updateWithWindow:(QuotaWindow *)window accent:(NSColor *)accent;
@end

@implementation QuotaRowView {
    NSString *_fallback;
    DialView *_dial;
    BarView *_bar;
    NSTextField *_title;
    NSTextField *_reset;
    NSTextField *_remaining;
    NSTextField *_used;
}
- (instancetype)initWithTitle:(NSString *)title fallback:(NSString *)fallback {
    self = [super initWithFill:[NSColor.whiteColor colorWithAlphaComponent:0.085] border:[NSColor.whiteColor colorWithAlphaComponent:0.11]];
    if (!self) return nil;
    _fallback = fallback;
    _dial = [DialView new];
    _bar = [BarView new];
    _title = Label(13, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.94], NO);
    _title.stringValue = title;
    _reset = Label(11, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.47], NO);
    _remaining = Label(18, NSFontWeightBold, NSColor.whiteColor, YES);
    _remaining.alignment = NSTextAlignmentRight;
    _used = Label(10, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.45], NO);
    _used.alignment = NSTextAlignmentRight;
    for (NSView *view in @[_dial, _bar, _title, _reset, _remaining, _used]) [self addSubview:view];
    return self;
}
- (void)layout {
    [super layout];
    CGFloat w = NSWidth(self.bounds);
    _dial.frame = NSMakeRect(12, 20, 64, 64);
    _title.frame = NSMakeRect(90, 62, w - 190, 18);
    _reset.frame = NSMakeRect(90, 43, w - 190, 16);
    _remaining.frame = NSMakeRect(w - 96, 58, 84, 24);
    _used.frame = NSMakeRect(w - 96, 42, 84, 14);
    _bar.frame = NSMakeRect(90, 17, w - 102, 8);
}
- (void)updateWithWindow:(QuotaWindow *)window accent:(NSColor *)accent {
    _dial.label = window.label ?: _fallback;
    _dial.value = (window.remainingPercent / 100.0);
    _dial.accent = accent;
    _bar.value = (window.remainingPercent / 100.0);
    _bar.accent = accent;
    _remaining.stringValue = window ? [NSString stringWithFormat:@"%ld%%", (long)llround(window.remainingPercent)] : @"--%";
    _used.stringValue = window ? [NSString stringWithFormat:L(@"quota.used"), (long)llround(window.usedPercent)] : L(@"quota.no_data");
    _reset.stringValue = window ? ResetText(window.resetAt) : L(@"reset.unavailable");
}
@end

@interface PredictionPanelView : PanelView
- (void)update:(Prediction *)prediction;
@end
@implementation PredictionPanelView {
    NSTextField *_title;
    NSTextField *_headline;
    NSTextField *_detail;
    NSTextField *_pace;
    NSTextField *_burst;
    NSTextField *_confidence;
}
- (instancetype)init {
    self = [super initWithFill:[NSColor.whiteColor colorWithAlphaComponent:0.085] border:[NSColor.whiteColor colorWithAlphaComponent:0.11]];
    if (!self) return nil;
    _title = Label(12, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.58], NO);
    _title.stringValue = L(@"panel.planning");
    _headline = Label(15, NSFontWeightBold, NSColor.whiteColor, NO);
    _detail = Label(11, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.55], NO);
    _pace = Label(11, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.82], NO);
    _burst = Label(11, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.82], NO);
    _confidence = Label(11, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.82], NO);
    for (NSView *view in @[_title, _headline, _detail, _pace, _burst, _confidence]) [self addSubview:view];
    return self;
}
- (void)layout {
    [super layout];
    CGFloat w = NSWidth(self.bounds);
    _title.frame = NSMakeRect(12, 73, w - 24, 16);
    _headline.frame = NSMakeRect(12, 50, w - 24, 20);
    _detail.frame = NSMakeRect(12, 32, w - 24, 16);
    _pace.frame = NSMakeRect(12, 11, 110, 16);
    _burst.frame = NSMakeRect(132, 11, 112, 16);
    _confidence.frame = NSMakeRect(w - 116, 11, 104, 16);
    _confidence.alignment = NSTextAlignmentRight;
}
- (void)update:(Prediction *)prediction {
    _headline.stringValue = prediction.headline ?: L(@"prediction.collecting");
    _detail.stringValue = prediction.detail ?: L(@"prediction.collecting_detail");
    _pace.stringValue = prediction.pace ?: L(@"prediction.pace_empty");
    _burst.stringValue = prediction.burst ?: L(@"burst.unknown");
    _confidence.stringValue = prediction.confidence ?: L(@"prediction.low");
}
@end

static NSColor *AccentForRemaining(double remaining) {
    if (remaining > 55) return Color(0.35, 0.95, 0.72, 1);
    if (remaining > 20) return Color(1.0, 0.68, 0.24, 1);
    return Color(1.0, 0.36, 0.33, 1);
}

@interface QuotaPopoverView : NSView
- (instancetype)initWithModel:(QuotaViewModel *)model frame:(NSRect)frame;
- (void)update:(QuotaSnapshot *)snapshot;
@end

@implementation QuotaPopoverView {
    QuotaViewModel *_model;
    NSVisualEffectView *_glass;
    NSTextField *_plan;
    NSTextField *_status;
    NSTextField *_error;
    PanelView *_errorPanel;
    NSTextField *_account;
    NSTextField *_accountSub;
    NSTextField *_authMode;
    QuotaRowView *_primary;
    QuotaRowView *_secondary;
    PredictionPanelView *_prediction;
    NSTextField *_footer;
}
- (instancetype)initWithModel:(QuotaViewModel *)model frame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _model = model;
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.clearColor.CGColor;
    _glass = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
    _glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _glass.material = NSVisualEffectMaterialPopover;
    _glass.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _glass.state = NSVisualEffectStateActive;
    [self addSubview:_glass];
    [self build];
    return self;
}
- (void)build {
    NSTextField *title = Label(21, NSFontWeightSemibold, NSColor.whiteColor, NO);
    title.stringValue = L(@"app.title");
    title.frame = NSMakeRect(72, 512, 180, 25);
    [self addSubview:title];
    _plan = Label(11, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.56], NO);
    _plan.frame = NSMakeRect(72, 494, 190, 16);
    [self addSubview:_plan];

    PanelView *iconBox = [[PanelView alloc] initWithFill:[NSColor.whiteColor colorWithAlphaComponent:0.10] border:[NSColor.whiteColor colorWithAlphaComponent:0.11]];
    iconBox.frame = NSMakeRect(18, 494, 42, 42);
    [self addSubview:iconBox];
    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 10, 22, 22)];
    icon.image = [NSImage imageWithSystemSymbolName:@"gauge.with.needle" accessibilityDescription:L(@"app.title")];
    icon.contentTintColor = Color(0.28, 0.86, 0.78, 1);
    [iconBox addSubview:icon];

    _status = Label(11, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.78], NO);
    _status.alignment = NSTextAlignmentCenter;
    _status.frame = NSMakeRect(292, 505, 72, 20);
    _status.wantsLayer = YES;
    _status.layer.cornerRadius = 8;
    _status.layer.backgroundColor = [NSColor.whiteColor colorWithAlphaComponent:0.10].CGColor;
    [self addSubview:_status];

    _errorPanel = [[PanelView alloc] initWithFill:Color(0.38, 0.18, 0.10, 0.62) border:[NSColor.systemOrangeColor colorWithAlphaComponent:0.23]];
    _errorPanel.frame = NSMakeRect(18, 452, 348, 36);
    _errorPanel.hidden = YES;
    _error = Label(12, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.85], NO);
    _error.frame = NSMakeRect(10, 9, 328, 18);
    [_errorPanel addSubview:_error];
    [self addSubview:_errorPanel];

    PanelView *accountPanel = [[PanelView alloc] initWithFill:[NSColor.whiteColor colorWithAlphaComponent:0.075] border:[NSColor.whiteColor colorWithAlphaComponent:0.10]];
    accountPanel.frame = NSMakeRect(18, 416, 348, 66);
    _account = Label(13, NSFontWeightSemibold, [NSColor.whiteColor colorWithAlphaComponent:0.92], NO);
    _account.frame = NSMakeRect(44, 36, 210, 18);
    _account.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _accountSub = Label(11, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.48], NO);
    _accountSub.frame = NSMakeRect(44, 17, 230, 16);
    _accountSub.lineBreakMode = NSLineBreakByTruncatingMiddle;
    NSImageView *person = [[NSImageView alloc] initWithFrame:NSMakeRect(12, 22, 24, 24)];
    person.image = [NSImage imageWithSystemSymbolName:@"person.crop.circle" accessibilityDescription:L(@"account.default")];
    person.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.70];
    [accountPanel addSubview:person];
    [accountPanel addSubview:_account];
    [accountPanel addSubview:_accountSub];
    _authMode = Label(10, NSFontWeightBold, Color(0.85, 0.96, 0.93, 1), NO);
    _authMode.alignment = NSTextAlignmentCenter;
    _authMode.frame = NSMakeRect(268, 22, 66, 22);
    _authMode.wantsLayer = YES;
    _authMode.layer.cornerRadius = 8;
    _authMode.layer.backgroundColor = [NSColor.systemTealColor colorWithAlphaComponent:0.18].CGColor;
    [accountPanel addSubview:_authMode];
    [self addSubview:accountPanel];

    _primary = [[QuotaRowView alloc] initWithTitle:L(@"window.fast") fallback:@"5h"];
    _primary.frame = NSMakeRect(18, 300, 348, 104);
    [self addSubview:_primary];
    _secondary = [[QuotaRowView alloc] initWithTitle:L(@"window.weekly") fallback:@"7d"];
    _secondary.frame = NSMakeRect(18, 184, 348, 104);
    [self addSubview:_secondary];
    _prediction = [PredictionPanelView new];
    _prediction.frame = NSMakeRect(18, 74, 348, 98);
    [self addSubview:_prediction];

    _footer = Label(11, NSFontWeightMedium, [NSColor.whiteColor colorWithAlphaComponent:0.48], NO);
    _footer.frame = NSMakeRect(18, 47, 210, 16);
    [self addSubview:_footer];
    [self addSubview:[self button:L(@"button.refresh") symbol:@"arrow.clockwise" frame:NSMakeRect(18, 14, 88, 28) action:@selector(refreshClicked)]];
    [self addSubview:[self button:L(@"button.auth") symbol:@"folder" frame:NSMakeRect(114, 14, 72, 28) action:@selector(openAuthClicked)]];
    [self addSubview:[self button:L(@"button.quit") symbol:@"power" frame:NSMakeRect(294, 14, 72, 28) action:@selector(quitClicked)]];
}
- (NSButton *)button:(NSString *)title symbol:(NSString *)symbol frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.frame = frame;
    button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
    button.imagePosition = NSImageLeading;
    button.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.88];
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    button.bordered = NO;
    button.wantsLayer = YES;
    button.layer.cornerRadius = 7;
    button.layer.backgroundColor = [NSColor.whiteColor colorWithAlphaComponent:0.115].CGColor;
    button.layer.borderColor = [NSColor.whiteColor colorWithAlphaComponent:0.11].CGColor;
    button.layer.borderWidth = 1;
    return button;
}
- (void)update:(QuotaSnapshot *)snapshot {
    _plan.stringValue = snapshot.plan.uppercaseString ?: L(@"app.current_account");
    _status.stringValue = snapshot.loading ? L(@"status.sync") : (snapshot.errorMessage ? L(@"status.check") : (snapshot.usedProxy ? L(@"status.proxy") : L(@"status.live")));
    _errorPanel.hidden = snapshot.errorMessage.length == 0;
    _error.stringValue = snapshot.errorMessage ?: @"";
    _account.stringValue = snapshot.email ?: L(@"account.default");
    _accountSub.stringValue = snapshot.authLastRefresh ? [NSString stringWithFormat:L(@"account.auth_refreshed"), ShortDateTime(snapshot.authLastRefresh)] : (snapshot.accountId ?: snapshot.authPath);
    _authMode.stringValue = (snapshot.authMode ?: @"chatgpt").uppercaseString;
    [_primary updateWithWindow:snapshot.primary accent:AccentForRemaining(snapshot.primary ? snapshot.primary.remainingPercent : 0)];
    [_secondary updateWithWindow:snapshot.secondary accent:AccentForRemaining(snapshot.secondary ? snapshot.secondary.remainingPercent : 0)];
    [_prediction update:snapshot.prediction];
    _footer.stringValue = snapshot.lastUpdated ? [NSString stringWithFormat:L(@"footer.updated"), NowClockText(), snapshot.usedProxy ? L(@"footer.via_proxy") : @""] : (snapshot.loading ? L(@"footer.reading") : L(@"footer.waiting"));
}
- (void)refreshClicked { [_model refresh]; }
- (void)openAuthClicked { [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:_model.snapshot.authPath]]]; }
- (void)quitClicked { [NSApplication.sharedApplication terminate:nil]; }
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    NSPopover *_popover;
    QuotaViewModel *_model;
    QuotaPopoverView *_view;
    NSTimer *_timer;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _model = [QuotaViewModel new];
    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = _statusItem.button;
    button.image = [NSImage imageWithSystemSymbolName:@"gauge.with.needle" accessibilityDescription:L(@"app.title")];
    button.imagePosition = NSImageLeading;
    button.target = self;
    button.action = @selector(togglePopover:);
    button.toolTip = L(@"app.title");

    _popover = [NSPopover new];
    _popover.behavior = NSPopoverBehaviorTransient;
    _popover.animates = YES;
    _popover.contentSize = NSMakeSize(384, 560);
    NSViewController *controller = [NSViewController new];
    _view = [[QuotaPopoverView alloc] initWithModel:_model frame:NSMakeRect(0, 0, 384, 560)];
    controller.view = _view;
    _popover.contentViewController = controller;

    __weak typeof(self) weakSelf = self;
    _model.onChange = ^(QuotaSnapshot *snapshot) {
        AppDelegate *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf updateStatus:snapshot];
        [strongSelf->_view update:snapshot];
    };
    [self updateStatus:_model.snapshot];
    [_model refresh];
    _timer = [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer *timer) {
        AppDelegate *strongSelf = weakSelf;
        [strongSelf->_model refresh];
    }];
}
- (void)applicationWillTerminate:(NSNotification *)notification { [_timer invalidate]; }
- (void)updateStatus:(QuotaSnapshot *)snapshot {
    NSString *title = @"Codex --";
    if (snapshot.primary && snapshot.secondary) {
        title = [NSString stringWithFormat:@"%@ %.0f%% | %@ %.0f%%", snapshot.primary.label, snapshot.primary.remainingPercent, snapshot.secondary.label, snapshot.secondary.remainingPercent];
    } else if (snapshot.loading) title = @"Codex ...";
    else if (snapshot.errorMessage) title = @"Codex !";
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:12.5 weight:NSFontWeightMedium], NSForegroundColorAttributeName: NSColor.labelColor};
    _statusItem.button.attributedTitle = [[NSAttributedString alloc] initWithString:[@" " stringByAppendingString:title] attributes:attrs];
}
- (void)togglePopover:(id)sender {
    if (_popover.shown) {
        [_popover performClose:sender];
    } else {
        [_popover showRelativeToRect:_statusItem.button.bounds ofView:_statusItem.button preferredEdge:NSMinYEdge];
        [NSApp activateIgnoringOtherApps:YES];
    }
}
@end

static int RunOnce(void) {
    AuthStore *authStore = [AuthStore new];
    UsageClient *client = [UsageClient new];
    HistoryStore *history = [HistoryStore new];
    NSError *error = nil;
    AuthInfo *auth = [authStore readAuth:&error];
    if (!auth) {
        fprintf(stderr, "error: %s\n", (error.localizedDescription ?: L(@"error.unable_auth_short")).UTF8String);
        return 1;
    }

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block UsageResult *result = nil;
    __block NSError *fetchError = nil;
    [client fetchWithAuth:auth completion:^(UsageResult *value, NSError *innerError) {
        result = value;
        fetchError = innerError;
        dispatch_semaphore_signal(sema);
    }];
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) != 0) {
        fprintf(stderr, "error: usage check timed out\n");
        return 1;
    }
    if (fetchError) {
        fprintf(stderr, "error: %s\n", fetchError.localizedDescription.UTF8String);
        return 1;
    }

    QuotaSnapshot *snapshot = [QuotaSnapshot empty];
    snapshot.primary = result.primary;
    snapshot.secondary = result.secondary;
    snapshot.plan = result.plan;
    snapshot.authPath = auth.path.path;
    snapshot.authMode = auth.authMode;
    snapshot.accountId = auth.accountId;
    snapshot.email = auth.email;
    snapshot.authLastRefresh = auth.lastRefresh;
    snapshot.lastUpdated = NSDate.date;
    snapshot.usedProxy = result.usedProxy;
    NSString *key = SHA256String(auth.accountId ?: auth.email ?: @"default");
    [history appendSnapshot:snapshot accountKey:key];
    snapshot.prediction = [history predictionForSnapshot:snapshot accountKey:key];

    printf("ok\n");
    printf("plan: %s\n", (snapshot.plan ?: @"-").UTF8String);
    printf("account: %s\n", (snapshot.email ?: snapshot.accountId ?: @"-").UTF8String);
    printf("primary: %s remaining %.0f%%\n", (snapshot.primary.label ?: @"-").UTF8String, snapshot.primary.remainingPercent);
    printf("secondary: %s remaining %.0f%%\n", (snapshot.secondary.label ?: @"-").UTF8String, snapshot.secondary.remainingPercent);
    printf("forecast: %s | %s | %s | samples %ld\n", snapshot.prediction.headline.UTF8String, snapshot.prediction.pace.UTF8String, snapshot.prediction.confidence.UTF8String, (long)snapshot.prediction.sampleCount);
    printf("history: %s\n", history.fileURL.path.UTF8String);
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--once") == 0) return RunOnce();
        }
        NSApplication *app = NSApplication.sharedApplication;
        static AppDelegate *delegate;
        delegate = [AppDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
