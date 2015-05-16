#import "EFSController.h"

typedef struct { EFSIndex location; NSUInteger length; } EFSRange;

@interface EFSQuery : NSObject
{
	@private
	EFSController *_controller;
}

- (id)initWithController:(EFSController *const)controller;
- (EFSController *)controller;

- (NSArray *)hashesInRange:(EFSRange const)range;

@end

@interface EFSQuery(EFSAbstract)

- (void)update;
- (DB *)DB;

@end

@interface EFSCachedQuery : EFSQuery
{
	@private
	DB *_cacheDB;
}
@end

@interface EFSUnionQuery : EFSCachedQuery
{
	@private
	NSArray *_subqueries;
}

- (id)initWithController:(EFSController *const)controller subqueries:(NSArray *const)subqueries;

@end

@interface EFSIntersectionQuery : EFSCachedQuery
{
	@private
	NSArray *_subqueries;
}

- (id)initWithController:(EFSController *const)controller subqueries:(NSArray *const)subqueries;

@end

@interface EFSDifferenceQuery : EFSCachedQuery
{
	@private
	EFSQuery *_minuend;
	EFSQuery *_subtrahend;
}

- (id)initWithController:(EFSController *const)controller minuend:(EFSQuery *const)minuend subtrahend:(EFSQuery *const)subtrahend;

@end

@interface EFSNameQuery : EFSQuery
{
	@private
	NSString *_name;
	BerkeleyDB *_tagDB;
}

- (id)initWithController:(EFSController *const)controller name:(NSString *const)name;

@end
