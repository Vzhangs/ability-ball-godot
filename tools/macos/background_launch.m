#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static IMP originalShow;
static IMP originalPolicy;

static BOOL backgroundPolicy(NSApplication *application, SEL selector, NSApplicationActivationPolicy policy) {
    // Register a background UI process without LaunchServices automatically activating it.
    if (policy == NSApplicationActivationPolicyRegular) {
        policy = NSApplicationActivationPolicyAccessory;
    }
    return ((BOOL (*)(id, SEL, NSApplicationActivationPolicy))originalPolicy)(application, selector, policy);
}

static void backgroundActivate(id self, SEL selector) {
    // Godot activates the app and schedules activation timers even with open -g.
    // Leave activation to the user through macOS instead.
}

static void backgroundShow(NSWindow *window, SEL selector, id sender) {
    if (NSApp.isActive) {
        ((void (*)(id, SEL, id))originalShow)(window, selector, sender);
    } else {
        // Keep native rendering and the ability to focus the window by clicking it.
        [window orderBack:sender];
    }
}

__attribute__((constructor)) static void installBackgroundLaunch(void) {
    // Child tools (for example ffmpeg) must not inherit this Godot-only library.
    unsetenv("DYLD_INSERT_LIBRARIES");
    @autoreleasepool {
        Method activate = class_getInstanceMethod(objc_getClass("GodotApplication"), sel_registerName("activateApplication"));
        Method show = class_getInstanceMethod([NSWindow class], @selector(makeKeyAndOrderFront:));
        Method policy = class_getInstanceMethod([NSApplication class], @selector(setActivationPolicy:));
        if (!activate || !show || !policy) {
            fprintf(stderr, "Background launch: required Godot/AppKit methods are unavailable.\n");
            _exit(78);
        }
        originalPolicy = method_setImplementation(policy, (IMP)backgroundPolicy);
        method_setImplementation(activate, (IMP)backgroundActivate);
        originalShow = method_setImplementation(show, (IMP)backgroundShow);
    }
}
