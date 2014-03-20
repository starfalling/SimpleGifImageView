//
//  SimpleGifImageView.m
//  SimpleGifImageView
//
//  Created by york <gyq5319920@gmail.com> on 3/19/14.
//  Copyright (c) 2014 Truecolor.Inc. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import <mach/mach.h>
#import "SimpleGifImageView.h"



// the following three methods are copied and modified from project:
// https://github.com/arielelkin/DrakingSampler/blob/master/UIImage%2BanimatedGIF.m
static int delayCentisecondsForImageAtIndex(CGImageSourceRef const source, size_t const i) {
  int delayCentiseconds = 1;
  CFDictionaryRef const properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
  if (properties) {
    CFDictionaryRef const gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
    if (gifProperties) {
      CFNumberRef const unclampedDelayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
      if (unclampedDelayTime) {
        delayCentiseconds = (int)lrint([(__bridge id) unclampedDelayTime doubleValue] * 100);
      }else{
        CFNumberRef const number = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
        delayCentiseconds = (int)lrint([(__bridge id) number doubleValue] * 100);
      }
    }
    CFRelease(properties);
  }
  return delayCentiseconds;
}
static int pairGCD(int a, int b) {
  if (a < b)
    return pairGCD(b, a);
  while (true) {
    int const r = a % b;
    if (r == 0)
      return b;
    a = b;
    b = r;
  }
}
static int vectorGCD(size_t const count, int const *const values) {
  int gcd = values[0];
  for (size_t i = 1; i < count; ++i) {
    gcd = pairGCD(values[i], gcd);
  }
  return gcd;
}









@interface SimpleGifImageView() {
  NSUInteger _currentFrameIndex;
  NSTimer *_timer;
  NSTimeInterval _timeInterval;
  CGImageRef *_imageRefs;
  NSUInteger _framesCount;
}
@end

@implementation SimpleGifImageView


- (void)dealloc {
  [self releaseImageRefs];
#if !__has_feature(objc_arc)
  [super dealloc];
#endif
}



- (void)setGifImageData:(NSData *)data {
  [self releaseImageRefs];
  
  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFTypeRef)data, nil);
  size_t const count = CGImageSourceGetCount(source);
  CGImageRef imageRefs[count];
  int delayCentiseconds[count];
  int totalDurationCentiseconds = 0;
  for (size_t i = 0; i < count; ++i) {
    imageRefs[i] = CGImageSourceCreateImageAtIndex(source, i, NULL);
    delayCentiseconds[i] = delayCentisecondsForImageAtIndex(source, i);
    totalDurationCentiseconds += delayCentiseconds[i];
  }
  int const gcd = vectorGCD(count, delayCentiseconds);
  _framesCount = totalDurationCentiseconds / gcd;
  _imageRefs = (CGImageRef *)calloc(_framesCount, sizeof(CGImageRef));
  for (size_t i=0, k=0; i < count; ++i) {
    _imageRefs[k++] = imageRefs[i];
    for (size_t j = delayCentiseconds[i] / gcd; j > 1; --j) {
      k++;
    }
  }
  
  
  _timeInterval = gcd/100.0;
  [self stopTimer];
  [self startTimer];
  
  CFRelease(source);
}

- (void)removeFromSuperview {
  [self stopTimer];
  [super removeFromSuperview];
}

- (void)releaseImageRefs {
  for (int i=0; i<_framesCount; i++) {
    if(_imageRefs[i]) CFRelease(_imageRefs[i]);
  }
  free(_imageRefs);
  _imageRefs = nil;
}

- (void)stopTimer {
  if (_timer) {
    [_timer invalidate];
    _timer = nil;
  }
}

- (void)startTimer {
  if (_framesCount <= 1) return;
  _timer = [NSTimer scheduledTimerWithTimeInterval:_timeInterval
                                            target:self
                                          selector:@selector(showNextFrame)
                                          userInfo:nil
                                           repeats:YES];
}



- (void)showNextFrame {
  _currentFrameIndex ++;
  if (_currentFrameIndex == _framesCount)
    _currentFrameIndex = 0;
  if (!_imageRefs[_currentFrameIndex]) return;
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
  [super drawRect:rect];
  if (!_imageRefs || !_imageRefs[_currentFrameIndex]) return;
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, 0, rect.size.height);
  CGContextScaleCTM(context, 1, -1);
  CGContextDrawImage(context, rect, _imageRefs[_currentFrameIndex]);
}

@end
