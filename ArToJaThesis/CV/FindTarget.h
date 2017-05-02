//
//  FindTarget.h
//


#import <Foundation/Foundation.h>
@class DJICameraViewController;
@interface FindTarget : NSObject

+ (NSArray*) findTargetCoordinates:(UIImage*) rawImage viewController:(DJICameraViewController*) vc;
+ (UIImage*) getImageMask:(UIImage*) rawImage;
+ (UIImage *)imageWithColor:(UIImage*)image location:(NSArray*) coords;

@end
