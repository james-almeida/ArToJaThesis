//
//  StitchingWrapper.h
//  PanoDemo
//
//  Created by DJI on 15/7/30.
//  Copyright (c) 2015年 DJI. All rights reserved.
//

#ifndef Stitching_Header_h
#define Stitching_Header_h

namespace cv
{
    using std::vector;
}

bool stitch (const cv::vector <cv::Mat> & images, cv::Mat &result);

#endif
