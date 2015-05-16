#import <db.h>

@class SLHTTPServer;
@class EFSServerDispatcher;
@class EFSQuery;

typedef uint64_t EFSIndex;

@interface EFSController : NSObject
{
	@private
	SLHTTPServer *_server;
	EFSServerDispatcher *_dispatcher;

	DB_ENV *_env;
	DB *_nameDB;
	DB *_indexDB;
	NSString *_tagsDBPath;
	NSCache *_tagDBByID;

	NSString *_cacheDBPath;
	NSCache *_queryByString; // TODO: Unused.

	NSDictionary *_extensionByMIME;

	NSLock *_indexLock;
	EFSIndex _index;
}

- (NSString *)pathForEntryWithHash:(NSString *const)hash MIMEType:(NSString *const)mime;
- (BOOL)getPath:(out NSString **const)outPath MIMEType:(out NSString **const)outMIME forEntryWithHash:(NSString *const)hash;
- (void)addEntryWithHash:(NSString *const)hash MIMEType:(NSString *const)mime;

- (void)addImplications:(NSArray *const)rels toName:(NSString *const)name;
- (void)removeImplications(NSArray *const)rels fromName:(NSString *const)name;

- (EFSQuery *)queryWithString:(NSString *const)string; // TODO: We should emit notifications to tell queries when to update...?

@end

@interface BerkeleyDB : NSObject
{
	@private
	DB *_DB;
}

- (id)initWithDB:(DB *const)db;
- (DB *)DB;

@end

@interface EFSController(EFSSemiPrivate) // FIXME: This interface is a mess... We just want to share methods with EFSQuery.

- (BOOL)getIndex:(out EFSIndex *const)outIndex forName:(NSString *const)name; // FIXME: This method should create indexes if they don't exist for new tags, so it should never fail.
- (BOOL)getHash:(out NSString **const)outHash MIMEType:(out NSString **const)outMIME forEntryWithIndex:(EFSIndex const)x;
- (DB_ENV *)env;
- (BerkeleyDB *)tagDBWithName:(NSString *const)name;
- (BerkeleyDB *)tagDBWithIndex:(EFSIndex const)x;
- (NSString *)cacheDBPath;

@end
