//
//  CDVAMapLocation.h
//  Created by tomisacat on 16/1/8.
//
//

#import <Cordova/CDVPlugin.h>


@interface CDVAMap4Yxt : CDVPlugin  

- (void)getCurrentPosition:(CDVInvokedUrlCommand *)command;

- (void)startUpdatePosition:(CDVInvokedUrlCommand *)command;

- (void)readUpdatePosition:(CDVInvokedUrlCommand *)command;

- (void)stopUpdatePosition:(CDVInvokedUrlCommand *)command;

- (void)showMap:(CDVInvokedUrlCommand *)command;

- (void)hideMap:(CDVInvokedUrlCommand *)command;

- (void)traceMap:(CDVInvokedUrlCommand *)command;

- (void)startScheduledPosition:(CDVInvokedUrlCommand *)command;

- (void)stopScheduledPosition:(CDVInvokedUrlCommand *)command;

@end
