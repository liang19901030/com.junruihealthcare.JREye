//
//  JREye.h
//  HelloCordova
//
//  Created by 路亮亮 on 16/3/15.
//
//

#import <Cordova/CDVPlugin.h>

@interface JREye : CDVPlugin

//跳转到拍照，视频界面
- (void)jrEyeTakePhotos:(CDVInvokedUrlCommand*)command;

@end