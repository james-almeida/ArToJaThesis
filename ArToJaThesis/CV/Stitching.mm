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
    //    UIImageToMat(compressedUIImage, compressedMat); //[OpenCVConversion cvMat3FromUIImage:compressedUIImage];
    UIImageToMat(rawImage, compressedMat); //[OpenCVConversion cvMat3FromUIImage:compressedUIImage];
    
    // steps to find target
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(compressedMat, hsvImage, CV_BGR2HSV);
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask, blueMask, sumMask;
    
    cv::inRange(hsvImage, cv::Scalar(110, 170, 170), cv::Scalar(130, 255, 255), redMask); // flip bc BGR
    cv::inRange(hsvImage, cv::Scalar(-10, 170, 170), cv::Scalar(10, 255, 255), blueMask);
    
    if (blueMask.empty() || redMask.empty()) return NULL;
    
    cv::add(blueMask, redMask, sumMask);
    
    // 3. laplacian for sum
    cv::Mat laplaceImage;
    cv::Laplacian(sumMask, laplaceImage, -1, 15, 1, 0, cv::BORDER_DEFAULT);
    laplaceImage = laplaceImage / 2;
    

    int n = 30;
    int m = 10;

    cv::Mat kernel = cv::Mat(n, n, CV_32F, -1.0);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            kernel.at<float>(i,j) = -1.0;
            if (i < n/2 + m && i > n/2 - m)
                kernel.at<float>(i,j) = 1.0;
            if (j < n/2 + m && j > n/2 - m)
                kernel.at<float>(i,j) = 1.0;
        }
    }
    
    cv::Mat filteredImage;
    cv::filter2D(laplaceImage, filteredImage, -1, kernel);
    
    return MatToUIImage(filteredImage);
}


// TODO: use cv::function rather than cvFunction?
+ (NSArray*) findTargetCoordinates:(UIImage*) rawImage {
    
    // compress image
    UIImage* compressedUIImage = [self compressedToRatio:rawImage ratio:COMPRESS_RATIO];
    
    // convert to cv::Mat datatype
    // http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c/10254561
    cv::Mat compressedMat;
//    UIImageToMat(compressedUIImage, compressedMat); //[OpenCVConversion cvMat3FromUIImage:compressedUIImage];
    UIImageToMat(rawImage, compressedMat); //[OpenCVConversion cvMat3FromUIImage:compressedUIImage];

    
    // steps to find target
    // 1. convert to HSV
    cv::Mat hsvImage;
    cv::cvtColor(compressedMat, hsvImage, CV_BGR2HSV);
    
    // 2. create mask for red & blue, sum together
    
    cv::Mat redMask = cv::Mat::zeros(hsvImage.rows, hsvImage.cols, CV_32S);
    cv::Mat blueMask = cv::Mat::zeros(hsvImage.rows, hsvImage.cols, CV_32S);
    cv::Mat sumMask = cv::Mat::zeros(hsvImage.rows, hsvImage.cols, CV_32S);
    
    cv::inRange(hsvImage, cv::Scalar(110, 170, 170), cv::Scalar(130, 255, 255), redMask); // flip bc BGR
    cv::inRange(hsvImage, cv::Scalar(-10, 170, 170), cv::Scalar(10, 255, 255), blueMask);
    
    if (blueMask.empty() || redMask.empty()) return NULL;
    
    cv::add(blueMask, redMask, sumMask);
    
    // 3. laplacian for sum
    cv::Mat laplaceImage = cv::Mat::zeros(sumMask.rows, sumMask.cols, CV_32S);;
    cv::Laplacian(sumMask, laplaceImage, -1, 15, 1, 0, cv::BORDER_DEFAULT);
    laplaceImage = laplaceImage / 2.0;
    
    // 4. '+' shaped kernel
    int n = 50;
    int m = 8;


    cv::Mat kernel = cv::Mat::zeros(n, n, CV_32F);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            kernel.at<float>(i,j) = -1.0;
            if (i < n/2 + m && i > n/2 - m)
                kernel.at<float>(i,j) = 1.0;
            if (j < n/2 + m && j > n/2 - m)
                kernel.at<float>(i,j) = 1.0;
        }
    }
    kernel = kernel / float(n * n);
    
    
//    for (int i = 0; i < n; i++) {
//        NSMutableString *line = [NSMutableString stringWithCapacity:80];
//        for (int j = 0; j < n; j++) {
//            [line appendFormat:@"%d ", kernel.at<int>(i,j)];
//        }
//        NSLog(line);
//    }
    
    cv::Mat filteredImage; //= cv::Mat::zeros(laplaceImage.rows, laplaceImage.cols, CV_32F);
    cv::filter2D(laplaceImage, filteredImage, -1, kernel);
//    filteredImage = filteredImage;
    
    // 5. find index of max value
    double minVal, maxVal, maxVal2;
    cv::Point minPoint, maxPoint;
    cv::minMaxLoc(filteredImage, &minVal, &maxVal, &minPoint, &maxPoint, cv::noArray());
//
    int idx[2];
    cv::minMaxIdx(filteredImage, NULL, &maxVal2, NULL, idx, cv::noArray());
    
    NSInteger rows = filteredImage.rows;
    NSInteger cols = filteredImage.cols;
    
    NSInteger xmax, ymax, maxval;
    xmax = -1;
    ymax = -1;
    maxval = -1;
    
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            if (filteredImage.at<char>(j,i) > maxval) {
                xmax = i;
                ymax = j;
                maxval = filteredImage.at<char>(j,i);
//                NSLog(@"New Max: %dl, at: (%d, %d)", maxval, xmax, ymax);
            }
        }
    }
    
//    if (xmax == -1)
//        return NULL;
//    
//    // return result, or null
    return @[[NSNumber numberWithInteger:xmax], [NSNumber numberWithInteger:ymax], [NSNumber numberWithFloat:maxval],
             [NSNumber numberWithInteger:maxPoint.x], [NSNumber numberWithInteger:maxPoint.y], [NSNumber numberWithFloat:maxVal],
             [NSNumber numberWithInteger:idx[0]], [NSNumber numberWithInteger:idx[1]], [NSNumber numberWithInteger:maxVal2], [NSNumber numberWithChar:filteredImage.at<char>(452,0)], [NSNumber numberWithChar:filteredImage.at<char>(0,452)],[NSNumber numberWithChar:filteredImage.at<char>(452,452)]];
    
    
//    int p = 2;
//    cv::Mat k2 = cv::Mat(p,p, CV_64F, 0.0);
//    kernel.at<double>(0,1) = 255;
//    kernel.at<double>(1,0) = 255;
//        return @[[NSNumber numberWithInteger:kernel.at<double>(0,1)], [NSNumber numberWithInteger:kernel.at<double>(0,0)], [NSNumber numberWithInteger:kernel.at<double>(1,0)]];
    
    
//    return @[[NSNumber numberWithInteger:maxPoint.x], [NSNumber numberWithInteger:maxPoint.y], [NSNumber numberWithInteger:maxVal]];
    
//    return @[[NSNumber numberWithInteger:idx[0]], [NSNumber numberWithInteger:idx[1]], [NSNumber numberWithInteger:maxVal]];


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
