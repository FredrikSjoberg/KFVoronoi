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

#import "KFVoronoiVertex.h"

#import "KFVoronoiEdge.h"
#import "KFVoronoiHalfedge.h"
#import "KFVoronoiSite.h"
#import "KFVoronoi.h"

#define kKFVoronoiVertexEpsilon 1.0E-10

#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiVertex

#pragma mark - Init
+(KFVoronoiVertex *) intersect:(KFVoronoiHalfedge *)he0 with:(KFVoronoiHalfedge *)he1
{
    KFVoronoiEdge *edge;
	KFVoronoiHalfedge *halfedge;
    
	float determinant, intersectionX, intersectionY;
	BOOL rightOfSite;
	
	KFVoronoiEdge *edge0 = he0.edge;
	KFVoronoiEdge *edge1 = he1.edge;
	
	if (edge0 == nil || edge1 == nil) {
		return nil;
	}
	if (edge0.rightSite == edge1.rightSite) {
		return nil;
	}
	
	determinant = edge0.a * edge1.b - edge0.b * edge1.a;
	if (-kKFVoronoiVertexEpsilon < determinant
        && determinant < kKFVoronoiVertexEpsilon) {
		// the edges are parallel
		return nil;
	}
	
	intersectionX = (edge0.c * edge1.b - edge1.c * edge0.b)/determinant;
	intersectionY = (edge1.c * edge0.a - edge0.c * edge1.a)/determinant;
	
    if (kfCompareByYThenX([[edge0 rightSite] point], [[edge1 rightSite] point]) == NSOrderedAscending) {
		halfedge = he0;
		edge = edge0;
	}
	else {
		halfedge = he1;
		edge = edge1;
	}
	
	rightOfSite = (intersectionX >= edge.rightSite.point.x);
	
	if ((rightOfSite && [[halfedge leftRight] kfMatches:kKFVoronoiOrientationLeft]) || (!rightOfSite && [[halfedge leftRight] kfMatches:kKFVoronoiOrientationRight])) {
		return nil;
	}
	
	return [[KFVoronoiVertex alloc] initWithCGPoint:ccp(intersectionX, intersectionY)];
}

@end
