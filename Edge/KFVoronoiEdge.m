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

#import "KFVoronoiEdge.h"

#import "KFVoronoiSite.h"
#import "KFVoronoiVertex.h"
#import "KFVoronoiLine.h"
#import "KFVoronoi.h"


#pragma mark -
#pragma mark - Private
@interface KFVoronoiEdge ()
@property (nonatomic, strong, readwrite) KFVoronoiSite *leftSite, *rightSite;
@property (nonatomic, readwrite) float a, b, c;

@property (nonatomic, strong) NSMutableDictionary *clippedVertices;

@end


#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiEdge


#pragma mark - Init
-(id) initWithSite:(KFVoronoiSite *)site0 andSite:(KFVoronoiSite *)site1 index:(uint)index
{
    if (site0 && site1) {
        if ((self = [super initWithIndex:index])) {
            [self setLeftSite:site0];
            [self setRightSite:site1];
            
            _leftVertex = nil;
            _rightVertex = nil;
            
            [self calculateEdgeEquation];
        }
        return self;
	}
    return nil;
}

-(id) initDeletedPlaceholder
{
    if ((self = [super init])) {
        
        [self setIndex:0];
        
        _leftSite = nil;
        _rightSite = nil;
        
        _leftVertex = nil;
        _rightVertex = nil;
    }
    return self;
}

#pragma mark - (Setup)
-(void) calculateEdgeEquation
{
    float dx, dy, absdx, absdy;
    float aNew, bNew, cNew;
    
    dx = self.rightSite.point.x - self.leftSite.point.x;
    dy = self.rightSite.point.y - self.leftSite.point.y;
    
    absdx = ((dx > 0) ? dx : -dx);
    absdy = ((dy > 0) ? dy : -dy);
    
    cNew = self.leftSite.point.x * dx + self.leftSite.point.y * dy + (dx * dx + dy * dy) * 0.5;
    if (absdx > absdy) {
        aNew = 1.0; bNew = dy/dx; cNew /= dx;
    }
    else {
        bNew = 1.0; aNew = dx/dy; cNew /= dy;
    }
    
    _a = aNew;
    _b = bNew;
    _c = cNew;
}

#pragma mark - (Overrides)
-(void) setLeftSite:(KFVoronoiSite *)leftSite
{
    _leftSite = leftSite;
    
    [leftSite addEdge:self];
}

-(void) setRightSite:(KFVoronoiSite *)rightSite
{
    _rightSite = rightSite;
    
    [rightSite addEdge:self];
}

#pragma mark - Site
-(KFVoronoiSite *) getSite:(NSString *)leftRight
{
    if ([leftRight kfMatches:kKFVoronoiOrientationLeft]) {
        return [self leftSite];
    }
    else if ([leftRight kfMatches:kKFVoronoiOrientationRight]) {
        return [self rightSite];
    }
    return nil;
}

#pragma mark - Vertices
-(void) setEdgeVertex:(KFVoronoiVertex *)v asLeftRight:(NSString *)leftRight
{
    if ([leftRight kfMatches:kKFVoronoiOrientationLeft]) {
		self.leftVertex = v;
	}
	else if ([leftRight kfMatches:kKFVoronoiOrientationRight]) {
		self.rightVertex = v;
	}
}

