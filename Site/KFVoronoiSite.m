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

#import "KFVoronoiSite.h"

#import "KFVoronoiEdge.h"
#import "KFVoronoiVertex.h"
#import "KFVoronoiHalfedge.h"
#import "KFVoronoi.h"

#define kKFVoronoiSiteEpsilon 0.05f
#define kKFVoronoiSiteNanPoint ccp(NAN,NAN)

typedef enum {
    kKFVoronoiSiteWindingClockwise,
    kKFVoronoiSiteWindingCounterClockwise,
    kKFVoronoiSiteWindingUndefined,
} kKFVoronoiSiteWinding;

static int gKF_BOUNDS_TOP = 1;
static int gKF_BOUNDS_BOTTOM = 2;
static int gKF_BOUNDS_LEFT = 4;
static int gKF_BOUNDS_RIGHT = 8;

#pragma mark -
#pragma mark - Private
@interface KFVoronoiSite ()

@property (nonatomic, strong) NSMutableArray *edges;
@property (nonatomic, strong) NSMutableArray *orientations;
@property (nonatomic, strong) NSMutableArray *region;

@end


#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiSite

#pragma mark - Edges
-(void) addEdge:(KFVoronoiEdge *)edge
{
    if (edge) {
        if (!_edges) {
            _edges = [[NSMutableArray alloc] init];
        }
        
        [self.edges addObject:edge];
    }
}


#pragma mark - Reorder
-(void) reorderEdges
{
    NSUInteger numEdges = self.edges.count;
    if (numEdges == 0)
        return; // TODO: Dont we need to initiate an empty orientations array anyway?
    
    
    // Initiate Orientations
    _orientations = [[NSMutableArray alloc] init];
    
    CGPoint firstPoint, lastPoint;
    CGPoint leftPoint, rightPoint;
    NSString *edgeOrientation = nil;
    
    // Create a queue of edges to reorder
    NSMutableSet *processed = [[NSMutableSet alloc] init];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    NSUInteger current = 0;
    while (current < numEdges) {
        for (KFVoronoiEdge *next in self.edges) {
            if (![processed containsObject:next]) {
                leftPoint = next.leftVertex.point;
                rightPoint = next.rightVertex.point;
                
                // Make sure we dont include any edges that have invalid/garbage vertices
                if (CGPointEqualToPoint(leftPoint, kKFVoronoiSiteNanPoint) || CGPointEqualToPoint(rightPoint, kKFVoronoiSiteNanPoint)) {
                    NSLog(@"KFVoronoiSite Infinity Vertex %@ %@",NSStringFromCGPoint(leftPoint),NSStringFromCGPoint(rightPoint));
                    continue;
                }
                
                // The edge is valid, process it
                if (current == 0) {
                    // First edge is set to have "Left" orientation
                    edgeOrientation = kKFVoronoiOrientationLeft;
                    
                    // Add it to result
                    [result addObject:next];
                    
                    // Set the Edge Orientation
                    [self.orientations addObject:edgeOrientation];
                    
                    // Update first/last vertex
                    firstPoint = leftPoint;
                    lastPoint = rightPoint;
                    
                    // Mark as processed
                    current++;
                    [processed addObject:next];
                }
                else {
                    // Previously processed egdes exist
                    if (CGPointEqualToPoint(leftPoint, lastPoint)) {
                        // Edge is RIGHT of lastPoint
                        // Add it to result
                        [result addObject:next];
                        
                        // Left orientation
                        [self.orientations addObject:kKFVoronoiOrientationLeft];
                        
                        // Update first/last vertex
                        lastPoint = rightPoint;
                        
                        // Mark as processed
                        current++;
                        [processed addObject:next];
                    }
                    else if (CGPointEqualToPoint(rightPoint, firstPoint)) {
                        // Edge is LEFT of firstPoint
                        // Insert first in result
                        [result insertObject:next atIndex:0];
                        
                        // Left orientation
                        [self.orientations insertObject:kKFVoronoiOrientationLeft atIndex:0];
                        
                        // Update first/last vertex
                        firstPoint = leftPoint;
                        
                        // Mark as processed
                        current++;
                        [processed addObject:next];
                        
                    }
                    else if (CGPointEqualToPoint(leftPoint, firstPoint)) {
                        // Edge is LEFT of firstPoint
                        // Insert first in result
                        [result insertObject:next atIndex:0];
                        
                        // Right orientation
                        [self.orientations insertObject:kKFVoronoiOrientationRight atIndex:0];
                        
                        // Update first/last vertex
                        firstPoint = rightPoint;
                        
                        // Mark as processed
                        current++;
                        [processed addObject:next];
                    }
                    else if (CGPointEqualToPoint(rightPoint, lastPoint)) {
                        // Edge is RIGHT of lastPoint
                        // Add it to result
                        [result addObject:next];
                        
                        // Left orientation
                        [self.orientations addObject:kKFVoronoiOrientationRight];
                        
                        // Update first/last vertex
                        lastPoint = leftPoint;
                        
                        // Mark as processed
                        current++;
                        [processed addObject:next];
                    }
                }
                
            }
        }
    }
    
    // Update Edge array
    [[self edges] removeAllObjects];
    [[self edges] addObjectsFromArray:result];
}


