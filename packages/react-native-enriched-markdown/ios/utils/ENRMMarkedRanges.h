#pragma once

#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Carries the id of the marked range a character belongs to.
extern NSString *const ENRMMarkIdAttributeName;

/// A host-supplied annotation: `[start, end)` in view-global offsets (text
/// segments' lengths summed in order), painted as a tinted background with an
/// underline. `active` paints it stronger.
@interface ENRMMarkedRange : NSObject
@property (nonatomic, copy) NSString *markId;
@property (nonatomic) NSUInteger start;
@property (nonatomic) NSUInteger end;
@property (nonatomic) BOOL active;
@end

#ifdef __cplusplus
extern "C" {
#endif

/// Repaints the marks that fall inside one text segment whose first character
/// sits at `base`. Clears the segment's previous marks first, restoring the
/// background and underline each mark covered, so a mark removed by the host
/// leaves the text exactly as rendered.
void ENRMApplyMarkedRanges(ENRMPlatformTextView *textView, NSArray<ENRMMarkedRange *> *marks, NSUInteger base,
                           RCTUIColor *_Nullable color);

/// The id of the mark under the tap, or nil.
NSString *_Nullable ENRMMarkIdAtTap(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
