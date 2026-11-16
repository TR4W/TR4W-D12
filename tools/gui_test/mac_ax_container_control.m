// Minimal Cocoa reproduction of a scroll view whose document/panels are
// generic NSControl instances, as in the installed Lazarus Cocoa widgetset.
#import <AppKit/AppKit.h>

static BOOL FilterHiddenChildren = NO;

@interface EnumeratedControl : NSControl
@end

@implementation EnumeratedControl
- (NSArray *)accessibilityChildren
{
   NSArray *children = self.subviews;
   if (FilterHiddenChildren)
   {
      NSMutableArray *visible = [NSMutableArray arrayWithCapacity:children.count];
      for (NSView *child in children)
      {
         if (!child.isHiddenOrHasHiddenAncestor)
         {
            [visible addObject:child];
         }
      }
      children = visible;
   }
   return NSAccessibilityUnignoredChildren(children);
}
@end

int main(int argc, const char *argv[])
{
   @autoreleasepool
   {
      [NSApplication sharedApplication];
      [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
      NSString *mode = argc > 1 ? @(argv[1]) : @"control";
      FilterHiddenChildren = [mode isEqualToString:@"visible"];
      Class containerClass = [mode isEqualToString:@"view"] ? NSView.class :
         (([mode isEqualToString:@"children"] || FilterHiddenChildren) ? EnumeratedControl.class : NSControl.class);
      NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(400, 400, 600, 260)
         styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
         backing:NSBackingStoreBuffered defer:NO];
      window.title = [@"AX container control: " stringByAppendingString:mode];
      NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 600, 260)];
      scroll.hasVerticalScroller = NO;
      scroll.hasHorizontalScroller = NO;
      NSView *document = [[containerClass alloc] initWithFrame:NSMakeRect(0, 0, 600, 260)];
      NSView *panel = [[containerClass alloc] initWithFrame:NSMakeRect(10, 20, 580, 210)];
      if ([mode isEqualToString:@"ignored"])
      {
         [document setAccessibilityElement:NO];
         [panel setAccessibilityElement:NO];
      }
      NSArray *titles = @[@"Save and close", @"Cancel", @"Save"];
      for (NSUInteger index = 0; index < titles.count; index++)
      {
         NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(20 + index * 180, 40, 150, 32)];
         button.title = titles[index];
         button.bezelStyle = NSBezelStyleRounded;
         button.enabled = index != 2;
         [panel addSubview:button];
      }
      NSButton *hiddenButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 90, 150, 32)];
      hiddenButton.title = @"Hidden button sentinel";
      hiddenButton.hidden = YES;
      [panel addSubview:hiddenButton];
      NSView *hiddenPanel = [[containerClass alloc] initWithFrame:NSMakeRect(0, 140, 200, 60)];
      NSButton *hiddenDescendant = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 180, 32)];
      hiddenDescendant.title = @"Hidden panel sentinel";
      [hiddenPanel addSubview:hiddenDescendant];
      hiddenPanel.hidden = YES;
      [document addSubview:hiddenPanel];
      [document addSubview:panel];
      scroll.documentView = document;
      window.contentView = scroll;
      [window makeKeyAndOrderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
      [NSApp run];
   }
   return 0;
}