#pragma mark - Region
-(void) calculateRegionWithinBounds:(CGRect)bounds
{
    if (!self.edges || self.edges.count == 0) {
		NSLog(@"Site getRegionWithinBounds: no region");
	}
    else {
        if (!self.orientations) {
            // Make sure Edge Orientations has been set
            [self reorderEdges];
        }
        
        // Set new region
        [self clipToBounds:bounds];
        
        
        if (self.region) {
            // Check Winding
            if ([self winding] == kKFVoronoiSiteWindingClockwise) {
                [[self region] reverseArray];
            }
        }
    }
}

-(NSArray *) getRegionWithinBounds:(CGRect)bounds
{
    if (!self.region)
        [self calculateRegionWithinBounds:bounds];
    
    if (self.region)
        return [NSArray arrayWithArray:self.region];
    
    NSLog(@"KFVoronoiSite Warning: getRegionWithinBounds impossible");
    return [NSArray array];
}

-(kKFVoronoiSiteWinding) winding
{
    float signedDoubleAreaVal = [self signedDoubleArea];
	
	if (signedDoubleAreaVal < 0) {
		return kKFVoronoiSiteWindingClockwise;
	}
	else if (signedDoubleAreaVal > 0) {
		return kKFVoronoiSiteWindingCounterClockwise;
	}
	else {
		return kKFVoronoiSiteWindingUndefined;
	}
}


-(float) signedDoubleArea
{
    int index;
	int nextIndex;
	int n = self.region.count;
	
	CGPoint point;
	CGPoint next;
	
	float signedDoubleArea = 0.0;
	for (index = 0; index < n; index++) {
		
		nextIndex = (index + 1) % n;
		
		point = [[self.region objectAtIndex:index] CGPointValue];
		next = [[self.region objectAtIndex:nextIndex] CGPointValue];
		
		signedDoubleArea += point.x * next.y - next.x * point.y;
	}
	return signedDoubleArea;
}

#pragma mark - ClipToBounds
-(void) clipToBounds:(CGRect)bounds
{
    int n = self.edges.count;
	int i = 0;
	KFVoronoiEdge *edge;
    
    // Grab the first relevant (ie visible) edge
	while (i < n && ([edge = [self.edges objectAtIndex:i] visible] == NO)) {
		++i;
	}
    
    // Make sure we actuly have any visible edges
	if (i == n) {
        // If not, return without clipping to bounds
		NSLog(@"VoronoiSite clipToBounds: No visible edges: %@ %@",self, NSStringFromCGPoint(self.point));
        for (KFVoronoiEdge *v in self.edges) {
            NSLog(@"%@ %@ %@",v, NSStringFromCGPoint(v.leftVertex.point), NSStringFromCGPoint(v.rightVertex.point));
        }
        
        return;
	}
    
    // Allocate Region Array
    _region = [[NSMutableArray alloc] init];
    
    // Grab the first relevant edge
    edge = [self.edges objectAtIndex:i];
    NSString *orientation = [self.orientations objectAtIndex:i];
    NSDictionary *edgeDict = [edge clippedEnds];
    
    // Add its vertices to region (in the correct order
    [self.region addObject:[edgeDict valueForKey:orientation]];
    [self.region addObject:[edgeDict valueForKey:[KFVoronoiHalfedge otherLeftRight:orientation]]];
    
    // Look through the rest of the edges and do the same
    for (int j = i + 1; j < n; j++) {
        edge = [self.edges objectAtIndex:j];
        
        if ([edge visible]) {
            // Only visible edges should be processed
            [self buildRegionFromBounds:bounds withIndex:j closeUp:NO];
        }
    }
    [self buildRegionFromBounds:bounds withIndex:i closeUp:YES];
}

