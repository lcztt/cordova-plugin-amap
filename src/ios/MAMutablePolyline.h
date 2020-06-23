#import <Foundation/Foundation.h>
#import <AMapNaviKit/AMapNaviKit.h>

#define use_navigation 1

@interface MAMutablePolyline : NSObject<MAOverlay>

/* save MAMapPoints by NSValue */
@property (nonatomic, strong) NSMutableArray *pointArray;

- (instancetype)initWithPoints:(NSArray *)nsvaluePoints;

- (MAMapRect)showRect;

- (MAMapPoint)mapPointForPointAt:(NSUInteger)index;

- (void)updatePoints:(NSArray *)points;

- (void)appendPoint:(MAMapPoint)point;

@end
