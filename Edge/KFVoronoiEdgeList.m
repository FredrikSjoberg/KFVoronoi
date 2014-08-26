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

#import "KFVoronoiEdgeList.h"

#import "KFVoronoiEdge.h"
#import "KFVoronoiHalfedge.h"

#pragma mark -
#pragma mark - Private
@interface KFVoronoiEdgeList ()

@property (nonatomic) float xDelta, xMin;
@property (nonatomic) int hashSize;
@property (nonatomic) uint currentEdgeIndex;
@property (nonatomic) uint currentVertexIndex;

@property (nonatomic, strong) NSMutableArray *hash;
@property (nonatomic, strong) KFVoronoiHalfedge *leftEnd;
@property (nonatomic, strong) KFVoronoiHalfedge *rightEnd;
@property (nonatomic, strong) KFVoronoiEdge *deleted;

#pragma mark - (Private Methods)
-(void) setupHash;
-(KFVoronoiHalfedge *) getHash:(int)b;

@end

#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiEdgeList

#pragma mark - Init
-(id) initWithXMin:(float)xValue andXDelta:(float)xDeltaValue withSize:(int)size
{
    if ((self = [super init])) {
        _xMin = xValue;
        _xDelta = xDeltaValue;
        _hashSize = 2*size;
        
        _currentEdgeIndex = 0;
        _currentVertexIndex = 0;
        
        [self setupHash];
    }
    return self;
}

#pragma mark - (Private Methods)
-(void) setupHash
{
    _hash = [[NSMutableArray alloc] initWithCapacity:self.hashSize];
    
    // Create Dummies
    _leftEnd = [[KFVoronoiHalfedge alloc] initDummy];
    _rightEnd = [[KFVoronoiHalfedge alloc] initDummy];
    
    _deleted = [[KFVoronoiEdge alloc] initDeletedPlaceholder];
    
    // Connect Dummies
    self.leftEnd.edgeListLeftNeighbor = nil;
    self.leftEnd.edgeListRightNeighbor = self.rightEnd;
    self.rightEnd.edgeListLeftNeighbor = self.leftEnd;
    self.rightEnd.edgeListRightNeighbor = nil;
    
    // LeftEnd at index 0
    [self.hash insertObject:self.leftEnd atIndex:0];
    for (int i = 0; i < self.hashSize - 1; i++) {
        // Null-objects for the rest
        [self.hash addObject:[NSNull null]];
    }
    // Except last object that is rightEnd
    [self.hash replaceObjectAtIndex:self.hashSize - 1 withObject:self.rightEnd];
}

-(KFVoronoiHalfedge *) getHash:(int)b
{
    KFVoronoiHalfedge *halfEdge;
	
	if (b < 0 || b >= self.hashSize) {
		return nil;
	}
    
    id cast = [self.hash objectAtIndex:b];
    
    if ([cast isMemberOfClass:[NSNull class]]) {
        halfEdge = nil;
    }
    else {
        halfEdge = cast;
    }
    
    if (halfEdge != nil && halfEdge.edge == self.deleted) {
		// This means the hash table points to a deleted halfedge and we need to patch it.
		[self.hash replaceObjectAtIndex:b withObject:[NSNull null]];
        return nil;
	}
    return halfEdge;
}

#pragma mark - FindLeftNeighbor
-(KFVoronoiHalfedge *) edgeListLeftNeighbor:(CGPoint)p
{
    int i, bucket;
	KFVoronoiHalfedge *halfEdge;
	
	// use hash table to get close to desired halfedge
	bucket = (p.x - self.xMin)/self.xDelta * self.hashSize;
	
    // make sure bucket does not exceed [0, hashSize]
	if (bucket < 0) {
		bucket = 0;
	}
	if (bucket >= self.hashSize) {
		bucket = self.hashSize - 1;
	}
	
    // Fetch the halfEdge
	halfEdge = [self getHash:bucket];
    
    if (halfEdge == nil) {
        for (i = 1; YES; ++i) {
            if ((halfEdge = [self getHash:(bucket - i)]) != nil) {
                break;
            }
            
            if ((halfEdge = [self getHash:(bucket + i)]) != nil) {
                break;
            }
        }
    }
	
	// Now search lineary for the correct halfEdge
	if (halfEdge == self.leftEnd || (halfEdge != self.rightEnd && [halfEdge isLeftOf:p])) {
		do {
			halfEdge = halfEdge.edgeListRightNeighbor;
		} while (halfEdge != self.rightEnd && [halfEdge isLeftOf:p]);
		halfEdge = halfEdge.edgeListLeftNeighbor;
	}
	else {
		do {
			halfEdge = halfEdge.edgeListLeftNeighbor;
		} while (halfEdge != self.leftEnd && ![halfEdge isLeftOf:p]);
	}
	
	// update the hash table and reference counts
	if ((bucket > 0) && (bucket < (self.hashSize - 1))) {
		[self.hash replaceObjectAtIndex:bucket withObject:halfEdge];
	}
	return halfEdge;
}

#pragma mark - EdgeIndex
-(uint) getNextEdgeIndex
{
    uint idx = self.currentEdgeIndex;
    self.currentEdgeIndex++;
    return idx;
}

-(uint) getNextVertexIndex
{
    uint idx = self.currentVertexIndex;
    self.currentVertexIndex ++;
    return idx;
}

#pragma mark - Insert
-(void) insertHalfEdge:(KFVoronoiHalfedge *)newHalfedge toTheRightOf:(KFVoronoiHalfedge *)lb
{
    newHalfedge.edgeListLeftNeighbor = lb;
	newHalfedge.edgeListRightNeighbor = lb.edgeListRightNeighbor;
	lb.edgeListRightNeighbor.edgeListLeftNeighbor = newHalfedge;
	lb.edgeListRightNeighbor = newHalfedge;
}

-(void) removeHalfEdge:(KFVoronoiHalfedge *)halfEdge
{
    halfEdge.edgeListLeftNeighbor.edgeListRightNeighbor = halfEdge.edgeListRightNeighbor;
	halfEdge.edgeListRightNeighbor.edgeListLeftNeighbor = halfEdge.edgeListLeftNeighbor;
    
    [halfEdge setEdgeToDeletedEdge:self.deleted];
    
	halfEdge.edgeListLeftNeighbor = nil;
	halfEdge.edgeListRightNeighbor = nil;
}

@end
