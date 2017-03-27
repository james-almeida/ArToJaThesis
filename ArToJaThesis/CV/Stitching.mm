//
//  Stitching.m
//  PanoDemo
//
//  Created by DJI on 15/7/30.
//  Copyright (c) 2015年 DJI. All rights reserved.
//

#import "Stitching.h"
#import "StitchingWrapper.h"
#import "OpenCVConversion.h"
#import "opencv2/imgcodecs/ios.h"

#define COMPRESS_RATIO 0.2

@implementation Stitching

+ (bool) stitchImageWithArray:(NSMutableArray*)imageArray andResult:(cv::Mat &) result {
    
    NSMutableArray* compressedImageArray =[NSMutableArray new];
    for(UIImage *rawImage in imageArray){
        UIImage *compressedImage=[self compressedToRatio:rawImage ratio:COMPRESS_RATIO];
        [compressedImageArray addObject:compressedImage];
    }
    [imageArray removeAllObjects];
    
    
    if ([compressedImageArray count]==0) {
        NSLog (@"imageArray is empty");
        return false;
    }
    cv::vector<cv::Mat> matArray;
    
    for (id image in compressedImageArray) {
        if ([image isKindOfClass: [UIImage class]]) {
            cv::Mat matImage = [OpenCVConversion cvMat3FromUIImage:image];
            matArray.push_back(matImage);
        }
    }
    NSLog(@"Stitching...");
    if(!stitch(matArray, result)){
        return false;
    }
    
    return true;
}

// TODO: use cv::function rather than cvFunction?
+ (NSArray*) findTargetCoordinates:(UIImage*) rawImage {
    
    // compress image
    UIImage* compressedUIImage = [self compressedToRatio:rawImage ratio:COMPRESS_RATIO];
    
    // convert to cv::Mat datatype
    // http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c/10254561
    cv::Mat compressedMat = [OpenCVConversion cvMat3FromUIImage:compressedImage];
    
    // find target
    
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(&compressedImage, &hsvImage, CV_BGR2HSV)
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask, blueMask, sumMask;
    
    cv::inRange(hsvImage, cvScalar(110, 150, 150), cvScalar(130, 255, 255), blueMask);
    cv::inRange(hsvImage, cvScalar(-5, 150, 150), cvScalar(5, 150, 150), redMask);
    
    if (blueMask == NULL || redMask == NULL) return NULL;
    
    cv::add(blueMask, redMask, sumMask);
    
    // 3. laplacian for sum
    cv::Mat laplaceImage;
    cv::laplace(sumMask, laplaceImage)
    
    // 4. '+' shaped kernel
    NSInteger n = 50;
    NSInteger m = 5;
    cv::Mat kernel = cv::Mat(n, n, CV_64F, -1.0);
    for (NSInteger i = 0; i < n; i++) {
        for (NSInteger j = 0; j < n; j++) {
            if (i < n + m && i > n - m)
                kernel.at<double>(i,j) = 1;
            if (j < n + m && j > n - m)
                kernel.at<double>(i,j) = 1;
        }
    }
    
    cv::Mat filteredImage;
    cv::filter2D(laplaceImage, filteredImage, &kernel);  // kernel or &kernel?
    
    // 5. find index of max value
    NSInteger rows = I.rows();
    NSInteger cols = I.cols();
    
    NSInteger xmax, ymax, maxval;
    xmax = -1;
    ymax = -1;
    maxval = 0;
    
    for (NSInteger i = 0; i < rows; i++) {
        for (NSInteger j = 0; j < cols; j++) {
            if (filteredImage.at<double>(i,j) > max) {
                xmax = i;
                ymax = j;
            }
        }
    }
    
    if (xmax == -1)
        return NULL;
    
    // return result, or null
    return [NSArray arrayWithObjects:@xmax, @ymax];
}


//compress the photo width and height to COMPRESS_RATIO
+ (UIImage *)compressedToRatio:(UIImage *)img ratio:(float)ratio {
    CGSize compressedSize;
    compressedSize.width=img.size.width*ratio;
    compressedSize.height=img.size.height*ratio;
    UIGraphicsBeginImageContext(compressedSize);
    [img drawInRect:CGRectMake(0, 0, compressedSize.width, compressedSize.height)];
    UIImage* compressedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return compressedImage;
}

@end