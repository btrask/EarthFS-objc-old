#import "EFSServerDispatcher.h"
#import "SLHTTPServer.h"

static Arr SLComponentsFromPath(Str path)
{
	Len a = [path hasPrefix:@"/"] ? 1 : 0;
	Len b = [path hasSuffix:@"/"] ? 1 : 0;
	Len l = [path length];
	if(a + b >= l) return [NSArray array];
	Str trimmed = [path substringWithRange:NSMakeRange(a, l - a - b)];
	return [trimmed componentsSeparatedByString:@"/"];
}
static Str SLPathFromComponents(Arr components)
{
	if(![components count]) return @"";
	return [@"/" stringByAppendingString:[components componentsJoinedByString:@"/"]];
}

@implementation EFSServerDispatcher

- (void)serveReq:(Req)req res:(Res)res
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
		Str params = [[req URL] parameterString];
		Str path = [[[req URL] path] stringByAppendingString:params ? [@";" stringByAppendingString:params] : @""]; // This is still an ugly hack.
		Arr components = SLComponentsFromPath(path);
		if([components containsObject:@".."]) {
			[self serveUnknownReq:req res:res];
			return;
		}
		[self serveReq:req res:res root:[NSDictionary dictionaryWithObjectsAndKeys:
			path, @"path",
			components, @"components",
			nil]];
	});
}

@end
