// Native macOS GUI test bridge. Keep this bundle/executable unchanged after
// permission approval. Jobs are restricted to the staged TR4W test bundle.
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <Carbon/Carbon.h>

#ifndef TR4W_AX_PROBE
#define TR4W_AX_PROBE 0
#endif

#ifndef TR4W_RUNNER_NEXT
#define TR4W_RUNNER_NEXT 0
#endif

static NSString *Root(void)
{
   return [NSHomeDirectory() stringByAppendingPathComponent:@"tr4w-gui-test"];
}

static NSString *ExpectedExecutable(void)
{
   return [Root() stringByAppendingPathComponent:@"app/TR4W.app/Contents/MacOS/tr4w"];
}

static NSString *OutputPath;

static void WriteResult(NSDictionary *result)
{
   NSError *error = nil;
   NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
   if (data == nil || ![data writeToFile:OutputPath options:NSDataWritingAtomic error:&error])
   {
      fprintf(stderr, "Cannot write pilot result: %s\n", error.description.UTF8String);
      exit(2);
   }
}

static void Finish(NSDictionary *result)
{
   WriteResult(result);
   [NSApp terminate:nil];
}

static void Fail(NSString *message)
{
   Finish(@{@"passed": @NO, @"error": message});
}

static NSDictionary *PermissionStatus(void)
{
   return @{@"accessibility": @(AXIsProcessTrusted()),
      @"screen_recording": @(TR4W_AX_PROBE ? NO : CGPreflightScreenCaptureAccess()),
      @"probe_only": @(TR4W_AX_PROBE),
      @"bundle_id": NSBundle.mainBundle.bundleIdentifier ?: @"",
      @"executable": NSBundle.mainBundle.executablePath ?: @"",
      @"pid": @(NSProcessInfo.processInfo.processIdentifier)};
}

static NSRunningApplication *OwnedApplication(NSDictionary *job)
{
   pid_t pid = [job[@"pid"] intValue];
   NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
   NSString *actual = app.executableURL.path.stringByResolvingSymlinksInPath;
   if (pid <= 0 || app == nil || ![actual isEqualToString:ExpectedExecutable().stringByResolvingSymlinksInPath])
   {
      return nil;
   }
   return app;
}

static BOOL RequireForeground(NSRunningApplication *app)
{
   if (NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier != app.processIdentifier)
   {
      Fail(@"TR4W must be foreground before input or capture");
      return NO;
   }
   return YES;
}

static id Attribute(AXUIElementRef node, CFStringRef name, NSMutableDictionary *errors)
{
   CFTypeRef value = NULL;
   AXError status = AXUIElementCopyAttributeValue(node, name, &value);
   if (status != kAXErrorSuccess)
   {
      errors[(__bridge NSString *)name] = @(status);
      return nil;
   }
   return CFBridgingRelease(value);
}

static NSMutableDictionary *DescribeElement(AXUIElementRef node, NSArray *path, NSUInteger identifier)
{
   NSMutableDictionary *errors = [NSMutableDictionary dictionary];
   NSMutableDictionary *record = [@{@"path": path, @"id": @(identifier), @"attribute_errors": errors} mutableCopy];
   CFArrayRef attributes = NULL;
   AXError attributeStatus = AXUIElementCopyAttributeNames(node, &attributes);
   record[@"attribute_names_status"] = @(attributeStatus);
   if (attributeStatus == kAXErrorSuccess)
   {
      record[@"supported_attributes"] = CFBridgingRelease(attributes);
   }
   CFArrayRef actions = NULL;
   AXError actionStatus = AXUIElementCopyActionNames(node, &actions);
   record[@"action_names_status"] = @(actionStatus);
   if (actionStatus == kAXErrorSuccess)
   {
      record[@"supported_actions"] = CFBridgingRelease(actions);
   }
   NSArray *names = @[@"AXRole", @"AXSubrole", @"AXTitle", @"AXDescription", @"AXValue", @"AXEnabled", @"AXFocused"];
   for (NSString *name in names)
   {
      id value = Attribute(node, (__bridge CFStringRef)name, errors);
      if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class])
      {
         record[name] = value;
      }
   }
   id position = Attribute(node, kAXPositionAttribute, errors);
   id size = Attribute(node, kAXSizeAttribute, errors);
   CGPoint point;
   CGSize bounds;
   if (position != nil && size != nil &&
      CFGetTypeID((__bridge CFTypeRef)position) == AXValueGetTypeID() &&
      CFGetTypeID((__bridge CFTypeRef)size) == AXValueGetTypeID() &&
      AXValueGetValue((__bridge AXValueRef)position, kAXValueCGPointType, &point) &&
      AXValueGetValue((__bridge AXValueRef)size, kAXValueCGSizeType, &bounds))
   {
      record[@"rectangle"] = @[@(point.x), @(point.y), @(bounds.width), @(bounds.height)];
   }
   return record;
}

