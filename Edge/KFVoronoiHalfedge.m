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

#import "KFVoronoiHalfedge.h"

#import "KFVoronoiEdge.h"
#import "KFVoronoiVertex.h"
#import "KFVoronoiSite.h"
#import "KFVoronoi.h"


#pragma mark -
#pragma mark - Private
@interface KFVoronoiHalfedge ()

@property (nonatomic, strong, readwrite) KFVoronoiEdge *edge;
@property (nonatomic, strong, readwrite) NSString *leftRight;

@property (nonatomic, readwrite) float yStar;

@end


#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiHalfedge


#pragma mark - Init
-(id) initWithEdge:(KFVoronoiEdge *)anEdge andLeftRight:(NSString *)lr
{
    if ((self = [super init])) {
        _edge = anEdge;
        _leftRight = lr;
        
        _nextInPriorityQueue = nil;
        _vertex = nil;
    }
    return self;
}

-(id) initDummy
{
    return [self initWithEdge:nil andLeftRight:nil];
}

#pragma mark - LeftOf
-(BOOL) isLeftOf:(CGPoint)p
{
    KFVoronoiSite *topSite;
	BOOL rightOfSite, above, fast;
	float dxp, dyp, dxs, t1, t2, t3, yl;
	
    // Fetch rightSite
	topSite = [self.edge rightSite];
    
	rightOfSite = (p.x > topSite.point.x);
	
	if (rightOfSite && [self.leftRight kfMatches:kKFVoronoiOrientationLeft]) {
		return YES;
	}
	if (!rightOfSite && [self.leftRight kfMatches:kKFVoronoiOrientationRight]) {
		return NO;
	}
	
	if (self.edge.a == 1.0) {
		dyp = p.y - topSite.point.y;
		dxp = p.x - topSite.point.x;
        
		fast = NO;
		
        if ((!rightOfSite && self.edge.b < 0.0) || (rightOfSite && self.edge.b >= 0.0)) {
			above = (dyp >= self.edge.b * dxp);
			fast = above;
		}
		else {
			above = (p.x + p.y * self.edge.b > self.edge.c);
			if (self.edge.b < 0.0) {
				above = !above;
			}
			if (!above) {
				fast = YES;
			}
		}
        
		if (!fast) {
			dxs = topSite.point.x - self.edge.leftSite.point.x;
			above = ( (self.edge.b * (dxp * dxp - dyp * dyp)) < (dxs * dyp * (1.0 + 2.0 * dxp/dxs + self.edge.b * self.edge.b)) );
			if (self.edge.b < 0.0)
			{
				above = !above;
			}
		}
	}
	else {
        // edge.b == 1.0
		yl = self.edge.c - self.edge.a * p.x;
		t1 = p.y - yl;
		t2 = p.x - topSite.point.x;
		t3 = yl - topSite.point.y;
		above = (t1 * t1 > t2 * t2 + t3 * t3);
	}
	return ([self.leftRight kfMatches:kKFVoronoiOrientationLeft] ? above : !above);
}

#pragma mark - SetYStar
-(void) setYStarFromVertex:(KFVoronoiVertex *)aVertex andSite:(KFVoronoiSite *)aSite
{
    float value = aVertex.point.y + ccpDistance(aSite.point, aVertex.point);
    
    [self setYStar:value];
}

#pragma mark Helper
+(NSString *) otherLeftRight:(NSString *)leftRight
{
    if ([leftRight kfMatches:kKFVoronoiOrientationLeft]) {
        return kKFVoronoiOrientationRight;
    }
    else if ([leftRight kfMatches:kKFVoronoiOrientationRight]) {
        return kKFVoronoiOrientationLeft;
    }
    return nil;
}

#pragma mark - DeletedEdge
-(void) setEdgeToDeletedEdge:(KFVoronoiEdge *)deleted
{
    if (deleted.leftSite == nil &&
        deleted.rightSite == nil &&
        deleted.leftVertex == nil &&
        deleted.rightVertex == nil) {
        
        [self setEdge:deleted];
    }
}

@end
