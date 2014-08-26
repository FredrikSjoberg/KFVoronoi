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

#import "KFVoronoiSiteList.h"

#import "KFVoronoiSite.h"
#import "KFVoronoi.h"

#pragma mark -
#pragma mark - Private
@interface KFVoronoiSiteList ()

@property (nonatomic, strong) NSMutableArray *sites;
@property (nonatomic, strong) NSMutableDictionary *sitesIndexedByLocation;

@property (nonatomic) int currentIndex;
@property (nonatomic) BOOL sorted;

#pragma mark - (Private Methods)
-(void) createSitesFromPoints:(NSArray *)points;
-(void) setSite:(KFVoronoiSite *)site forLocation:(CGPoint)location;
-(void) addNewSite:(KFVoronoiSite *)site;
-(void) sortSites;

@end



#pragma mark -
#pragma mark - Implementation
@implementation KFVoronoiSiteList

#pragma mark - Initialize
-(id) initWithPoints:(NSArray *)points
{
    if ((self = [super init])) {
        _sites = [[NSMutableArray alloc] init];
        _sitesIndexedByLocation = [[NSMutableDictionary alloc] init];
        
        _currentIndex = 0;
        _sorted = NO;
        
        [self createSitesFromPoints:points];
    }
    return self;
}

#pragma mark - (Setup)
-(void) createSitesFromPoints:(NSArray *)points
{
    uint i = 0;
    for (NSValue *value in points) {
        CGPoint p = [value CGPointValue];
        
        if (![self containsSiteForLocation:p]) {
            // Create a new Site
            KFVoronoiSite *site = [[KFVoronoiSite alloc] initWithCGPoint:p index:i];
            [self addNewSite:site];
            
            // Index the site by location
            [[self sitesIndexedByLocation] setObject:site forKey:value];
            
            // Update the index
            i++;
        }
    }
}

-(void) addNewSite:(KFVoronoiSite *)site
{
    // Adding a new site means the sorting must be redone
    [self setSorted:NO];
    [self.sites addObject:site];
}

#pragma mark - (Sort Sites)
-(void) sortSites
{
    [self.sites sortUsingComparator:^NSComparisonResult(id obj1, id obj2){
        KFVoronoiSite *s1 = obj1;
        KFVoronoiSite *s2 = obj2;
        
        int tempIndex;
        
        NSComparisonResult compareResult = kfCompareByYThenX([s1 point], [s2 point]);
        
        if (compareResult == NSOrderedAscending) {
            if (s1.index > s2.index)
            {
                tempIndex = s1.index;
                s1.index = s2.index;
                s2.index = tempIndex;
            }
        }
        else if (compareResult == NSOrderedDescending) {
            if (s2.index > s1.index)
            {
                tempIndex = s2.index;
                s2.index = s1.index;
                s1.index = tempIndex;
            }
        }
        
        return compareResult;
    }];
}


#pragma mark - Sites
-(void) reorderEdgesForAllSites
{
    for (KFVoronoiSite *s in self.sites) {
        [s reorderEdges];
    }
}

-(void) calculateRegionsForAllSitesWithBounds:(CGRect)plotBounds
{
    for (KFVoronoiSite *s in self.sites) {
        [s calculateRegionWithinBounds:plotBounds];
    }
}

-(uint) getNumberOfSites
{
    return self.sites.count;
}

-(BOOL) containsSiteForLocation:(CGPoint)location
{
    if ([[self sitesIndexedByLocation] objectForKey:[NSValue valueWithCGPoint:location]]) {
        return YES;
    }
    return NO;
}

-(KFVoronoiSite *) getSiteForLocation:(CGPoint)location
{
    return [self.sitesIndexedByLocation objectForKey:[NSValue valueWithCGPoint:location]];
}

-(KFVoronoiSite *) nextSite
{
    if (self.sorted == NO) {
		NSLog(@"SiteList.next: sites have not been sorted.");
        [self sortSites];
	}
    
	if (self.currentIndex < [self.sites count]) {
		KFVoronoiSite *site = [self.sites objectAtIndex:self.currentIndex];
		self.currentIndex++;
		return site;
	}
	else {
		return nil;
	}
}

#pragma mark - Bounds
-(CGRect) getBounds
{
    // Make sure the sites have been sorted
    if (self.sorted == NO) {
        [self sortSites];
        
		[self setCurrentIndex:0];
		[self setSorted:YES];
	}
    
	float xmin, xmax, ymin, ymax;
    
    // If we have no sites.. return Zero-rect
	if ([self.sites count] == 0) {
        return CGRectZero;
	}
    
    
	xmin = FLT_MAX;
	xmax = -FLT_MAX;
	
    // Find xmin/xmax
	for (KFVoronoiSite *site in self.sites) {
		if (site.point.x < xmin) {
			xmin = site.point.x;
			
		}
        
		if (site.point.x > xmax) {
			xmax = site.point.x;
		}
	}
	
	
	// We asume the sites have been sorted on y.
	KFVoronoiSite *minSite = [self.sites objectAtIndex:0];
	KFVoronoiSite *maxSite = [self.sites objectAtIndex:(self.sites.count - 1)];
	ymin = minSite.point.y;
	ymax = maxSite.point.y;
	
	return CGRectMake(xmin, ymin, xmax - xmin, ymax - ymin);
}

@end