static BOOL Walk(AXUIElementRef node, NSArray *path, NSMutableArray *records,
   CFMutableDictionaryRef visited, NSUInteger *identifier)
{
   CFNumberRef previous = CFDictionaryGetValue(visited, node);
   if (previous != NULL)
   {
      *identifier = [(__bridge NSNumber *)previous unsignedIntegerValue];
      return YES;
   }
   if (records.count >= 3000 || path.count > 32)
   {
      return NO;
   }
   *identifier = records.count;
   CFDictionarySetValue(visited, node, (__bridge CFNumberRef)@(*identifier));
   NSMutableDictionary *record = DescribeElement(node, path, *identifier);
   [records addObject:record];
   NSMutableArray *links = [NSMutableArray array];
   record[@"links"] = links;
   // A Cocoa container may expose document content through a relation other
   // than AXChildren. Record the relation and deduplicate remote AX identities.
   for (NSString *relation in @[@"AXChildren", @"AXContents", @"AXVisibleChildren", @"AXChildrenInNavigationOrder", @"AXWindows"])
   {
      NSArray *children = Attribute(node, (__bridge CFStringRef)relation, record[@"attribute_errors"]);
      if (children == nil)
      {
         continue;
      }
      if (![children isKindOfClass:NSArray.class])
      {
         record[@"unexpected_relation_type"] = relation;
         return NO;
      }
      for (NSUInteger index = 0; index < children.count; index++)
      {
         if (CFGetTypeID((__bridge CFTypeRef)children[index]) != AXUIElementGetTypeID())
         {
            record[@"unexpected_relation_element"] = relation;
            return NO;
         }
         NSUInteger target = 0;
         if (!Walk((__bridge AXUIElementRef)children[index], [path arrayByAddingObject:@(links.count)], records, visited, &target))
         {
            return NO;
         }
         [links addObject:@{@"attribute": relation, @"index": @(index), @"target": @(target)}];
      }
   }
   return YES;
}

static BOOL DescendantPath(NSArray *path, NSArray *parent)
{
   if (path.count < parent.count)
   {
      return NO;
   }
   for (NSUInteger index = 0; index < parent.count; index++)
   {
      if (![path[index] isEqual:parent[index]])
      {
         return NO;
      }
   }
   return YES;
}

