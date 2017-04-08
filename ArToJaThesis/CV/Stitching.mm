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
#import "DJICameraViewController.h"

#define COMPRESS_RATIO 0.2
#define LOW 85
#define FILTER_SIZE 30

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
 
    // convert to cv::Mat datatype
    // http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c/10254561
    
    cv::Mat compressedMat;
    UIImageToMat(rawImage, compressedMat); //[OpenCVConversion cvMat3FromUIImage:compressedUIImage];
    
    // steps to find target
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(compressedMat, hsvImage, CV_BGR2HSV);
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask, blueMask, sumMask;
    
    cv::inRange(hsvImage, cv::Scalar(110, LOW, LOW), cv::Scalar(130, 255, 255), redMask); // flip bc BGR
    cv::inRange(hsvImage, cv::Scalar(-10, LOW, LOW), cv::Scalar(10, 255, 255), blueMask);

    cv::Mat kernel = cv::Mat::ones(FILTER_SIZE, FILTER_SIZE, CV_32F) / (FILTER_SIZE * FILTER_SIZE);
    
    cv::Mat filteredImage;
    cv::filter2D(redMask, filteredImage, -1, kernel);
    
    return MatToUIImage(filteredImage);
}


// TODO: use cv::function rather than cvFunction?
+ (NSArray*) findTargetCoordinates:(UIImage*) rawImage viewController:(DJICameraViewController*) vc {
    
    // convert to cv::Mat datatype
    cv::Mat compressedMat;
    UIImageToMat(rawImage, compressedMat);
    
    // steps to find target
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(compressedMat, hsvImage, CV_BGR2HSV);
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask = cv::Mat::zeros(hsvImage.rows, hsvImage.cols, CV_32S);
    cv::Mat blueMask = cv::Mat::zeros(hsvImage.rows, hsvImage.cols, CV_32S);
    cv::Mat sumMask = cv::Mat::zeros(hsvImage.rows, hsvImage.cols, CV_32S);
    
    cv::inRange(hsvImage, cv::Scalar(110, LOW, LOW), cv::Scalar(130, 255, 255), redMask); // flip bc BGR
    cv::inRange(hsvImage, cv::Scalar(-10, LOW, LOW), cv::Scalar(10, 255, 255), blueMask);
    
    cv::Mat kernel = cv::Mat::ones(FILTER_SIZE, FILTER_SIZE, CV_32F) / (FILTER_SIZE * FILTER_SIZE);
    
    cv::Mat filteredRedImage, filteredBlueImage;
    cv::filter2D(redMask, filteredRedImage, -1, kernel);
    cv::filter2D(redMask, filteredBlueImage, -1, kernel);
    
    // 5. find index of max value
    cv::Point maxRedPoint, maxBluePoint;
    cv::minMaxLoc(filteredRedImage, nil, nil, nil, &maxRedPoint, cv::noArray());
    cv::minMaxLoc(filteredBlueImage, nil, nil, nil, &maxBluePoint, cv::noArray());

    return @[[NSNumber numberWithInteger:maxRedPoint.x], [NSNumber numberWithInteger:maxRedPoint.y], [NSNumber numberWithInteger:maxBluePoint.x], [NSNumber numberWithInteger:maxBluePoint.y]];
}

+ (UIImage *)imageWithColor:(UIImage*)image location:(NSArray*) coords{
        
    UIImage* outputImage = image; //[UIImage imageWithData:UIImagePNGRepresentation(image)];
    CGRect imageRect = CGRectMake(0, 0, outputImage.size.width, outputImage.size.height);
    
    UIGraphicsBeginImageContext(outputImage.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Save current status of graphics context
    CGContextSaveGState(context);
    CGContextDrawImage(context, imageRect, outputImage.CGImage);
    //    And then just draw a point on it wherever you want like this:
    
    NSInteger size = 10;
    CGContextSetRGBFillColor(context, 1.0 , 0.0, 0.0, 1);
    CGContextFillRect(context, CGRectMake([coords[0] integerValue],[coords[1] integerValue], size, size));
    
    CGContextRestoreGState(context);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    return img;
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
