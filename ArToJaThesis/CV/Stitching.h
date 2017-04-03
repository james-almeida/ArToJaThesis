//
//  Stitching.h
//  PanoDemo
//
//  Created by DJI on 15/7/30.
//  Copyright (c) 2015年 DJI. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DJICameraViewController;
@interface Stitching : NSObject

//+ (bool) stitchImageWithArray:(NSMutableArray*)imageArray andResult:(cv::Mat) result;
+ (NSArray*) findTargetCoordinates:(UIImage*) rawImage viewController:(DJICameraViewController*) vc;
+ (UIImage*) getRedMask:(UIImage*) rawImage;
+ (UIImage *)imageWithColor:(UIImage*)image location:(NSArray*) coords;

@end