-(void) clipVertices:(CGRect)bounds
{
    float xmin = CGRectGetMinX(bounds);
	float xmax = CGRectGetMaxX(bounds);	// right
	float ymin = CGRectGetMinY(bounds);
	float ymax = CGRectGetMaxY(bounds);	// bottom
    
    /*
    To generalize this into a polygon BoundingBox instead of a rectangle
    we need to have line-equations/edges that define the bounds.
    
      Y
      ^
     1.0 *             * ii(0.5,1)
      |           ----   \
      |       ----        \
     0.7 *   * i(0,0.7)    \
      |       \             \
     0.5 *     \             * iii(0.7,0.5)
      |         \        ----
      |          \   ----
     0.2 *         * iv(0.3,0.2)
      |
     0.0 *
    --+-*-------*----*-----*-------*- >X
      |0.0     0.3  0.5   0.7     1.0
    
    LineI   : i->ii
    LineII  : ii->iii
    LineIII : iii->iv
    LineIV  : iv->i
    
    xMin: dependant on LineIV(y=[0.2,0.7]) and LineI(y=[0.7,1])
    xMax: dependant on LineIII(y=[0.2,0.5]) and LineII(y=[0.5,1])
    
    yMin: dependant on LineIV(x=[0,0.3]) and LineIII(x=[0.3,0.7])
    yMax: dependant on LineI(x=[0,0.5]) and LineII(x=[0.5,0.7])
    
    */
    
    
	KFVoronoiVertex *vertex0, *vertex1;
	float x0, x1, y0, y1;
    
	if (self.a == 1.0 && self.b >= 0.0) {
		vertex0 = self.rightVertex;
		vertex1 = self.leftVertex;
	}
	else {
		vertex0 = self.leftVertex;
		vertex1 = self.rightVertex;
	}
    
	
	if (self.a == 1.0) {
		y0 = ymin;
		
		if (vertex0 != nil && vertex0.point.y > ymin) {
			y0 = vertex0.point.y;
		}
        
		if (y0 > ymax) {
			return;
		}
		
        // Ax + By = c
        // --> x = ((c - By)/1.0)
		x0 = self.c - self.b * y0;
		y1 = ymax;
		
		if (vertex1 != nil && vertex1.point.y < ymax) {
			y1 = vertex1.point.y;
		}
		if (y1 < ymin) {
			return;
		}
		
        // Ax + By = c
        // --> x = ((c - By)/1.0)
		x1 = self.c - self.b * y1;
		
		if ((x0 > xmax && x1 > xmax) || (x0 < xmin && x1 < xmin)) {
			return;
		}
		
		if (x0 > xmax) {
			x0 = xmax;
			y0 = (self.c - x0)/(self.b);
		}
		else if (x0 < xmin) {
			x0 = xmin;
			y0 = (self.c - x0)/(self.b);
		}
		if (x1 > xmax) {
			x1 = xmax;
			y1 = (self.c - x1)/(self.b);
		}
		else if (x1 < xmin) {
			x1 = xmin;
			y1 = (self.c - x1)/(self.b);
		}
	}
	else {
		x0 = xmin;
		
		if (vertex0 != nil && vertex0.point.x > xmin) {
			x0 = vertex0.point.x;
		}
		if (x0 > xmax) {
			return;
		}
		
		y0 = self.c - self.a * x0;
		x1 = xmax;
		
		if (vertex1 != nil && vertex1.point.x < xmax) {
			x1 = vertex1.point.x;
		}
		if (x1 < xmin) {
			return;
		}
		
		y1 = self.c - self.a * x1;
		
		if ((y0 > ymax && y1 > ymax) || (y0 < ymin && y1 < ymin)) {
			return;
		}
		
		if (y0 > ymax) {
			y0 = ymax;
			x0 = (self.c - y0)/(self.a);
		}
		else if (y0 < ymin) {
			y0 = ymin;
			x0 = (self.c - y0)/(self.a);
		}
		
		if (y1 > ymax) {
			y1 = ymax;
			x1 = (self.c - y1)/(self.a);
		}
		else if (y1 < ymin) {
			y1 = ymin;
			x1 = (self.c - y1)/(self.a);
		}
	}
    
    _clippedVertices = [[NSMutableDictionary alloc] initWithCapacity:2];
	
	if (vertex0 == self.leftVertex) {
		[self.clippedVertices setObject:[NSValue valueWithCGPoint:CGPointMake(x0, y0)] forKey:kKFVoronoiOrientationLeft];
		[self.clippedVertices setObject:[NSValue valueWithCGPoint:CGPointMake(x1, y1)] forKey:kKFVoronoiOrientationRight];
	}
	else {
		[self.clippedVertices setObject:[NSValue valueWithCGPoint:CGPointMake(x0, y0)] forKey:kKFVoronoiOrientationRight];
		[self.clippedVertices setObject:[NSValue valueWithCGPoint:CGPointMake(x1, y1)] forKey:kKFVoronoiOrientationLeft];
	}
}

-(NSDictionary *) clippedEnds
{
    
    if (_clippedVertices) {
        
        return [NSDictionary dictionaryWithDictionary:_clippedVertices];
    }
    return nil;
}

#pragma mark - VoronoiLine
-(KFVoronoiLine *) delaunayLine
{
	return [[KFVoronoiLine alloc] initWithPoint:self.leftSite.point andPoint:self.rightSite.point];
}

-(KFVoronoiLine *) voronoiEdge
{
	if (![self visible]) {
		return nil;
	}
	
	CGPoint point1 = [[self.clippedVertices valueForKey:kKFVoronoiOrientationLeft] CGPointValue];
	CGPoint point2 = [[self.clippedVertices valueForKey:kKFVoronoiOrientationRight] CGPointValue];
    
	if (CGPointEqualToPoint(point1, point2)) {
		return nil;
	}
    
	return [[KFVoronoiLine alloc] initWithPoint:point1 andPoint:point2];
}

#pragma mark - Helper
-(BOOL) visible
{
    return (_clippedVertices != nil);
}

@end
