//
//  CDVAMapLocation.h
//  Created by tomisacat on 16/1/8.
//
//

#import <Cordova/CDVPlugin.h>


@interface CDVAMap4Yxt : CDVPlugin  

// 单次定位回调
- (void)getCurrentPosition:(CDVInvokedUrlCommand *)command;

- (void)startUpdatePosition:(CDVInvokedUrlCommand *)command;

- (void)readUpdatePosition:(CDVInvokedUrlCommand *)command;

- (void)stopUpdatePosition:(CDVInvokedUrlCommand *)command;

//- (void)showMap:(CDVInvokedUrlCommand *)command;
//
//- (void)hideMap:(CDVInvokedUrlCommand *)command;
//
//- (void)traceMap:(CDVInvokedUrlCommand *)command;

// 开启定时定位
- (void)startScheduledPosition:(CDVInvokedUrlCommand *)command;
// 关闭定时定位
- (void)stopScheduledPosition:(CDVInvokedUrlCommand *)command;
// 开启导航
- (void)openNav:(CDVInvokedUrlCommand *)command;
// 检查定位权限
- (void)checkLocationAuth:(CDVInvokedUrlCommand *)command;

@end
