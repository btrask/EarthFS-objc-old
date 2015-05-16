#import <openssl/sha.h>
#import <openssl/bio.h>
#import <openssl/evp.h>

#import "EFSController.h"
#import "BTErrno.h"
#import "EFSServerDispatcher.h"
#import "SLHTTPServer.h"

typedef struct __attribute__((packed)) {
	uint8_t hash[SHA_DIGEST_LENGTH];
	char mime[64];
} EFSIndexDBValue;

static NSString *SLHexEncode(uint8_t const *const restrict bytes, NSUInteger const l)
{
	char const *const restrict chars = "0123456789abcdef";
	char *const restrict hex = malloc(l * 2);
	for(NSUInteger i = 0; i < l; ++i) {
		uint8_t const byte = bytes[i];
		hex[i * 2] = chars[byte >> 4];
		hex[i * 2 + 1] = chars[byte & 0xf];
	}
	return [[[NSString alloc] initWithBytesNoCopy:hex length:l * 2 encoding:NSASCIIStringEncoding freeWhenDone:YES] autorelease];
}

@implementation EFSController

#pragma mark -EFSController

//- (NSString *)rawEntryPathForHash:(NSString *const)hash storeIfNew:(BOOL const)store
//{
//	// FIXME: We need to go from hash -> index.
//	return [_rawPath stringByAppendingFormat:@"/%@/%@", [idx substringWithRange:NSMakeRange(l - 2, 2)], idx];
//}
//- (uint32_t)entryIndexForHash:storeIfNew:;
//
//#pragma mark -
//
//- (NSArray *)entriesWithTags:(NSArray *const)tags
//{
//}
//- (void)addImplication:(NSString *const)implication toTag:(NSString *const)tag
//{
//}
//- (void)removeImplication:(NSString *const)implication fromTag:(NSString *const)tag
//{
//}

#pragma mark -EFSController(EFSSemiPrivate)

- (BOOL)getIndex:(out EFSIndex *const)outIndex forName:(NSString *const)name
{
	EFSIndex x = 0;
	char const *const str = [name UTF8String];
	DBT key = {
		.data = (void *)str,
		.ulen = strlen(str),
		.flags = DB_DBT_USERMEM | DB_DBT_READONLY,
	};
	DBT val = {
		.data = &x,
		.ulen = sizeof(x),
		.flags = DB_DBT_USERMEM,
	};
	int const err = _nameDB->get(_nameDB, NULL, &key, &val, kNilOptions);
	if(DB_NOTFOUND == err || val.size != val.ulen) return NO;
	BTErrno(err);
	if(outIndex) *outIndex = x;
	return YES;
}
- (BOOL)getHash:(out NSString **const)outHash MIMEType:(out NSString **const)outMIME forEntryWithIndex:(EFSIndex const)x
{
	DBT key = {
		.data = (void *)&x,
		.ulen = sizeof(x),
		.flags = DB_DBT_USERMEM | DB_DBT_READONLY,
	};
	EFSIndexDBValue y = {};
	DBT val = {
		.data = &y,
		.ulen = sizeof(y),
		.flags = DB_DBT_USERMEM,
	};
	int const err = _nameDB->get(_nameDB, NULL, &key, &val, kNilOptions);
	if(DB_NOTFOUND == err || val.size != val.ulen) return NO;
	BTErrno(err);
	y.mime[sizeof(y.mime)-1] = 0; // Ensure null termination.
	if(outHash) *outHash = SLHexEncode(y.hash, sizeof(y.hash));
	if(outMIME) *outMIME = [NSString stringWithUTF8String:y.mime];
	return YES;
}

- (DB_ENV *)env
{
	return _env;
}
- (BerkeleyDB *)tagDBWithName:(NSString *const)name
{
	return nil; // TODO: Implement.
}
- (BerkeleyDB *)tagDBWithIndex:(EFSIndex const)x
{
	NSString *const tagDBName = [NSString stringWithFormat:@"%ul", (unsigned long)x];
	BerkeleyDB *tagDB = [_tagDBByID objectForKey:tagDBName];
	if(!tagDB) {
		DB *rawDB = NULL;
		BTErrno(db_create(&rawDB, _env, kNilOptions));
		BTErrno(rawDB->open(rawDB, NULL, [_tagsDBPath fileSystemRepresentation], [tagDBName UTF8String], DB_BTREE, DB_CREATE | DB_THREAD, 0));
		tagDB = [[[BerkeleyDB alloc] initWithDB:rawDB] autorelease];
		[_tagDBByID setObject:tagDB forKey:tagDBName cost:0]; // TODO: Calculate cost based on DB size.
	}
	return tagDB;
}
- (NSString *)cacheDBPath
{
	return [[_cacheDBPath retain] autorelease];
}

#pragma mark -NSObject

- (id)init
{
	if(!(self = [super init])) return nil;

	NSString *const applicationSupportPath = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"EarthFS"];
	(void)[[NSFileManager defaultManager] createDirectoryAtPath:applicationSupportPath withIntermediateDirectories:YES attributes:nil error:NULL];

	db_env_create(&_env, kNilOptions);
	BTErrno(_env->open(_env, [applicationSupportPath fileSystemRepresentation], DB_INIT_LOCK | DB_INIT_MPOOL | DB_INIT_TXN | DB_THREAD, 0));

	NSString *const metadataDBPath = [applicationSupportPath stringByAppendingPathComponent:@"metaDB"];
	BTErrno(db_create(&_nameDB, _env, kNilOptions));
	BTErrno(_nameDB->open(_nameDB, NULL, [metadataDBPath fileSystemRepresentation], "names", DB_BTREE, DB_CREATE | DB_THREAD, 0));
	BTErrno(db_create(&_indexDB, _env, kNilOptions));
	BTErrno(_indexDB->open(_indexDB, NULL, [metadataDBPath fileSystemRepresentation], "indices", DB_BTREE, DB_CREATE | DB_THREAD, 0));

	_cacheDBPath = [[applicationSupportPath stringByAppendingPathComponent:@"cacheDB"] copy];

	_tagsDBPath = [[applicationSupportPath stringByAppendingPathComponent:@"tagsDB"] copy];
	_tagDBByID = [[NSCache alloc] init];

	_extensionByMIME = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"EFSExtensions" ofType:@"plist"]];

	_server = [[SLHTTPServer alloc] init];
	_dispatcher = [[EFSServerDispatcher alloc] init];
	[_server addListener:@"request" block:^(SLHTTPRequest *const req, SLHTTPResponse *const res) {
		[_dispatcher serveReq:req res:res];
	}];
	[_server listenOnPort:8001 address:INADDR_LOOPBACK/* INADDR_ANY */];

	return self;
}
- (void)dealloc
{
	[_server release];
	[_dispatcher release];
	BTErrno(_nameDB->close(_nameDB, kNilOptions));
	BTErrno(_indexDB->close(_indexDB, kNilOptions));
	[_cacheDBPath release];
	[_tagsDBPath release];
	[_tagDBByID release];
	[_extensionByMIME release];
	BTErrno(_env->close(_env, DB_FORCESYNC));
	[super dealloc];
}

@end

@implementation BerkeleyDB

- (id)initWithDB:(DB *const)db
{
	if((self = [super init])) {
		_DB = db;
	}
	return self;
}
- (DB *)DB
{
	return _DB;
}
- (void)dealloc
{
	_DB->close(_DB, kNilOptions);
	[super dealloc];
}

@end
