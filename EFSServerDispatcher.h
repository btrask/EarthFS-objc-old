#import "SLDispatcher.h"

@class SLHTTPRequest;
@class SLHTTPResponse;

typedef NSDictionary *const Dic;
typedef NSString *const Str;
typedef NSArray *const Arr;
typedef NSUInteger Idx;
typedef NSUInteger const Len;
typedef SLHTTPRequest *const Req;
typedef SLHTTPResponse *const Res;

@interface EFSServerDispatcher : SLDispatcher
{
}

- (void)serveReq:(Req)req res:(Res)res;

@end
