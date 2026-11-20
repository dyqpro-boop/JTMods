#import "HNModBootstrap.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

void hnmod_bootstrap_anchor(void) {
}

static void HNModRunStartup(void) {
    Class cls = NSClassFromString(@"HNModManager");
    if (!cls) {
        return;
    }

    SEL selector = sel_registerName("start");
    if ([cls respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)((id)cls, selector);
    }
}

__attribute__((constructor))
static void HNModBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

        __block id observer = [center addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                 object:nil
                                                  queue:[NSOperationQueue mainQueue]
                                             usingBlock:^(NSNotification * _Nonnull note) {
            HNModRunStartup();
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }];

        if ([UIApplication sharedApplication].delegate != nil) {
            HNModRunStartup();
        }
    });
}