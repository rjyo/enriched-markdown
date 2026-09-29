#import "CodeBackground.h"
#import "ENRMUIKit.h"
#import "RenderContext.h"

NSString *const CodeAttributeName = @"Code";
const CGFloat CodeHorizontalPadding = 3.0;
const CGFloat CodeHorizontalMargin = 0.0;

static const CGFloat kCodeBackgroundCornerRadius = 4.0;
static const CGFloat kCodeBackgroundBorderWidth = 0.5;

@implementation CodeBackground {
  StyleConfig *_config;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super init];
  if (self) {
    _config = config;
  }
  return self;
}

- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin
{
  RCTUIColor *backgroundColor = _config.codeBackgroundColor;
  if (!backgroundColor)
    return;

  NSTextStorage *textStorage = layoutManager.textStorage;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphsToShow actualGlyphRange:NULL];
  if (charRange.location == NSNotFound || charRange.length == 0)
    return;

  [textStorage enumerateAttribute:CodeAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (!value || range.length == 0)
                           return;
                         if (NSIntersectionRange(range, charRange).length == 0)
                           return;

                         [self drawCodeBackgroundForRange:range
                                            layoutManager:layoutManager
                                            textContainer:textContainer
                                                  atPoint:origin
                                          backgroundColor:backgroundColor
                                              borderColor:self->_config.codeBorderColor];
                       }];
}

- (void)drawCodeBackgroundForRange:(NSRange)range
                     layoutManager:(NSLayoutManager *)layoutManager
                     textContainer:(NSTextContainer *)textContainer
                           atPoint:(CGPoint)origin
                   backgroundColor:(RCTUIColor *)backgroundColor
                       borderColor:(RCTUIColor *)borderColor
{
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  if (glyphRange.location == NSNotFound || glyphRange.length == 0)
    return;

  CGFloat referenceHeight = [self findReferenceHeightForRange:range textStorage:layoutManager.textStorage];

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphRange
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *tc, NSRange lineRange,
                                            BOOL *stop) {
                                 NSRange intersect = NSIntersectionRange(lineRange, glyphRange);
                                 if (intersect.length == 0)
                                   return;

                                 BOOL isFirst = (intersect.location == glyphRange.location);
                                 BOOL isLast = (NSMaxRange(intersect) == NSMaxRange(glyphRange));

                                 CGRect finalRect;
                                 if (isFirst || isLast) {
                                   // Precise bounds are only required for the start and end of the span.
                                   // Selection rects, not boundingRectForGlyphRange: on a line shorter
                                   // than the font's natural height the bounding rect balloons ~20pt
                                   // sideways, while the enclosing rects stay on the glyphs.
                                   __block CGRect textRect = CGRectNull;
                                   [layoutManager
                                       enumerateEnclosingRectsForGlyphRange:intersect
                                                   withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                                            inTextContainer:textContainer
                                                                 usingBlock:^(CGRect enclosing, BOOL *stopEnclosing) {
                                                                   textRect = CGRectUnion(textRect, enclosing);
                                                                 }];
                                   if (CGRectIsNull(textRect))
                                     return;
                                   finalRect = CGRectMake(textRect.origin.x + origin.x, textRect.origin.y + origin.y,
                                                          textRect.size.width, textRect.size.height);

                                   // For multi-line, extend the first line to the right edge of the fragment
                                   if (isFirst && !isLast) {
                                     finalRect.size.width =
                                         (usedRect.origin.x + usedRect.size.width + origin.x) - finalRect.origin.x;
                                   }
                                 } else {
                                   // OPTIMIZATION: Middle lines use the usedRect of the fragment directly
                                   finalRect = CGRectMake(usedRect.origin.x + origin.x, usedRect.origin.y + origin.y,
                                                          usedRect.size.width, usedRect.size.height);
                                 }

                                 // Grow into the kerned gap CodeRenderer reserved. The trailing kern
                                 // already widens the last glyph's advance by padding + margin, so
                                 // the right edge gives the margin back. A span starting a line has
                                 // no kerned gap before it, so it keeps its left edge.
                                 CGFloat lineStart = usedRect.origin.x + origin.x;
                                 if (isFirst && finalRect.origin.x - lineStart >= CodeHorizontalPadding - 0.5) {
                                   finalRect.origin.x -= CodeHorizontalPadding;
                                   finalRect.size.width += CodeHorizontalPadding;
                                 }
                                 if (isLast) {
                                   finalRect.size.width -= CodeHorizontalMargin;
                                 }

                                 // Ensure consistent height and no gaps
                                 if (finalRect.size.height < referenceHeight) {
                                   finalRect.size.height = referenceHeight;
                                 }

                                 [self drawBackgroundAndBorders:finalRect
                                                backgroundColor:backgroundColor
                                                    borderColor:borderColor
                                                        isFirst:isFirst
                                                         isLast:isLast];
                               }];
}

#pragma mark - Drawing Logic

