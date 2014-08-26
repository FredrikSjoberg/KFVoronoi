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

#import "KFVoronoi.h"

#import "KFVoronoiSite.h"
#import "KFVoronoiEdge.h"
#import "KFVoronoiHalfedge.h"
#import "KFVoronoiVertex.h"

#import "KFVoronoiSiteList.h"
#import "KFVoronoiHEPQ.h"
#import "KFVoronoiEdgeList.h"

NSString * const kKFVoronoiOrientationLeft = @"kKFVoronoiOrientationLeft";
NSString * const kKFVoronoiOrientationRight = @"kKFVoronoiOrientationRight";

#pragma mark -
#pragma mark - Private
@interface KFVoronoi ()

@property (nonatomic, strong) KFVoronoiSiteList *siteList;
@property (nonatomic, strong) NSMutableArray *edges;
@property (nonatomic, strong) NSMutableArray *vertices;
@property (nonatomic, strong) NSMutableArray *halfEdges;
@property (nonatomic) CGRect plotBounds;

#pragma mark - (Fortunes Algoritm)
-(void) runFortunesAlgorithm;
-(void) clipEdgeVertices;
-(void) reorderSiteEdges;
-(void) createSiteRegions;
#pragma mark - (HandleComponents)
-(void) addEdge:(KFVoronoiEdge *)edge;
-(void) addHalfEdge:(KFVoronoiHalfedge *)halfedge;
-(void) addVertex:(KFVoronoiVertex *)vertex;
@end

#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoi

#pragma mark - Init
-(id) initWithPoints:(NSArray *)points andBounds:(CGRect)bounds
{
    if ((self = [super init])) {
        _plotBounds = bounds;
        
        // Initiate SiteList
        _siteList = [[KFVoronoiSiteList alloc] initWithPoints:points];
        
        
        // Initiate Edge Storage
        _edges = [[NSMutableArray alloc] init];
        _halfEdges = [[NSMutableArray alloc] init];
        _vertices = [[NSMutableArray alloc] init];
        
        // Run the Algorithm
        [self runFortunesAlgorithm];
    }
    return self;
}


