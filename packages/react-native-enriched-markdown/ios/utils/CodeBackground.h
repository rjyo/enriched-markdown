#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CodeAttributeName;
// Horizontal room around an inline code span: CodeRenderer kerns padding +
// margin on each side, and CodeBackground widens the fill by the padding,
// leaving the margin as a gap to the surrounding text.
extern const CGFloat CodeHorizontalPadding;
extern const CGFloat CodeHorizontalMargin;

@interface CodeBackground : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;
- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