static void ControlAction(NSDictionary *job, NSRunningApplication *app)
{
   if (!RequireForeground(app))
   {
      return;
   }
   NSDictionary *selector = job[@"selector"];
   if (![selector isKindOfClass:NSDictionary.class] || ![selector[@"window"] isKindOfClass:NSString.class] ||
      [selector[@"window"] length] == 0 || ![selector[@"role"] isKindOfClass:NSString.class] ||
      (selector[@"title"] == nil && selector[@"path"] == nil && selector[@"focused"] == nil))
   {
      Fail(@"Control action requires an owned window, role and explicit selector");
      return;
   }
   AXUIElementRef application = AXUIElementCreateApplication(app.processIdentifier);
   AXUIElementSetMessagingTimeout(application, 2.0);
   NSMutableArray *records = [NSMutableArray array];
   CFMutableDictionaryRef visited = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
   NSUInteger identifier = 0;
   BOOL complete = Walk(application, @[], records, visited, &identifier);
   CFRelease(application);
   NSArray *frames = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *record, NSDictionary *bindings)
   {
      (void)bindings;
      return [record[@"AXRole"] isEqual:@"AXWindow"] && [record[@"AXTitle"] containsString:selector[@"window"]];
   }]];
   NSMutableArray *matches = [NSMutableArray array];
   if (complete && frames.count == 1)
   {
      for (NSDictionary *record in records)
      {
         if (DescendantPath(record[@"path"], frames[0][@"path"]) &&
            [record[@"AXRole"] isEqual:selector[@"role"]] &&
            (selector[@"title"] == nil || [record[@"AXTitle"] isEqual:selector[@"title"]]) &&
            (selector[@"path"] == nil || [record[@"path"] isEqual:selector[@"path"]]) &&
            (selector[@"focused"] == nil || [record[@"AXFocused"] isEqual:selector[@"focused"]]))
         {
            [matches addObject:record];
         }
      }
   }
   if (matches.count != 1 || (matches[0][@"AXEnabled"] != nil && ![matches[0][@"AXEnabled"] boolValue]))
   {
      CFRelease(visited);
      Fail(@"Control is not uniquely enabled in the requested owned window");
      return;
   }
   NSDictionary *record = matches[0];
   AXUIElementRef selected = NULL;
   NSDictionary *nodes = (__bridge NSDictionary *)visited;
   for (id candidate in nodes)
   {
      if ([nodes[candidate] isEqual:record[@"id"]])
      {
         selected = (AXUIElementRef)CFRetain((__bridge CFTypeRef)candidate);
         break;
      }
   }
   CFRelease(visited);
   if (selected == NULL)
   {
      Fail(@"Resolved accessibility control is unavailable");
      return;
   }
   if (!RequireForeground(app))
   {
      CFRelease(selected);
      return;
   }
   AXError status;
   if ([job[@"operation"] isEqual:@"click"])
   {
      NSArray *rectangle = record[@"rectangle"];
      NSArray *frame = frames[0][@"rectangle"];
      if (rectangle.count != 4 || frame.count != 4)
      {
         CFRelease(selected);
         Fail(@"Click target has no valid owned window bounds");
         return;
      }
      CGPoint point = CGPointMake([rectangle[0] doubleValue] + [rectangle[2] doubleValue] / 2,
         [rectangle[1] doubleValue] + [rectangle[3] doubleValue] / 2);
      CGRect bounds = CGRectMake([frame[0] doubleValue], [frame[1] doubleValue], [frame[2] doubleValue], [frame[3] doubleValue]);
      AXUIElementRef hit = NULL;
      AXUIElementRef owner = AXUIElementCreateApplication(app.processIdentifier);
      AXUIElementSetMessagingTimeout(owner, 2.0);
      status = AXUIElementCopyElementAtPosition(owner, point.x, point.y, &hit);
      CFRelease(owner);
      BOOL matchesHit = NO;
      for (NSUInteger depth = 0; status == kAXErrorSuccess && hit != NULL && depth < 16; depth++)
      {
         if (CFEqual(hit, selected))
         {
            matchesHit = YES;
            break;
         }
         CFTypeRef parent = NULL;
         status = AXUIElementCopyAttributeValue(hit, kAXParentAttribute, &parent);
         CFRelease(hit);
         hit = parent != NULL && CFGetTypeID(parent) == AXUIElementGetTypeID() ? (AXUIElementRef)parent : NULL;
         if (parent != NULL && hit == NULL)
         {
            CFRelease(parent);
         }
      }
      if (hit != NULL)
      {
         CFRelease(hit);
      }
      if ([rectangle[2] doubleValue] <= 0 ||
         [rectangle[3] doubleValue] <= 0 || !CGRectContainsPoint(bounds, point) || !matchesHit)
      {
         CFRelease(selected);
         Fail(@"Click target is outside its window or its hit test changed");
         return;
      }
      if (!RequireForeground(app))
      {
         CFRelease(selected);
         return;
      }
      CGEventRef down = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, point, kCGMouseButtonLeft);
      CGEventRef up = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, point, kCGMouseButtonLeft);
      CGEventPost(kCGHIDEventTap, down);
      CGEventPost(kCGHIDEventTap, up);
      CFRelease(down);
      CFRelease(up);
      status = kAXErrorSuccess;
   }
   else
   {
      status = [job[@"operation"] isEqual:@"focus"] ?
         AXUIElementSetAttributeValue(selected, kAXFocusedAttribute, kCFBooleanTrue) :
         AXUIElementPerformAction(selected, kAXPressAction);
   }
   CFRelease(selected);
   Finish(@{@"passed": @(status == kAXErrorSuccess), @"status": @(status),
      @"target": record, @"error": status == kAXErrorSuccess ? @"" : @"Native accessibility action failed"});
}

