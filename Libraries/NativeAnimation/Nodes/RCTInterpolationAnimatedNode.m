/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTInterpolationAnimatedNode.h"

#import "RCTAnimationUtils.h"

NSRegularExpression *regex;

@implementation RCTInterpolationAnimatedNode
{
  __weak RCTValueAnimatedNode *_parentNode;
  NSArray<NSNumber *> *_inputRange;
  NSArray<NSNumber *> *_outputRange;
  NSArray<NSString *> *_soutputRange;
  NSString *_extrapolateLeft;
  NSString *_extrapolateRight;
  bool _hasStringOutput;
}

- (instancetype)initWithTag:(NSNumber *)tag
                     config:(NSDictionary<NSString *, id> *)config
{
  if (!regex) {
    regex = [NSRegularExpression regularExpressionWithPattern:@"[0-9.-]+" options:NSRegularExpressionCaseInsensitive error:nil];
  }
  if ((self = [super initWithTag:tag config:config])) {
    _inputRange = [config[@"inputRange"] copy];
    NSMutableArray *outputRange = [NSMutableArray array];
    NSMutableArray *soutputRange = [NSMutableArray array];

    _hasStringOutput = NO;
    for (id value in config[@"outputRange"]) {
      if ([value isKindOfClass:[NSNumber class]]) {
        [outputRange addObject:value];
      } else if ([value isKindOfClass:[NSString class]]) {
        [soutputRange addObject:value];
        NSTextCheckingResult* match = [regex firstMatchInString:value options:NSMatchingAnchored range:NSMakeRange(0, [value length])];
        NSString* strNumber = [value substringWithRange:match.range];
        [outputRange addObject:[NSNumber numberWithDouble:strNumber.doubleValue]];
        _hasStringOutput = YES;
      }
    }
    _outputRange = [outputRange copy];
    _soutputRange = [soutputRange copy];
    _extrapolateLeft = config[@"extrapolateLeft"];
    _extrapolateRight = config[@"extrapolateRight"];
  }
  return self;
}

- (void)onAttachedToNode:(RCTAnimatedNode *)parent
{
  [super onAttachedToNode:parent];
  if ([parent isKindOfClass:[RCTValueAnimatedNode class]]) {
    _parentNode = (RCTValueAnimatedNode *)parent;
  }
}

- (void)onDetachedFromNode:(RCTAnimatedNode *)parent
{
  [super onDetachedFromNode:parent];
  if (_parentNode == parent) {
    _parentNode = nil;
  }
}

- (void)performUpdate
{
  [super performUpdate];
  if (!_parentNode) {
    return;
  }

  CGFloat inputValue = _parentNode.value;

  CGFloat interpolated = RCTInterpolateValueInRange(inputValue,
                                                    _inputRange,
                                                    _outputRange,
                                                    _extrapolateLeft,
                                                    _extrapolateRight);
  self.value = interpolated;
  if (_hasStringOutput) {
    self.stringValue = [regex stringByReplacingMatchesInString:_soutputRange[0]
                                                 options:0
                                                   range:NSMakeRange(0, _soutputRange[0].length)
                                            withTemplate:[NSString stringWithFormat:@"%.3f", interpolated]];
  }
}

@end