#pragma mark - (Fortunes Algoritm)
-(void) runFortunesAlgorithm
{
    KFVoronoiSite *newSite, *bottomSite, *topSite, *tempSite, *bottomMostSite;
	KFVoronoiVertex *v, *vertex;
	CGPoint newIntStar;
    NSString *leftRight;
	KFVoronoiHalfedge *lbnd, *rbnd, *llbnd, *rrbnd, *bisector;
	KFVoronoiEdge *edge;
    
    // Get the dataBounds
    CGRect dataBounds = [self.siteList getBounds];
    
    // Calculate SQRT(numSites)
    int sqrtNumberSites = sqrt([[self siteList] getNumberOfSites] + 4);	// is this correct??
	
    
    // Create HalfEdgePriorityQueue
    KFVoronoiHEPQ *heap = [[KFVoronoiHEPQ alloc] initWithYMin:dataBounds.origin.y andYDelta:CGRectGetHeight(dataBounds) withSize:sqrtNumberSites];
    
    // Create EdgeList
    KFVoronoiEdgeList *edgeList = [[KFVoronoiEdgeList alloc] initWithXMin:dataBounds.origin.x andXDelta:CGRectGetWidth(dataBounds) withSize:sqrtNumberSites];
    
    
    // Fetch the bottomMostSite
    bottomMostSite = [self.siteList nextSite];
    
    // Fetch the next site in line after BottomMostSite
    newSite = [self.siteList nextSite];
    
    // Start processing the sites, creating the diagram
    for ( ; ; ) {
        // Check if Heap is Empty
		if (![heap empty]) {
            // If no, get newIntStar
			newIntStar = [heap minPoint];
		}
        
        if (newSite != nil
            && ([heap empty] || kfCompareByYThenX([newSite point], newIntStar) == NSOrderedAscending) ) {
            // Newsite Smallest
            
			lbnd = [edgeList edgeListLeftNeighbor:[newSite point]];
			rbnd = lbnd.edgeListRightNeighbor;
			
			if (lbnd.edge == nil) {
				bottomSite = bottomMostSite;
			}
			else {
				bottomSite = [lbnd.edge getSite:[KFVoronoiHalfedge otherLeftRight:[lbnd leftRight]]];
			}
            
            edge = [[KFVoronoiEdge alloc] initWithSite:bottomSite andSite:newSite index:[edgeList getNextEdgeIndex]];
            [self addEdge:edge];
            
            bisector = [[KFVoronoiHalfedge alloc] initWithEdge:edge andLeftRight:kKFVoronoiOrientationLeft];
            [self addHalfEdge:bisector];
			[edgeList insertHalfEdge:bisector toTheRightOf:lbnd];
            
            vertex = [KFVoronoiVertex intersect:bisector with:lbnd];
            if (vertex) {
                [self addVertex:vertex];
				[heap removeHalfEdge:lbnd];
				lbnd.vertex = vertex;
                
                [lbnd setYStarFromVertex:vertex andSite:newSite];
				[heap insertHalfEdge:lbnd];
			}
			lbnd = bisector;
            
            bisector = [[KFVoronoiHalfedge alloc] initWithEdge:edge andLeftRight:kKFVoronoiOrientationRight];
            [self addHalfEdge:bisector];
			[edgeList insertHalfEdge:bisector toTheRightOf:lbnd];
            
            vertex = [KFVoronoiVertex intersect:rbnd with:bisector];
            if (vertex) {
                [self addVertex:vertex];
				bisector.vertex = vertex;
                
				[bisector setYStarFromVertex:vertex andSite:newSite];
                [heap insertHalfEdge:bisector];
			}
			
			newSite = [self.siteList nextSite];
        }
        else if (![heap empty]) {
            // Intersection Smallest
            lbnd = [heap extractMin];
			llbnd = lbnd.edgeListLeftNeighbor;
			rbnd = lbnd.edgeListRightNeighbor;
			rrbnd = rbnd.edgeListRightNeighbor;
			
			if (lbnd.edge == nil) {
				bottomSite = bottomMostSite;
			}
			else {
				bottomSite = [lbnd.edge getSite:[lbnd leftRight]];
			}
            
            
            if (rbnd.edge == nil) {
				topSite = bottomMostSite;
			}
			else {
				topSite = [rbnd.edge getSite:[KFVoronoiHalfedge otherLeftRight:[rbnd leftRight]]];
			}
            
            
			v = lbnd.vertex;
            [v setIndex:[edgeList getNextVertexIndex]];
			
            [[lbnd edge] setEdgeVertex:v asLeftRight:[lbnd leftRight]];
            [[rbnd edge] setEdgeVertex:v asLeftRight:[rbnd leftRight]];
			
			[edgeList removeHalfEdge:lbnd];
			[heap removeHalfEdge:rbnd];
			[edgeList removeHalfEdge:rbnd];
            
            
            leftRight = kKFVoronoiOrientationLeft;
			if (bottomSite.point.y > topSite.point.y) {
				tempSite = bottomSite;
				bottomSite = topSite;
				topSite = tempSite;
				leftRight = kKFVoronoiOrientationRight;
			}
            
            edge = [[KFVoronoiEdge alloc] initWithSite:bottomSite andSite:topSite index:[edgeList getNextEdgeIndex]];
            [self addEdge:edge];
			
            bisector = [[KFVoronoiHalfedge alloc] initWithEdge:edge andLeftRight:leftRight];
            [self addHalfEdge:bisector];
			[edgeList insertHalfEdge:bisector toTheRightOf:llbnd];
			[edge setEdgeVertex:v asLeftRight:[KFVoronoiHalfedge otherLeftRight:leftRight]];
			
            vertex = [KFVoronoiVertex intersect:bisector with:llbnd];
            if (vertex) {
                [self addVertex:vertex];
				[heap removeHalfEdge:llbnd];
				llbnd.vertex = vertex;
                
				[llbnd setYStarFromVertex:vertex andSite:bottomSite];
				[heap insertHalfEdge:llbnd];
			}
            
            
            vertex = [KFVoronoiVertex intersect:rrbnd with:bisector];
            if (vertex) {
                [self addVertex:vertex];
				bisector.vertex = vertex;
                
                [bisector setYStarFromVertex:vertex andSite:bottomSite];
				[heap insertHalfEdge:bisector];
			}
            
        }
        else {
            break;
        }
    }
    
    // Clip Edge Vertices
    [self clipEdgeVertices];
    
    // Reorder Edges for Sites
    [self reorderSiteEdges];
    
    // Create Regions for Sites
    [self createSiteRegions];
    
}

-(void) clipEdgeVertices
{
    for (KFVoronoiEdge *edge in self.edges) {
		[edge clipVertices:self.plotBounds];
        
	}
}

-(void) reorderSiteEdges
{
    [[self siteList] reorderEdgesForAllSites];
}

-(void) createSiteRegions
{
    [[self siteList] calculateRegionsForAllSitesWithBounds:self.plotBounds];
}

#pragma mark - (HandleComponents)
-(void) addEdge:(KFVoronoiEdge *)edge
{
    if (edge)
        [[self edges] addObject:edge];
}

-(void) addHalfEdge:(KFVoronoiHalfedge *)halfedge
{
    if (halfedge)
        [[self halfEdges] addObject:halfedge];
}

-(void) addVertex:(KFVoronoiVertex *)vertex
{
    if (vertex)
        [[self vertices] addObject:vertex];
}


#pragma mark - Regions
-(NSArray *) getRegionForPoint:(CGPoint)p
{
    KFVoronoiSite *site = [self.siteList getSiteForLocation:p];
    
    if (site) {
        return [site getRegionWithinBounds:self.plotBounds];
    }
    
    return [NSArray array];
}

#pragma mark - FetchEdges
-(NSArray *) fetchEdges
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    for (KFVoronoiEdge *e in self.edges) {
        if ([e visible]) {
            [arr addObject:e];
        }
    }
    
    return [NSArray arrayWithArray:arr];
}

#pragma mark - CompareByYThenX
NSComparisonResult kfCompareByYThenX(CGPoint p0, CGPoint p1)
{
    if (p0.y < p1.y){ return NSOrderedAscending;}
	if (p0.y > p1.y){ return NSOrderedDescending; }
	if (p0.x < p1.x){ return NSOrderedAscending;}
	if (p0.x > p1.x){ return NSOrderedDescending;}
	
	return NSOrderedSame;
}

@end
