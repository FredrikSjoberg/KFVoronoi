/*
 * The author of this software is Steven Fortune. Copyright (c) 1994 by AT&T
 * Bell Laboratories.
 * Permission to use, copy, modify, and distribute this software for any
 * purpose without fee is hereby granted, provided that this entire notice
 * is included in all copies of any software which is or includes a copy
 * or modification of this software and in all copies of the supporting
 * documentation for such software.
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
 * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
 */
/*
 MIT License
 
 Copyright (c) 2011 Fredrik Sjöberg
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "KFVoronoiHEPQ.h"

#import "KFVoronoiHalfedge.h"
#import "KFVoronoiVertex.h"

#pragma mark -
#pragma mark - Private
@interface KFVoronoiHEPQ ()

@property (nonatomic, strong) NSMutableArray *hashHEPQ;
@property (nonatomic) int HEPQcount;
@property (nonatomic) int minBucket;
@property (nonatomic) int hashSize;
@property (nonatomic) float yMin;
@property (nonatomic) float yDelta;

#pragma mark - (Private Methods)
-(void) setupHash;
-(BOOL) isEmpty:(int)bucket;
-(void) adjustMinBucket;
-(int) bucket:(KFVoronoiHalfedge *)halfEdge;

@end



#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiHEPQ

#pragma mark - Init
-(id) initWithYMin:(float)yValue andYDelta:(float)yDeltaValue withSize:(int)size
{
    if ((self = [super init])) {
        _yMin = yValue;
        _yDelta = yDeltaValue;
        
        _hashSize = 4*size;
        _HEPQcount = 0;
        _minBucket = 0;
        
        [self setupHash];
    }
    return self;
}

#pragma mark - (Private Methods)
-(void) setupHash
{
    _hashHEPQ = [[NSMutableArray alloc] initWithCapacity:self.hashSize];
    
    for (int i = 0; i < self.hashSize; i++) {
        // Create dummy (nil ref he)
        KFVoronoiHalfedge *he = [[KFVoronoiHalfedge alloc] initDummy];
        
        // Insert at index i
        [[self hashHEPQ] addObject:he];
    }
}

-(BOOL) isEmpty:(int)bucket
{
    KFVoronoiHalfedge *he = [self.hashHEPQ objectAtIndex:bucket];
	return (he.nextInPriorityQueue == nil);
}

-(void) adjustMinBucket
{
    while (self.minBucket < (self.hashSize -1) && [self isEmpty:self.minBucket]) {
		++self.minBucket;
	}
}

-(int) bucket:(KFVoronoiHalfedge *)halfEdge
{
	int theBucket = (halfEdge.yStar - self.yMin)/self.yDelta * self.hashSize;
    
	if (theBucket < 0) {
		theBucket = 0;
	}
	if (theBucket >= self.hashSize) {
		theBucket = self.hashSize - 1;
	}
    
	return theBucket;
}


#pragma mark - Heap
-(BOOL) empty
{
    
    return (self.HEPQcount == 0);
}

-(CGPoint) minPoint
{
    [self adjustMinBucket];
	KFVoronoiHalfedge *halfEdge = [self.hashHEPQ objectAtIndex:self.minBucket];
	KFVoronoiHalfedge *answer = halfEdge.nextInPriorityQueue;
	
	return CGPointMake(answer.vertex.point.x, answer.yStar);
}

#pragma mark - Insert/RemoveHalfEdge
-(void) insertHalfEdge:(KFVoronoiHalfedge *)halfEdge
{
    KFVoronoiHalfedge *previous, *next;
	int insertionBucket = [self bucket:halfEdge];
	
	if (insertionBucket < self.minBucket) {
		self.minBucket = insertionBucket;
	}
	previous = [self.hashHEPQ objectAtIndex:insertionBucket];
	
	while (((next = previous.nextInPriorityQueue) != nil) &&
           (halfEdge.yStar > next.yStar || (halfEdge.yStar == next.yStar && halfEdge.vertex.point.x > next.vertex.point.x))) {
		previous = next;
	}
    
	halfEdge.nextInPriorityQueue = previous.nextInPriorityQueue;
	previous.nextInPriorityQueue = halfEdge;
	++self.HEPQcount;
}

-(void) removeHalfEdge:(KFVoronoiHalfedge *)halfEdge
{
    KFVoronoiHalfedge *previous;
	int removalBucket = [self bucket:halfEdge];
	
	if (halfEdge.vertex != nil) {
		previous = [self.hashHEPQ objectAtIndex:removalBucket];
		while (previous.nextInPriorityQueue != halfEdge) {
			previous = previous.nextInPriorityQueue;
		}
        
		previous.nextInPriorityQueue = halfEdge.nextInPriorityQueue;
		self.HEPQcount--;
		halfEdge.vertex = nil;
		halfEdge.nextInPriorityQueue = nil;
	}
}

-(KFVoronoiHalfedge *) extractMin
{
    KFVoronoiHalfedge *testHalfEdge = [self.hashHEPQ objectAtIndex:self.minBucket];
	KFVoronoiHalfedge *answer = testHalfEdge.nextInPriorityQueue;
	
	testHalfEdge.nextInPriorityQueue = answer.nextInPriorityQueue;
	
	self.HEPQcount--;
	answer.nextInPriorityQueue = nil;
	
	return answer;
}

@end