static NSArray *HitTest(AXUIElementRef application, NSArray *points)
{
   NSMutableArray *results = [NSMutableArray array];
   for (NSArray *point in points)
   {
      if (![point isKindOfClass:NSArray.class] || point.count != 2)
      {
         continue;
      }
      AXUIElementRef element = NULL;
      AXError status = AXUIElementCopyElementAtPosition(application, [point[0] floatValue], [point[1] floatValue], &element);
      NSMutableDictionary *hit = [@{@"point": point, @"status": @(status)} mutableCopy];
      NSMutableArray *ancestors = [NSMutableArray array];
      hit[@"ancestors"] = ancestors;
      if (status == kAXErrorSuccess && element != NULL)
      {
         CFMutableSetRef visited = CFSetCreateMutable(NULL, 0, &kCFTypeSetCallBacks);
         for (NSUInteger index = 0; index < 16 && element != NULL; index++)
         {
            if (CFSetContainsValue(visited, element))
            {
               CFRelease(element);
               element = NULL;
               break;
            }
            CFSetAddValue(visited, element);
            NSMutableDictionary *record = DescribeElement(element, @[], index);
            [ancestors addObject:record];
            id parent = Attribute(element, kAXParentAttribute, record[@"attribute_errors"]);
            CFRelease(element);
            element = NULL;
            if (parent != nil && CFGetTypeID((__bridge CFTypeRef)parent) == AXUIElementGetTypeID())
            {
               element = (AXUIElementRef)CFRetain((__bridge CFTypeRef)parent);
            }
         }
         if (element != NULL)
         {
            CFRelease(element);
         }
         CFRelease(visited);
      }
      [results addObject:hit];
   }
   return results;
}

