/**
 * Copyright (c) Facebook, Inc. and its affiliates.
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
  NSArray<NSArray<NSNumber *> *> *_outputs;
  NSArray<NSString *> *_soutputRange;
  NSString *_extrapolateLeft;
  NSString *_extrapolateRight;
  NSUInteger _numVals;
  bool _hasStringOutput;
  bool _shouldRound;
  NSArray<NSTextCheckingResult*> *_matches;
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
    NSMutableArray<NSMutableArray<NSNumber *> *> *_outputRanges = [NSMutableArray array];

    _hasStringOutput = NO;
    for (id value in config[@"outputRange"]) {
      if ([value isKindOfClass:[NSNumber class]]) {
        [outputRange addObject:value];
      } else if ([value isKindOfClass:[NSString class]]) {
        NSMutableArray *output = [NSMutableArray array];
        [_outputRanges addObject:output];
        [soutputRange addObject:value];

        _matches = [regex matchesInString:value options:0 range:NSMakeRange(0, [value length])];
        for (NSTextCheckingResult *match in _matches) {
          NSString* strNumber = [value substringWithRange:match.range];
          [output addObject:[NSNumber numberWithDouble:strNumber.doubleValue]];
        }

        _hasStringOutput = YES;
        [outputRange addObject:[output objectAtIndex:0]];
      }
    }
    if (_hasStringOutput) {
      _numVals = [_matches count];
      NSString *value = [soutputRange objectAtIndex:0];
      _shouldRound = [value containsString:@"rgb"];
      _matches = [regex matchesInString:value options:0 range:NSMakeRange(0, [value length])];
      NSMutableArray<NSMutableArray<NSNumber *> *> *outputs = [NSMutableArray arrayWithCapacity:_numVals];
      NSUInteger size = [soutputRange count];
      for (NSUInteger j = 0; j < _numVals; j++) {
        NSMutableArray *output = [NSMutableArray arrayWithCapacity:size];
        [outputs addObject:output];
        for (int i = 0; i < size; i++) {
          [output addObject:[[_outputRanges objectAtIndex:i] objectAtIndex:j]];
        }
      }
      _outputs = [outputs copy];
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
    if (_numVals > 1) {
      NSString *text = _soutputRange[0];
      NSMutableString *formattedText = [NSMutableString stringWithString:text];
      NSUInteger i = _numVals;
      for (NSTextCheckingResult *match in [_matches reverseObjectEnumerator]) {
        CGFloat val = RCTInterpolateValueInRange(inputValue,
                                                          _inputRange,
                                                          _outputs[--i],
                                                          _extrapolateLeft,
                                                          _extrapolateRight);
        NSString *str;
        if (_shouldRound) {
          bool isAlpha = i == 3;
          CGFloat rounded = isAlpha ? round(val * 1000) / 1000 : round(val);
          str = isAlpha ? [NSString stringWithFormat:@"%1.3f", rounded] : [NSString stringWithFormat:@"%1.0f", rounded];
        } else {
          str = [NSString stringWithFormat:@"%1f", val];
        }

        [formattedText replaceCharactersInRange:[match range] withString:str];
      }
      self.stringValue = formattedText;
    } else {
      self.stringValue = [regex stringByReplacingMatchesInString:_soutputRange[0]
                                                 options:0
                                                   range:NSMakeRange(0, _soutputRange[0].length)
                                            withTemplate:[NSString stringWithFormat:@"%1f", interpolated]];
    }
  }
}

@end