-(void) buildRegionFromBounds:(CGRect)bounds withIndex:(uint)j closeUp:(BOOL)closingUp
{
    // Find the region point just before the current index, j
    CGPoint rightPoint = [[self.region objectAtIndex:(self.region.count - 1)] CGPointValue];
	
    // Grab the edge for current index. Then grab the related point
	KFVoronoiEdge *newEdge = [self.edges objectAtIndex:j];
	NSString *newOrientation = [self.orientations objectAtIndex:j];
	NSDictionary *edgeDict = [newEdge clippedEnds];
	CGPoint newPoint = [[edgeDict valueForKey:newOrientation] CGPointValue];
    
    
	if (![self epsilonSiteDistance:rightPoint p1:newPoint]) {
		if (rightPoint.x != newPoint.x && rightPoint.y != newPoint.y) {
			int rightCheck = [self checkBounds:bounds forPoint:rightPoint];
			int newCheck = [self checkBounds:bounds forPoint:newPoint];
			
			float px;
			float py;
			if (rightCheck & gKF_BOUNDS_RIGHT)
			{
				px = bounds.origin.x + CGRectGetWidth(bounds);
				if (newCheck & gKF_BOUNDS_BOTTOM) {
					py = bounds.origin.y + CGRectGetHeight(bounds);
					CGPoint newP = CGPointMake(px, py);
					[self.region addObject:[NSValue valueWithCGPoint:newP]];
				}
				else if	(newCheck & gKF_BOUNDS_TOP){
					py = bounds.origin.y;
					CGPoint newP = CGPointMake(px, py);
					[self.region addObject:[NSValue valueWithCGPoint:newP]];
				}
				else if (newCheck & gKF_BOUNDS_LEFT) {
					if ((rightPoint.y - bounds.origin.y + newPoint.y - bounds.origin.y) < CGRectGetHeight(bounds)) {
						py = bounds.origin.y;
					}
					else {
						py = bounds.origin.y + CGRectGetHeight(bounds);
					}
                    
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(bounds.origin.x, py)]];
				}
			}
			else if (rightCheck & gKF_BOUNDS_LEFT)
			{
				px = bounds.origin.x;
				if (newCheck & gKF_BOUNDS_BOTTOM) {
					py = bounds.origin.y + CGRectGetHeight(bounds);
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
				}
				else if (newCheck & gKF_BOUNDS_TOP) {
					py = bounds.origin.y;
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
				}
				else if (newCheck & gKF_BOUNDS_RIGHT) {
					if ((rightPoint.y - bounds.origin.y + newPoint.y - bounds.origin.y) < CGRectGetHeight(bounds)) {
						py = bounds.origin.y;
					}
					else {
						py = bounds.origin.y + CGRectGetHeight(bounds);
					}
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake((bounds.origin.x + CGRectGetWidth(bounds)), py)]];
                    
				}
			}
			else if (rightCheck & gKF_BOUNDS_TOP)
			{
				py = bounds.origin.y;
				if (newCheck & gKF_BOUNDS_RIGHT) {
					px = bounds.origin.x + CGRectGetWidth(bounds);
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
				}
				else if (newCheck & gKF_BOUNDS_LEFT) {
					px = bounds.origin.x;
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
				}
				else if (newCheck & gKF_BOUNDS_BOTTOM) {
					if ((rightPoint.x - bounds.origin.x + newPoint.x - bounds.origin.x) < CGRectGetWidth(bounds)) {
						px = bounds.origin.x;
					}
					else {
						px = bounds.origin.x + CGRectGetWidth(bounds);
					}
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, (bounds.origin.y + CGRectGetHeight(bounds)))]];
				}
			}
			else if (rightCheck & gKF_BOUNDS_BOTTOM)
			{
				py = bounds.origin.y + CGRectGetHeight(bounds);
				if (newCheck & gKF_BOUNDS_RIGHT) {
					px = bounds.origin.x + CGRectGetWidth(bounds);
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
				}
				else if (newCheck & gKF_BOUNDS_LEFT) {
					px = bounds.origin.x;
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
				}
				else if (newCheck & gKF_BOUNDS_TOP) {
					if ((rightPoint.x - bounds.origin.x + newPoint.x - bounds.origin.x) < CGRectGetWidth(bounds)) {
						px = bounds.origin.x;
					}
					else {
						px = bounds.origin.x + CGRectGetWidth(bounds);
					}
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, py)]];
					[self.region addObject:[NSValue valueWithCGPoint:CGPointMake(px, bounds.origin.y)]];
				}
			}
		}
        
		if (closingUp) {
			return;
		}
		[self.region addObject:[NSValue valueWithCGPoint:newPoint]];
	}
    
	CGPoint newRightPoint = [[edgeDict valueForKey:[KFVoronoiHalfedge otherLeftRight:newOrientation]] CGPointValue];
	
	CGPoint firstPoint = [[self.region objectAtIndex:0] CGPointValue];
    
	if (![self epsilonSiteDistance:firstPoint p1:newRightPoint]) {
		[self.region addObject:[NSValue valueWithCGPoint:newRightPoint]];
	}
}

#pragma mark - Helper
-(BOOL) epsilonSiteDistance:(CGPoint)p0 p1:(CGPoint)p1
{
    return (ccpDistance(p0, p1) < kKFVoronoiSiteEpsilon);
}

-(int) checkBounds:(CGRect)bounds forPoint:(CGPoint)point
{
    int value = 0;
	if (point.x == bounds.origin.x) // bounds.left = top-left x coord of bounds
	{
		value |= gKF_BOUNDS_LEFT;
	}
	if (point.x == bounds.origin.x + CGRectGetWidth(bounds)) // bounds.right = sum of x coord and bounds width
	{
		value |= gKF_BOUNDS_RIGHT;
	}
	if (point.y == bounds.origin.y)	// bounds.top = top-left y coord of bounds
	{
		value |= gKF_BOUNDS_TOP;
	}
	if (point.y == bounds.origin.y + CGRectGetHeight(bounds))	// bounds.bottom = sum of y coord and bounds height
	{
		value |= gKF_BOUNDS_BOTTOM;
	}
	return value;
}

@end