- (void)drawBackgroundAndBorders:(CGRect)rect
                 backgroundColor:(RCTUIColor *)backgroundColor
                     borderColor:(RCTUIColor *)borderColor
                         isFirst:(BOOL)isFirst
                          isLast:(BOOL)isLast
{
  UIBezierPath *path = [self pathForRect:rect isFirst:isFirst isLast:isLast];
  [backgroundColor setFill];
  [path fill];

  if (borderColor) {
    [borderColor setStroke];
    UIBezierPath *strokePath =
        (isFirst && isLast) ? path : [self openBorderPathForRect:rect isFirst:isFirst isLast:isLast];
    strokePath.lineWidth = kCodeBackgroundBorderWidth;
    BezierPathSetRoundStyle(strokePath);
    [strokePath stroke];
  }
}

- (UIBezierPath *)pathForRect:(CGRect)rect isFirst:(BOOL)isFirst isLast:(BOOL)isLast
{
#if !TARGET_OS_OSX
  UIRectCorner corners = 0;
  if (isFirst)
    corners |= (UIRectCornerTopLeft | UIRectCornerBottomLeft);
  if (isLast)
    corners |= (UIRectCornerTopRight | UIRectCornerBottomRight);

  return [UIBezierPath bezierPathWithRoundedRect:rect
                               byRoundingCorners:corners
                                     cornerRadii:CGSizeMake(kCodeBackgroundCornerRadius, kCodeBackgroundCornerRadius)];
#else
  // NSBezierPath doesn't support per-corner rounding — use uniform corner radius
  CGFloat cornerRadius = (isFirst || isLast) ? kCodeBackgroundCornerRadius : 0;
  return UIBezierPathWithRoundedRect(rect, cornerRadius);
#endif
}

- (UIBezierPath *)openBorderPathForRect:(CGRect)rect isFirst:(BOOL)isFirst isLast:(BOOL)isLast
{
  UIBezierPath *path = [UIBezierPath bezierPath];
  CGFloat r = kCodeBackgroundCornerRadius;
  CGFloat inset = kCodeBackgroundBorderWidth / 2.0;
  CGRect insetRect = CGRectInset(rect, inset, inset);

  if (isFirst) {
    [path moveToPoint:CGPointMake(CGRectGetMaxX(rect), insetRect.origin.y)];
    BezierPathAddLine(path, CGPointMake(insetRect.origin.x + r, insetRect.origin.y));
    BezierPathAddQuadCurve(path, CGPointMake(insetRect.origin.x, insetRect.origin.y + r),
                           CGPointMake(insetRect.origin.x, insetRect.origin.y));
    BezierPathAddLine(path, CGPointMake(insetRect.origin.x, CGRectGetMaxY(insetRect) - r));
    BezierPathAddQuadCurve(path, CGPointMake(insetRect.origin.x + r, CGRectGetMaxY(insetRect)),
                           CGPointMake(insetRect.origin.x, CGRectGetMaxY(insetRect)));
    BezierPathAddLine(path, CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(insetRect)));
  } else if (isLast) {
    [path moveToPoint:CGPointMake(rect.origin.x, insetRect.origin.y)];
    BezierPathAddLine(path, CGPointMake(CGRectGetMaxX(insetRect) - r, insetRect.origin.y));
    BezierPathAddQuadCurve(path, CGPointMake(CGRectGetMaxX(insetRect), insetRect.origin.y + r),
                           CGPointMake(CGRectGetMaxX(insetRect), insetRect.origin.y));
    BezierPathAddLine(path, CGPointMake(CGRectGetMaxX(insetRect), CGRectGetMaxY(insetRect) - r));
    BezierPathAddQuadCurve(path, CGPointMake(CGRectGetMaxX(insetRect) - r, CGRectGetMaxY(insetRect)),
                           CGPointMake(CGRectGetMaxX(insetRect), CGRectGetMaxY(insetRect)));
    BezierPathAddLine(path, CGPointMake(rect.origin.x, CGRectGetMaxY(insetRect)));
  } else {
    [path moveToPoint:CGPointMake(rect.origin.x, insetRect.origin.y)];
    BezierPathAddLine(path, CGPointMake(CGRectGetMaxX(rect), insetRect.origin.y));
    [path moveToPoint:CGPointMake(rect.origin.x, CGRectGetMaxY(insetRect))];
    BezierPathAddLine(path, CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(insetRect)));
  }
  return path;
}

#pragma mark - Helpers

- (CGFloat)findReferenceHeightForRange:(NSRange)range textStorage:(NSTextStorage *)textStorage
{
  if (range.location == NSNotFound || range.length == 0 || !textStorage) {
    return [_config paragraphFontSize] * 1.2;
  }
  NSNumber *lineHeightValue = [textStorage attribute:@"BlockLineHeight" atIndex:range.location effectiveRange:NULL];
  return lineHeightValue ? [lineHeightValue doubleValue] : ([_config paragraphFontSize] * 1.2);
}

@end