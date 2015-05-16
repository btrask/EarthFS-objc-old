#import "EFSQuery.h"
#import "BTErrno.h"

@implementation EFSQuery

#pragma mark -EFSQuery

- (id)initWithController:(EFSController *const)controller
{
	if((self = [super init])) {
		_controller = controller;
	}
	return self;
}
- (EFSController *)controller { return _controller; }

#pragma mark -

- (NSArray *)hashesInRange:(EFSRange const)range
{
	NSMutableArray *const r = [NSMutableArray array];
	DB *const db = [self DB];
	EFSIndex i = 0;
	DBT key = {
		.data = &key,
		.ulen = sizeof(key),
		.flags = DB_DBT_USERMEM | DB_DBT_READONLY,
	};
	DBT val = {
		.data = NULL,
		.ulen = 0,
		.flags = DB_DBT_USERMEM,
	};
	EFSIndex const max = range.location + range.length;
	for(i = range.location; i < max; ++i) {
		BTErrno(db->get(db, NULL, &key, &val, kNilOptions));
	}
	return r;
}

@end

@implementation EFSCachedQuery

- (id)initWithController:(EFSController *const)controller
{
	if((self = [super initWithController:controller])) {
		BTErrno(db_create(&_cacheDB, [controller env], kNilOptions));
		BTErrno(_cacheDB->open(_cacheDB, NULL, [[controller cacheDBPath] fileSystemRepresentation], [[self description] UTF8String], DB_BTREE, DB_CREATE | DB_THREAD | DB_RECNUM, 0));
	}
	return self;
}
- (DB *)DB { return _cacheDB; }

#pragma mark -NSObject

- (void)dealloc
{
	BTErrno(_cacheDB->close(_cacheDB, kNilOptions));
	[super dealloc];
}

@end

@implementation EFSUnionQuery

#pragma mark -EFSUnionQuery

- (id)initWithController:(EFSController *const)controller subqueries:(NSArray *const)subqueries
{
	if((self = [super initWithController:controller])) {
		_subqueries = [subqueries copy]; // TODO: Sort from largest to smallest?
	}
	return self;
}

#pragma mark -EFSQuery(EFSAbstract)

- (void)update
{
	for(EFSQuery *const q in _subqueries) [q update];
	// TODO: Rebuild cache.
}

#pragma mark -NSObject

- (void)dealloc
{
	[_subqueries release];
	[super dealloc];
}

#pragma mark -NSObject<NSObject>

- (NSString *)description
{
	return [NSString stringWithFormat:@"(%@)", [_subqueries componentsJoinedByString:@" | "]];
}

@end

@implementation EFSIntersectionQuery

#pragma mark -EFSIntersectionQuery

- (id)initWithController:(EFSController *const)controller subqueries:(NSArray *const)subqueries
{
	if((self = [super initWithController:controller])) {
		_subqueries = [subqueries copy]; // TODO: Sort from smallest to largest?
	}
	return self;
}

#pragma mark -EFSQuery(EFSAbstract)

- (void)update
{
	for(EFSQuery *const q in _subqueries) [q update];
	// TODO: Rebuild cache.
}

#pragma mark -NSObject

- (void)dealloc
{
	[_subqueries release];
	[super dealloc];
}

#pragma mark -NSObject<NSObject>

- (NSString *)description
{
	return [NSString stringWithFormat:@"(%@)", [_subqueries componentsJoinedByString:@" & "]];
}

@end

@implementation EFSDifferenceQuery

#pragma mark -EFSDifferenceQuery

- (id)initWithController:(EFSController *const)controller minuend:(EFSQuery *const)minuend subtrahend:(EFSQuery *const)subtrahend
{
	if((self = [super initWithController:controller])) {
		_minuend = [minuend retain];
		_subtrahend = [subtrahend retain];
	}
	return self;
}

#pragma mark -EFSQuery(EFSAbstract)

- (void)update
{
	[_minuend update];
	[_subtrahend update];
	// TODO: Rebuild cache.
}

#pragma mark -NSObject

- (void)dealloc
{
	[_minuend release];
	[_subtrahend release];
	[super dealloc];
}

#pragma mark -NSObject<NSObject>

- (NSString *)description
{
	return [NSString stringWithFormat:@"(%@ - %@)", _minuend, _subtrahend];
}

@end

@implementation EFSNameQuery

#pragma mark -EFSTagQuery

- (id)initWithController:(EFSController *const)controller name:(NSString *const)name
{
	if((self = [super initWithController:controller])) {
		_name = [name copy];
		_tagDB = [[controller tagDBWithName:name] retain];
	}
	return self;
}

#pragma mark -EFSQuery(EFSAbstract)

- (void)update {}
- (DB *)DB { return [_tagDB DB]; }

#pragma mark -NSObject

- (void)dealloc
{
	[_name release];
	[_tagDB release];
	[super dealloc];
}

#pragma mark -NSObject<NSObject>

- (NSString *)description
{
	return [[_name retain] autorelease];
}

@end