static void Capture(NSDictionary *job, NSRunningApplication *app)
{
   if (!CGPreflightScreenCaptureAccess())
   {
      Fail(@"Screen Recording permission is required");
      return;
   }
   if (!RequireForeground(app))
   {
      return;
   }
   [SCShareableContent getShareableContentExcludingDesktopWindows:YES onScreenWindowsOnly:YES
      completionHandler:^(SCShareableContent *content, NSError *error)
   {
      if (error != nil)
      {
         dispatch_async(dispatch_get_main_queue(), ^{ Fail(error.description); });
         return;
      }
      SCWindow *selected = nil;
      for (SCWindow *window in content.windows)
      {
         if (window.owningApplication.processID == app.processIdentifier && window.windowID == [job[@"window_id"] unsignedIntValue])
         {
            selected = window;
            break;
         }
      }
      if (selected == nil)
      {
         dispatch_async(dispatch_get_main_queue(), ^{ Fail(@"Requested owned window is not on screen"); });
         return;
      }
      SCContentFilter *filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:selected];
      SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
      config.width = (size_t)ceil(filter.contentRect.size.width * filter.pointPixelScale);
      config.height = (size_t)ceil(filter.contentRect.size.height * filter.pointPixelScale);
      config.showsCursor = NO;
      config.capturesAudio = NO;
      [SCScreenshotManager captureImageWithFilter:filter configuration:config
         completionHandler:^(CGImageRef image, NSError *captureError)
      {
         // Materialize the image before returning from this callback. The
         // CGImage's lifetime is not extended by capturing its raw pointer.
         NSBitmapImageRep *bitmap = image ? [[NSBitmapImageRep alloc] initWithCGImage:image] : nil;
         dispatch_async(dispatch_get_main_queue(), ^
         {
            if (captureError != nil || bitmap == nil)
            {
               Fail(captureError.description ?: @"Screen capture returned no image");
               return;
            }
            if (NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier != app.processIdentifier)
            {
               Fail(@"Foreground changed during capture");
               return;
            }
            NSString *png = [OutputPath.stringByDeletingPathExtension stringByAppendingPathExtension:@"png"];
            NSData *data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSError *writeError = nil;
            if (![data writeToFile:png options:NSDataWritingAtomic error:&writeError])
            {
               Fail(writeError.description);
               return;
            }
            Finish(@{@"passed": @YES, @"png": png, @"width": @(bitmap.pixelsWide), @"height": @(bitmap.pixelsHigh)});
         });
      }];
   }];
}

