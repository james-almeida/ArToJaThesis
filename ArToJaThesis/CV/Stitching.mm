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

+ (UIImage*) getRedMask:(UIImage*) rawImage {
    // compress image
    UIImage* compressedUIImage = [self compressedToRatio:rawImage ratio:COMPRESS_RATIO];
    
    // convert to cv::Mat datatype
    // http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c/10254561
    cv::Mat compressedMat;
    UIImageToMat(compressedUIImage, compressedMat);//[OpenCVConversion cvMat3FromUIImage:compressedUIImage];

    // steps to find target
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(compressedMat, hsvImage, CV_BGR2HSV);
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask, blueMask, sumMask;
    
    cv::inRange(hsvImage, cv::Scalar(110, 150, 150), cv::Scalar(130, 255, 255), redMask); // flip bc BGR
    cv::inRange(hsvImage, cv::Scalar(-10, 150, 150), cv::Scalar(10, 255, 255), blueMask);
    
    if (blueMask.empty() || redMask.empty()) return NULL;
    
    cv::add(blueMask, redMask, sumMask);
    
    // 3. laplacian for sum
    cv::Mat laplaceImage;
    cv::Laplacian(sumMask, laplaceImage, -1);
    
    return MatToUIImage(laplaceImage);
}


// TODO: use cv::function rather than cvFunction?
+ (NSArray*) findTargetCoordinates:(UIImage*) rawImage {
    
    // compress image
    UIImage* compressedUIImage = [self compressedToRatio:rawImage ratio:COMPRESS_RATIO];
    
    // convert to cv::Mat datatype
    // http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c/10254561
    cv::Mat compressedMat;
    UIImageToMat(compressedUIImage, compressedMat); //[OpenCVConversion cvMat3FromUIImage:compressedUIImage];
    
    // steps to find target
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(compressedMat, hsvImage, CV_BGR2HSV);
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask, blueMask, sumMask;
    
    cv::inRange(hsvImage, cv::Scalar(110, 150, 150), cv::Scalar(130, 255, 255), redMask); // flip bc BGR
    cv::inRange(hsvImage, cv::Scalar(-10, 150, 150), cv::Scalar(10, 255, 255), blueMask);
    
    if (blueMask.empty() || redMask.empty()) return NULL;
    
    cv::add(blueMask, redMask, sumMask);
    
    // 3. laplacian for sum
    cv::Mat laplaceImage;
    cv::Laplacian(sumMask, laplaceImage, -1);
    
    // 4. '+' shaped kernel
    int n = 50;
    int m = 5;
    cv::Mat kernel = cv::Mat(n, n, CV_64F, -1.0);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (i < n + m && i > n - m)
                kernel.at<double>(i,j) = 1;
            if (j < n + m && j > n - m)
                kernel.at<double>(i,j) = 1;
        }
    }
    
    cv::Mat filteredImage;
    cv::filter2D(laplaceImage, filteredImage, -1, kernel);  // kernel or &kernel?
    
    // 5. find index of max value
//    double minVal, maxVal;
//    cv::Point minPoint, maxPoint;
//    cv::minMaxLoc(filteredImage, &minVal, &maxVal, &minPoint, &maxPoint, cv::noArray());
    
    NSInteger rows = filteredImage.rows;
    NSInteger cols = filteredImage.cols;
    
    NSInteger xmax, ymax, maxval;
    xmax = -1;
    ymax = -1;
    maxval = 0;
    
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            if (filteredImage.at<double>(i,j) > maxval) {
                xmax = i;
                ymax = j;
            }
        }
    }
    
    if (xmax == -1)
        return NULL;
    
    // return result, or null
    return @[[NSNumber numberWithInteger:xmax], [NSNumber numberWithInteger:ymax]];
}

+ (UIImage *)imageWithColor:(UIImage*)image location:(NSArray*) coords{
    
    UIColor* color = [UIColor colorWithRed:255 green:0 blue:0 alpha:1];
    
    // begin a new image context, to draw our colored image onto
    CGSize size = CGSizeMake(image.size.width/2, image.size.height/2);
    UIGraphicsBeginImageContextWithOptions(size, NO, [[UIScreen mainScreen] scale]);
    
    // get a reference to that context we created
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // set the fill color
    [color setFill];
    
    // translate/flip the graphics context (for transforming from CG* coords to UI* coords
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // set the blend mode to overlay, and the original image
    CGContextSetBlendMode(context, kCGBlendModeOverlay);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    CGContextDrawImage(context, rect, image.CGImage);
    
    // set a mask that matches the shape of the image, then draw (overlay) a colored rectangle
    CGContextClipToMask(context, rect, image.CGImage);
    CGContextAddRect(context, rect);
    CGContextDrawPath(context,kCGPathFill);
    
    // generate a new UIImage from the graphics context we drew onto
    UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //return the color-burned image
    return coloredImg;
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
