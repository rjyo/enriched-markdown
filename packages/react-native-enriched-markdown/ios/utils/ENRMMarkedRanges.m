#import "ENRMMarkedRanges.h"
#import "ENRMTextHitTest.h"

NSString *const ENRMMarkIdAttributeName = @"ENRMMarkId";
/// What a mark covered before it was painted: attribute key → original value
/// (NSNull when the key was absent).
static NSString *const ENRMMarkSavedAttributeName = @"ENRMMarkSaved";

@implementation ENRMMarkedRange
@end

static NSArray<NSAttributedStringKey> *ENRMMarkPaintedKeys(void)
{
  return @[ NSBackgroundColorAttributeName, NSUnderlineStyleAttributeName, NSUnderlineColorAttributeName ];
}

static void ENRMClearMarks(NSTextStorage *storage)
{
  NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
  NSMutableArray<NSDictionary *> *saved = [NSMutableArray array];
  [storage enumerateAttribute:ENRMMarkSavedAttributeName
                      inRange:NSMakeRange(0, storage.length)
                      options:0
                   usingBlock:^(NSDictionary *value, NSRange range, BOOL *stop) {
                     if (value) {
                       [ranges addObject:[NSValue valueWithRange:range]];
                       [saved addObject:value];
                     }
                   }];
  [ranges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger i, BOOL *stop) {
    NSRange range = rangeValue.rangeValue;
    [saved[i] enumerateKeysAndObjectsUsingBlock:^(NSAttributedStringKey key, id value, BOOL *innerStop) {
      if (value == [NSNull null]) {
        [storage removeAttribute:key range:range];
      } else {
        [storage addAttribute:key value:value range:range];
      }
    }];
    [storage removeAttribute:ENRMMarkSavedAttributeName range:range];
    [storage removeAttribute:ENRMMarkIdAttributeName range:range];
  }];
}

static BOOL ENRMHasMarks(NSAttributedString *text)
{
  __block BOOL found = NO;
  [text enumerateAttribute:ENRMMarkSavedAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if (value) {
                    found = YES;
                    *stop = YES;
                  }
                }];
  return found;
}

static void ENRMPaintMark(NSTextStorage *storage, NSRange range, NSString *markId, RCTUIColor *color, BOOL active)
{
  NSMutableArray<NSValue *> *pieces = [NSMutableArray array];
  NSMutableArray *saved = [NSMutableArray array];
  NSArray<NSAttributedStringKey> *keys = ENRMMarkPaintedKeys();
  [storage enumerateAttributesInRange:range
                              options:0
                           usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attrs, NSRange piece, BOOL *stop) {
                             [pieces addObject:[NSValue valueWithRange:piece]];
                             // Overlapping marks: keep the first mark's record of the original text.
                             if (attrs[ENRMMarkSavedAttributeName]) {
                               [saved addObject:[NSNull null]];
                               return;
                             }
                             NSMutableDictionary *original = [NSMutableDictionary dictionary];
                             for (NSAttributedStringKey key in keys) {
                               original[key] = attrs[key] ?: [NSNull null];
                             }
                             [saved addObject:original];
                           }];
  [pieces enumerateObjectsUsingBlock:^(NSValue *pieceValue, NSUInteger i, BOOL *stop) {
    if (saved[i] != [NSNull null]) {
      [storage addAttribute:ENRMMarkSavedAttributeName value:saved[i] range:pieceValue.rangeValue];
    }
  }];
  [storage addAttributes:@{
    NSBackgroundColorAttributeName : [color colorWithAlphaComponent:active ? 0.30 : 0.16],
    NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle),
    NSUnderlineColorAttributeName : active ? color : [color colorWithAlphaComponent:0.7],
    ENRMMarkIdAttributeName : markId,
  }
                   range:range];
}

void ENRMApplyMarkedRanges(ENRMPlatformTextView *textView, NSArray<ENRMMarkedRange *> *marks, NSUInteger base,
                           RCTUIColor *_Nullable color)
{
  NSTextStorage *storage = textView.textStorage;
  if (!storage) {
    return;
  }
  NSUInteger length = storage.length;
  NSMutableArray<ENRMMarkedRange *> *inside = [NSMutableArray array];
  for (ENRMMarkedRange *mark in marks) {
    if (mark.start >= base && mark.end > mark.start && mark.end <= base + length) {
      [inside addObject:mark];
    }
  }
  if (inside.count == 0 && !ENRMHasMarks(storage)) {
    return;
  }

  RCTUIColor *tint = color ?: [RCTUIColor systemGreenColor];
  [storage beginEditing];
  ENRMClearMarks(storage);
  // Inactive first so the active mark's stronger paint wins where they overlap.
  for (ENRMMarkedRange *mark in inside) {
    if (!mark.active) {
      ENRMPaintMark(storage, NSMakeRange(mark.start - base, mark.end - mark.start), mark.markId, tint, NO);
    }
  }
  for (ENRMMarkedRange *mark in inside) {
    if (mark.active) {
      ENRMPaintMark(storage, NSMakeRange(mark.start - base, mark.end - mark.start), mark.markId, tint, YES);
    }
  }
  [storage endEditing];
}

NSString *_Nullable ENRMMarkIdAtTap(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer)
{
  NSUInteger index = ENRMCharacterIndexForTap(textView, recognizer);
  if (index == NSNotFound) {
    return nil;
  }
  NSAttributedString *text = ENRMGetAttributedText(textView);
  if (index >= text.length) {
    return nil;
  }
  return [text attribute:ENRMMarkIdAttributeName atIndex:index effectiveRange:NULL];
}