static void PerformJob(NSDictionary *job)
{
   NSString *operation = job[@"operation"];
   if ([operation isEqualToString:@"preflight"])
   {
      Finish(PermissionStatus());
      return;
   }
   if (!AXIsProcessTrusted())
   {
      Fail(@"Accessibility permission is required");
      return;
   }
   if (TR4W_AX_PROBE && ![operation isEqualToString:@"inspect"])
   {
      Fail(@"AX Probe supports read-only inspection only");
      return;
   }
   NSRunningApplication *app = OwnedApplication(job);
   if (app == nil)
   {
      Fail(@"PID does not belong to the staged TR4W executable");
      return;
   }
   if ([operation isEqualToString:@"inspect"])
   {
      AXUIElementRef element = AXUIElementCreateApplication(app.processIdentifier);
      AXUIElementSetMessagingTimeout(element, 2.0);
      NSMutableArray *records = [NSMutableArray array];
      CFMutableDictionaryRef visited = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
      NSUInteger identifier = 0;
      BOOL complete = Walk(element, @[], records, visited, &identifier);
      CFRelease(visited);
      NSArray *hits = HitTest(element, job[@"hit_points"] ?: @[]);
      CFRelease(element);
      if (!complete)
      {
         Fail(@"Accessibility tree exceeds pilot limits");
         return;
      }
      CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
      NSMutableArray *ownedWindows = [NSMutableArray array];
      for (NSDictionary *window in CFBridgingRelease(windows))
      {
         if ([window[(__bridge NSString *)kCGWindowOwnerPID] intValue] == app.processIdentifier)
         {
            [ownedWindows addObject:window];
         }
      }
      Finish(@{@"passed": @YES, @"pid": @(app.processIdentifier), @"tree": records, @"windows": ownedWindows, @"hit_tests": hits});
   }
   else if ([operation isEqualToString:@"activate"])
   {
      BOOL requested = [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
      Finish(@{@"passed": @(requested), @"pid": @(app.processIdentifier)});
   }
   else if ([operation isEqualToString:@"key"])
   {
      if (!RequireForeground(app))
      {
         return;
      }
      NSDictionary *keys = @{@"j": @(kVK_ANSI_J), @"q": @(kVK_ANSI_Q), @"w": @(kVK_ANSI_W),
         @"escape": @(kVK_Escape), @"return": @(kVK_Return), @"y": @(kVK_ANSI_Y),
         @"space": @(kVK_Space), @"tab": @(kVK_Tab), @"up": @(kVK_UpArrow), @"down": @(kVK_DownArrow),
         @"left": @(kVK_LeftArrow), @"right": @(kVK_RightArrow), @"home": @(kVK_Home), @"end": @(kVK_End),
         @"backspace": @(kVK_Delete), @"delete": @(kVK_ForwardDelete), @"pageup": @(kVK_PageUp), @"pagedown": @(kVK_PageDown),
         @"a": @(kVK_ANSI_A), @"f1": @(kVK_F1)};
      NSNumber *code = keys[job[@"key"]];
      if (code == nil)
      {
         Fail(@"Unsupported pilot key");
         return;
      }
      CGEventFlags flags = 0;
      for (NSString *modifier in job[@"modifiers"])
      {
         if ([modifier isEqualToString:@"command"])
         {
            flags |= kCGEventFlagMaskCommand;
         }
         else if ([modifier isEqualToString:@"control"])
         {
            flags |= kCGEventFlagMaskControl;
         }
         else if ([modifier isEqualToString:@"option"])
         {
            flags |= kCGEventFlagMaskAlternate;
         }
         else if ([modifier isEqualToString:@"shift"])
         {
            flags |= kCGEventFlagMaskShift;
         }
         else
         {
            Fail(@"Unsupported pilot modifier");
            return;
         }
      }
      CGEventRef down = CGEventCreateKeyboardEvent(NULL, code.unsignedShortValue, true);
      CGEventRef up = CGEventCreateKeyboardEvent(NULL, code.unsignedShortValue, false);
      CGEventSetFlags(down, flags);
      CGEventSetFlags(up, flags);
      CGEventPost(kCGHIDEventTap, down);
      CGEventPost(kCGHIDEventTap, up);
      CFRelease(down);
      CFRelease(up);
      Finish(@{@"passed": @YES, @"pid": @(app.processIdentifier)});
   }
   else if ([operation isEqual:@"focus"] || [operation isEqual:@"press"] || [operation isEqual:@"click"])
   {
      ControlAction(job, app);
   }
   else if ([operation isEqual:@"text"])
   {
      NSString *text = job[@"text"];
      if (![text isKindOfClass:NSString.class] || text.length == 0 || text.length > 4096)
      {
         Fail(@"Text input requires 1 to 4096 UTF-16 units");
         return;
      }
      if (!RequireForeground(app))
      {
         return;
      }
      __block BOOL complete = YES;
      [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByComposedCharacterSequences
         usingBlock:^(NSString *substring, NSRange range, NSRange enclosingRange, BOOL *stop)
      {
         (void)range;
         (void)enclosingRange;
         if (NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier != app.processIdentifier)
         {
            complete = NO;
            *stop = YES;
            return;
         }
         unichar characters[substring.length];
         [substring getCharacters:characters];
         CGEventRef down = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_A, true);
         CGEventRef up = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_A, false);
         CGEventKeyboardSetUnicodeString(down, substring.length, characters);
         CGEventKeyboardSetUnicodeString(up, substring.length, characters);
         CGEventPost(kCGHIDEventTap, down);
         CGEventPost(kCGHIDEventTap, up);
         CFRelease(down);
         CFRelease(up);
      }];
      Finish(@{@"passed": @(complete), @"error": complete ? @"" : @"Foreground changed during text input"});
   }
   else if ([operation isEqualToString:@"capture"])
   {
      Capture(job, app);
   }
   else
   {
      Fail(@"Unknown pilot operation");
   }
}

@interface PilotDelegate : NSObject <NSApplicationDelegate>
@end

