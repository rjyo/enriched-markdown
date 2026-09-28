#import "CodeRenderer.h"
#import "CodeBackground.h"
#import "ENRMUIKit.h"
#import "FontUtils.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"
#import <React/RCTFont.h>

@implementation CodeRenderer

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{

  BlockStyle *blockStyle = [context getBlockStyle];

  RCTUIColor *codeColor = _config.codeColor;

  UIFont *blockFont = cachedFontFromBlockStyle(blockStyle, context);

  UIFontDescriptorSymbolicTraits traits = blockFont.fontDescriptor.symbolicTraits;
  UIFontWeight weight = (traits & UIFontDescriptorTraitBold) ? UIFontWeightBold : UIFontWeightRegular;

  // Paragraphs set their block style from a cached font and leave fontSize at
  // 0, which sized inline code at the system default; the resolved font is
  // the real (Dynamic Type-scaled) body size.
  CGFloat codeFontSize = _config.codeFontSize > 0 ? _config.codeFontSize : blockFont.pointSize;

  NSString *codeFontFamily = _config.codeFontFamily;
  UIFont *codeFont;
  if (codeFontFamily.length > 0) {
    NSString *weightStr = (weight == UIFontWeightBold) ? @"bold" : nil;
    codeFont = [RCTFont updateFont:nil
                        withFamily:codeFontFamily
                              size:@(codeFontSize)
                            weight:weightStr
                             style:nil
                           variant:nil
                   scaleMultiplier:1.0];
  } else {
    codeFont = [UIFont monospacedSystemFontOfSize:codeFontSize weight:weight];
  }

  NSUInteger start = output.length;

  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange range = [RenderContext rangeForRenderedContent:output start:start];
  if (range.length > 0) {
    NSDictionary *existingAttributes = [output attributesAtIndex:start effectiveRange:NULL];
    NSMutableDictionary *codeAttributes = [existingAttributes ?: @{} mutableCopy];

    codeAttributes[NSFontAttributeName] = codeFont;
    if (codeColor) {
      codeAttributes[NSForegroundColorAttributeName] = codeColor;
    }
    codeAttributes[CodeAttributeName] = @YES;

    // Store block line height directly for CodeBackground to use
    codeAttributes[@"BlockLineHeight"] = @(UIFontLineHeight(blockFont));

    // Kerning reserves horizontal room for the background's padding without
    // adding characters, so copy/select still yield the bare code.
    codeAttributes[NSKernAttributeName] = @0;
    [output setAttributes:codeAttributes range:range];
    [output addAttribute:NSKernAttributeName
                   value:@(CodeHorizontalPadding + CodeHorizontalMargin)
                   range:NSMakeRange(NSMaxRange(range) - 1, 1)];
    if (range.location > 0) {
      [output addAttribute:NSKernAttributeName
                     value:@(CodeHorizontalPadding + CodeHorizontalMargin)
                     range:NSMakeRange(range.location - 1, 1)];
    }
  }
}

@end