@implementation PilotDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
   NSString *preflight = [NSBundle.mainBundle objectForInfoDictionaryKey:@"TR4WPreflightFilename"];
   if (preflight == nil)
   {
      preflight = TR4W_AX_PROBE ? @"mac-ax-probe-preflight.json" :
         (TR4W_RUNNER_NEXT ? @"mac-runner-next-preflight.json" : @"mac-preflight.json");
   }
   OutputPath = [[Root() stringByAppendingPathComponent:@"artifacts"] stringByAppendingPathComponent:preflight];
   NSArray *arguments = NSProcessInfo.processInfo.arguments;
   NSUInteger index = [arguments indexOfObject:@"--job"];
   if (index != NSNotFound && index + 1 < arguments.count)
   {
      NSString *path = [arguments[index + 1] stringByResolvingSymlinksInPath];
      NSString *jobs = [[Root() stringByAppendingPathComponent:@"jobs"] stringByAppendingString:@"/"];
      if (![path hasPrefix:jobs])
      {
         Fail(@"Job must be inside ~/tr4w-gui-test/jobs");
         return;
      }
      NSError *error = nil;
      NSData *data = [NSData dataWithContentsOfFile:path];
      NSDictionary *job = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
      if (![job isKindOfClass:NSDictionary.class])
      {
         Fail(error.description ?: @"Cannot read job JSON");
         return;
      }
      NSString *output = [job[@"output"] stringByResolvingSymlinksInPath];
      NSString *artifacts = [[Root() stringByAppendingPathComponent:@"artifacts"] stringByAppendingString:@"/"];
      if (![output hasPrefix:artifacts] || [[NSFileManager defaultManager] fileExistsAtPath:output])
      {
         Fail(@"Output must be a new file inside ~/tr4w-gui-test/artifacts");
         return;
      }
      OutputPath = output;
      PerformJob(job);
      return;
   }
   if ([arguments containsObject:@"--preflight"])
   {
      Finish(PermissionStatus());
      return;
   }
   [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
   [NSApp activateIgnoringOtherApps:YES];
   BOOL done = NO;
   BOOL screenRequired = !TR4W_AX_PROBE && !TR4W_RUNNER_NEXT;
   while (!done)
   {
      NSDictionary *status = PermissionStatus();
      NSAlert *alert = [[NSAlert alloc] init];
      NSString *name = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
      alert.messageText = [name stringByAppendingString:TR4W_AX_PROBE ? @" permission" : @" permissions"];
      alert.informativeText = [NSString stringWithFormat:@"Accessibility: %@\nScreen Recording: %@\n\n%@ This helper does not launch TR4W during permission setup.",
         [status[@"accessibility"] boolValue] ? @"granted" : @"not granted",
         !screenRequired ? @"not required" : ([status[@"screen_recording"] boolValue] ? @"granted" : @"not granted"),
         TR4W_AX_PROBE ? @"Only Accessibility is required for this read-only probe." :
            (TR4W_RUNNER_NEXT ? @"Grant Accessibility to this input runner. The existing GUI Pilot supplies screenshots." : [@"Grant these to " stringByAppendingString:name])];
      [alert addButtonWithTitle:@"Request Accessibility"];
      if (screenRequired)
      {
         [alert addButtonWithTitle:@"Request Screen Recording"];
      }
      [alert addButtonWithTitle:@"Close"];
      NSModalResponse response = [alert runModal];
      if (response == NSAlertFirstButtonReturn)
      {
         NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
         AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
         [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
         done = YES;
      }
      else if (screenRequired && response == NSAlertSecondButtonReturn)
      {
         CGRequestScreenCaptureAccess();
         [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];
         done = YES;
      }
      else
      {
         done = YES;
      }
   }
   Finish(PermissionStatus());
}
@end

int main(void)
{
   @autoreleasepool
   {
      [NSApplication sharedApplication];
      [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
      PilotDelegate *delegate = [[PilotDelegate alloc] init];
      NSApp.delegate = delegate;
      [NSApp run];
   }
   return 0;
}
