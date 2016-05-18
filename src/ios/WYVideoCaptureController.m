//
//  WYVideoCaptureController.m
//  WYAVFoundation
//
//  Created by 王俨 on 15/12/31.
//  Copyright © 2015年 wangyan. All rights reserved.
//

#import "WYVideoCaptureController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIView+Extension.h"
#import "NSTimer+Addtion.h"
#import "ProgressView.h"
#import "UIView+AutoLayoutViews.h"
#import "JRMediaFileManage.h"
#import "PictureScanViewController.h"

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);
#define kAnimationDuration 0.2
#define kTimeChangeDuration 0.1
#define kVideoTotalTime 30
#define kVideoLimit 10

@interface WYVideoCaptureController (){
    UIBarButtonItem *_leftItem;
    CGRect _leftBtnFrame;
    CGRect _centerBtnFrame;
    CGRect _rightBtnFrame;
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
    BOOL _isLeftEye;
    BOOL _isLeftTouchDown;
    BOOL _isRightTouchDown;
    BOOL _isLeftTouchUpInside;
    BOOL _isRightToucUpInside;
    int _leftTakenPictureCount;
    int _rightTakenPictureCount;
}
@property (nonatomic, strong) UISlider *wbSlider;
@property (nonatomic, strong) UIView *viewContainer;
@property (nonatomic, strong) ProgressView *progressView;
@property (nonatomic, strong) UIButton *leftBtn;
@property (nonatomic, strong) UIButton *centerBtn;
@property (nonatomic, strong) UIButton *rightBtn;
@property (nonatomic, strong) UIButton *cameraBtn;
@property (nonatomic, strong) UIView *toolView;
@property (nonatomic, strong) UIButton *ISOBtn;
@property (nonatomic, strong) UIButton *whiteBalanceBtn;
@property (nonatomic, strong) UIView *whiteBalanceView;

/// 负责输入和输出设备之间数据传递
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *captureDevice;
/// 负责从AVCaptureDevice获取数据
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
/// 照片输出流
@property (nonatomic, strong) AVCaptureStillImageOutput *captureStillImageOutput;
/// 相机拍摄预览层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@end

@implementation WYVideoCaptureController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self initTakenParameters];
    [self ChangeToLeft:YES];
    [self setupCaptureView];
    self.view.backgroundColor = RGB(0x16161b);
    
    if (_isScan) {
        [self pushToPictureScan:NO];
    }else{
        [self cleanOlderData];
    }
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [_captureSession startRunning];
    [self configureNavgationBar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_captureSession stopRunning];
}

- (void)dealloc {
    NSLog(@"我是拍照控制器,我被销毁了");
}

- (void)configureNavgationBar{
    //将status bar 文本颜色设置为白色
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.navigationBar.barTintColor = RGB(0x000000);
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], NSForegroundColorAttributeName, [UIFont boldSystemFontOfSize:18.f], NSFontAttributeName, nil]];
    
    _leftItem = [[UIBarButtonItem alloc] initWithTitle:@"取消"
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(leftBarButtonItemAction)];
    self.navigationItem.leftBarButtonItem = _leftItem;
}

- (void)leftBarButtonItemAction{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cleanOlderData{
    [[JRMediaFileManage shareInstance] deleteAllFiles];
}

- (void)setupCaptureView {
    // 1.初始化会话
    _captureSession = [[AVCaptureSession alloc] init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
        [_captureSession setSessionPreset:AVCaptureSessionPresetPhoto]; // 设置分辨率
    }
    // 2.获得输入设备
    self.captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    [self wbSliderMethod:_wbSlider];
    if (_captureDevice == nil) {
        NSLog(@"获取输入设备失败");
        return;
    }
    // 4.根据输入设备初始化设备输入对象,用于获得输入数据
    NSError *error = nil;
    _captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:&error];
    if (error) {
        NSLog(@"创建设备输入对象失败 -- error = %@", error);
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"未获得相机权限，请到设置中授权后再尝试。" message:nil preferredStyle:UIAlertControllerStyleAlert];
        
        // Create the actions.
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self dismissViewControllerAnimated:YES completion:^{
                
            }];
        }];
        // Add the actions.
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    // 初始化图片设备输出对象
    _captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    _captureStillImageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG}; // 输出设置
    // 6.将设备添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
    }
    // 7.将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureStillImageOutput]) {
        [_captureSession addOutput:_captureStillImageOutput];
    }
    // 8.创建视频预览层
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    CALayer *layer = _viewContainer.layer;
    layer.masksToBounds = YES;
    _captureVideoPreviewLayer.frame = layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [layer insertSublayer:_captureVideoPreviewLayer atIndex:0];
    [self addNotificationToCaptureDevice:_captureDevice];
}

#pragma mark - CaptureMethod
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *captureDevice in devices) {
        if (captureDevice.position == position) {
            return captureDevice;
        }
    }
    return nil;
}

/// 改变设备属性的统一方法
///
/// @param propertyChange 属性改变操作
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange {
    AVCaptureDevice *captureDevice = _captureDeviceInput.device;
    NSError *error = nil;
    // 注意:在改变属性之前一定要先调用lockForConfiguration;调用完成之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    } else {
        NSLog(@"更改设备属性错误 -- error = %@", error);
    }
}

#pragma mark - Notification
/// 给输入设备添加通知
- (void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevie {
    // 注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(areaChanged:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevie];
}
/// 移除设备通知
- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

- (void)areaChanged:(NSNotification *)n {
    
}

#pragma mark - UI设计
- (void)setupUI {
    [self prepareUI];
    
    [self.view addSubview:_viewContainer];
    //[self.view addSubview:_progressView];
    [self.view addSubview:self.whiteBalanceView];
    [self.view addSubview:self.wbSlider];
    [self.view addSubview:self.toolView];
    [self.view addSubview:self.ISOBtn];
    [self.view addSubview:self.whiteBalanceBtn];
    
    [self.view addSubview:_leftBtn];
    [self.view addSubview:_centerBtn];
    [self.view addSubview:_rightBtn];
    [self.view addSubview:_cameraBtn];
    
    CGFloat viewContainerHeight = APP_HEIGHT-64-CGRectGetHeight(self.toolView.bounds);
    _viewContainer.frame = CGRectMake(0, 64, APP_WIDTH, viewContainerHeight);
    _progressView.frame = CGRectMake(0, CGRectGetMaxY(_viewContainer.frame), APP_WIDTH, 5);
    CGFloat btnW = 40;
    CGFloat leftBtnX = (APP_WIDTH - 3 * btnW - 2 * 32) *0.5;
    CGFloat leftBtnY = APP_HEIGHT-62-btnW;
    
    _leftBtnFrame = CGRectMake(leftBtnX, leftBtnY, btnW, btnW);
    _centerBtnFrame = CGRectOffset(_leftBtnFrame, 32 + btnW, 0);
    _rightBtnFrame = CGRectOffset(_centerBtnFrame, 32 + btnW, 0);
    [self restoreBtn];
    _cameraBtn.frame = CGRectMake((APP_WIDTH - 67) * 0.5, APP_HEIGHT-62, 62, 62);
}
- (void)prepareUI {
    _viewContainer = [[UIView alloc] init];
    //添加滑动手势
    UISwipeGestureRecognizer *leftSwipGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
    leftSwipGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    [_viewContainer addGestureRecognizer:leftSwipGestureRecognizer];
    
    UISwipeGestureRecognizer *rightSwipGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
    rightSwipGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [_viewContainer addGestureRecognizer:rightSwipGestureRecognizer];
    
    _progressView = [[ProgressView alloc] initWithFrame:CGRectMake(0, APP_WIDTH + 44, APP_WIDTH, 5)];
    _progressView.totalTime = kVideoTotalTime;
    
    _leftBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_leftBtn setTitle:@"左眼" forState:UIControlStateNormal];
    [_leftBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _leftBtn.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [_leftBtn addTarget:self action:@selector(leftBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    _centerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_centerBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_centerBtn setTitle:@"左眼" forState:UIControlStateNormal];
    _centerBtn.titleLabel.font = [UIFont systemFontOfSize:15.0];
    _rightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_rightBtn setTitle:@"右眼" forState:UIControlStateNormal];
    [_rightBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _rightBtn.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [_rightBtn addTarget:self action:@selector(rightBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    _cameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_cameraBtn setImage:[UIImage imageNamed:@"takePhoto"] forState:UIControlStateNormal];
    [_cameraBtn addTarget:self action:@selector(cameraBtnTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraBtn addTarget:self action:@selector(cameraBtnTouchDown:) forControlEvents:UIControlEventTouchDown];
}

#pragma mark - View
- (UIButton *)ISOBtn{
    if (!_ISOBtn) {
        UIImage *ISOImg = [UIImage imageNamed:@"ISOicon"];
        CGFloat ISOWidth = ISOImg.size.width;
        CGFloat ISOHeight = ISOImg.size.height;
        CGFloat ISOOriginX = APP_WIDTH-(30.0f/2.0f)-ISOWidth;
        CGFloat ISOOriginY = 64.0f + (45.0f/2.0f);
        _ISOBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _ISOBtn.frame = CGRectMake(ISOOriginX, ISOOriginY, ISOWidth, ISOHeight);
        [_ISOBtn setBackgroundImage:ISOImg forState:UIControlStateNormal];
        [_ISOBtn addTarget:self action:@selector(ISOBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _ISOBtn;
}

- (UIButton *)whiteBalanceBtn{
    if (!_whiteBalanceBtn) {
        UIImage *whiteBalanceImg = [UIImage imageNamed:@"white-balance-icon"];
        CGFloat whiteBalanceWidth = whiteBalanceImg.size.width;
        CGFloat whiteBalanceHeight = whiteBalanceImg.size.height;
        CGFloat whiteBalanceOriginX = APP_WIDTH-(30.0f/2.0f)-whiteBalanceWidth;
        CGFloat whiteBalanceOriginY = CGRectGetMaxY(_ISOBtn.frame) + (10.0f/2.0f);
        _whiteBalanceBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _whiteBalanceBtn.frame = CGRectMake(whiteBalanceOriginX, whiteBalanceOriginY, whiteBalanceWidth, whiteBalanceHeight);
        [_whiteBalanceBtn setBackgroundImage:whiteBalanceImg forState:UIControlStateNormal];
        [_whiteBalanceBtn addTarget:self action:@selector(whiteBalanceBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _whiteBalanceBtn;
}

- (UIView *)toolView{
    if (!_toolView) {
        CGFloat toolWidth = APP_WIDTH;
        CGFloat toolHeight = 100.0f;
        CGFloat toolOriginX = 0.0f;
        CGFloat toolOriginY = APP_HEIGHT-toolHeight;
        _toolView = [[UIView alloc] initWithFrame:CGRectMake(toolOriginX, toolOriginY, toolWidth, toolHeight)];
        _toolView.backgroundColor = RGB(0x000000);
    }
    return _toolView;
}

- (UIView *)whiteBalanceView{
    if (!_whiteBalanceView) {
        CGFloat width = 553.0f/2.0f;
        CGFloat height = 70.0f/2.0f;
        CGFloat originX = (APP_WIDTH-width)/2.0f;
        CGFloat originY = APP_HEIGHT - (324.0f+62.0f+44.0f)/2.0f;
        _whiteBalanceView = [[UIView alloc] initWithFrame:CGRectMake(originX, originY, width, height)];
        _whiteBalanceView.hidden = YES;
        _whiteBalanceView.backgroundColor = RGB(0x000000);
        _whiteBalanceView.alpha = 0.8f;
        _whiteBalanceView.layer.cornerRadius = 5.0f;
        _whiteBalanceView.layer.masksToBounds = YES;
    }
    return _whiteBalanceView;
}

- (UISlider *)wbSlider{
    if (!_wbSlider) {
        UIImage *leftImg = [UIImage imageNamed:@"whiteBalanceLefticon"];
        UIImage *rightImg = [UIImage imageNamed:@"whiteBalanceRighticon"];
        
        CGFloat sliderWidth = CGRectGetWidth(_whiteBalanceView.bounds) - (22.0f+22.0f)/2.0f;
        CGFloat sliderHeight = 31.0f;
        CGFloat sliderOriginX = CGRectGetMinX(_whiteBalanceView.frame) + 22.0f/2.0f;
        CGFloat sliderOriginY = CGRectGetMinY(_whiteBalanceView.frame) +((CGRectGetHeight(_whiteBalanceView.bounds)-sliderHeight)/2.0f);
        _wbSlider = [[UISlider alloc] initWithFrame:CGRectMake(sliderOriginX, sliderOriginY, sliderWidth, sliderHeight)];
        _wbSlider.hidden = YES;
        _wbSlider.minimumValue = 3000.0f;
        _wbSlider.maximumValue = 12000.0f;
        _wbSlider.value = 6000.0f;
        _wbSlider.minimumValueImage = leftImg;
        _wbSlider.maximumValueImage = rightImg;
        [_wbSlider addTarget:self action:@selector(wbSliderMethod:) forControlEvents:UIControlEventValueChanged];
    }
    return _wbSlider;
}

#pragma mark - ButtonClick
- (void)pushToPictureScan:(BOOL)animated{
    PictureScanViewController *scanVc = [[PictureScanViewController alloc] init];
    [self.navigationController pushViewController:scanVc animated:animated];
}
- (void)wbSliderMethod:(id)sender{
    UISlider *slider = (UISlider *)sender;
    AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTint = {
        .temperature = slider.value,
        .tint = 0,
    };
    AVCaptureWhiteBalanceGains wbGains = [_captureDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTint];
    [_captureDevice lockForConfiguration:nil];
    [_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:wbGains completionHandler:nil];
    [_captureDevice unlockForConfiguration];
}

- (void)ISOBtnClick:(id)sender{
    UIButton *btn = (UIButton *)sender;
    btn.selected = !btn.selected;
    
    UIImage *ISOImg = [UIImage imageNamed:@"ISOicon"];
    UIImage *ISOClickImg = [UIImage imageNamed:@"ISOclickicon"];
    
    [_captureDevice lockForConfiguration:nil];
    if (btn.isSelected) {
        [_ISOBtn setBackgroundImage:ISOClickImg forState:UIControlStateNormal];
        [_captureDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds(0.05, 1000) ISO:40.0 completionHandler:nil];
    }else{
        [_ISOBtn setBackgroundImage:ISOImg forState:UIControlStateNormal];
        [_captureDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds(0.05, 1000) ISO:80.0 completionHandler:nil];
    }
    [_captureDevice unlockForConfiguration];
}

- (void)whiteBalanceBtnClick:(id)sender{
    UIButton *btn = (UIButton *)sender;
    btn.selected = !btn.isSelected;
    _whiteBalanceView.hidden = !_whiteBalanceView.hidden;
    _wbSlider.hidden = !_wbSlider.hidden;
    UIImage *whiteBalanceImg = [UIImage imageNamed:@"white-balance-icon"];
    UIImage *whiteBalanceSelectedImg = [UIImage imageNamed:@"white-balance-click-icon"];
    if (btn.isSelected) {
        [_whiteBalanceBtn setBackgroundImage:whiteBalanceSelectedImg
                                    forState:UIControlStateNormal];
    }else{
        [_whiteBalanceBtn setBackgroundImage:whiteBalanceImg
                                    forState:UIControlStateNormal];
    }
}

- (void)handleSwipes:(UISwipeGestureRecognizer *)sender{
    if (sender.direction == UISwipeGestureRecognizerDirectionLeft){
        if (_isLeftEye) {
            [self rightBtnClick:nil];
        }
    }else if(sender.direction == UISwipeGestureRecognizerDirectionRight){
        if (!_isLeftEye) {
            [self leftBtnClick:nil];
        }
    }
}

- (void)leftBtnClick:(UIButton *)btn {
    [UIView animateWithDuration:kAnimationDuration animations:^{
        _leftBtn.frame = _centerBtnFrame;
        _centerBtn.frame = _rightBtnFrame;
    } completion:^(BOOL finished) {
        [self ChangeToLeft:YES];
    }];
}
- (void)rightBtnClick:(UIButton *)btn {
    [UIView animateWithDuration:kAnimationDuration animations:^{
        _rightBtn.frame = _centerBtnFrame;
        _centerBtn.frame = _leftBtnFrame;
    } completion:^(BOOL finished) {
        [self ChangeToLeft:NO];
    }];
}
- (void)cameraBtnTouchUpInside:(UIButton *)btn {
    if (_isLeftEye) {
        if (_isLeftTouchDown) {
            _isLeftTouchDown = NO;
        }else{
            if (_leftTakenPictureCount == 6) {
                [self showBeyondLimitTakenCount];
            }else{
                _isLeftTouchUpInside = YES;
                [self takePictureMethod];
            }
        }
    }else{
        if (_isRightTouchDown) {
            _isRightTouchDown = NO;
        }else{
            if (_rightTakenPictureCount == 6) {
                [self showBeyondLimitTakenCount];
            }else{
                _isRightToucUpInside = YES;
                [self takePictureMethod];
            }
        }
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(cameraBtnTouchDownMethod)
                                               object:nil];
}

- (void)cameraBtnTouchDown:(UIButton *)btn{
    [self performSelector:@selector(cameraBtnTouchDownMethod) withObject:nil afterDelay:0.5f];
}

- (void)cameraBtnTouchDownMethod{
    if (_isLeftEye) {
        if (_leftTakenPictureCount == 6) {
            [self showBeyondLimitTakenCount];
        }else{
            _isLeftTouchDown = YES;
            [self takePictureMethod];
        }
    }else{
        if (_rightTakenPictureCount == 6) {
            [self showBeyondLimitTakenCount];
        }else{
            _isRightTouchDown = YES;
            [self takePictureMethod];
        }
    }
}

- (void)takePictureMethod{
    if([_captureDevice isAdjustingFocus]){
        [_captureDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
    }else{
        [self takePictureMethodCore];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"adjustingFocus"]){
        BOOL adjustingFocus = [ [change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        if(!adjustingFocus){
            [_captureDevice removeObserver:self forKeyPath:@"adjustingFocus"];
            [self takePictureMethodCore];
        }
    }
}

- (void)takePictureMethodCore{
    if (_isLeftEye) {
        _leftTakenPictureCount++;
    }else{
        _rightTakenPictureCount++;
    }
    
    __weak WYVideoCaptureController *wself = self;
    // 1.根据设备输出获得链接
    AVCaptureConnection *captureConnection = [_captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    // 2.根据链接取得设备输出的数据
    [_captureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        [wself saveTakenPictureData:imageData];
    }];
}

- (void)showBeyondLimitTakenCount{
    __weak WYVideoCaptureController *wself = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"单侧眼睛最多拍摄六张图片,是否重拍?" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"重拍" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (_isLeftEye) {
            _leftTakenPictureCount=0;
        }else{
            _rightTakenPictureCount=0;
        }
        self.title = @"0/6";
        [[JRMediaFileManage shareInstance] deleteFileWithEyeType:_isLeftEye];
        //[wself takePictureMethod];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 更新界面
            [wself pushToPictureScan:YES];
        });
    }];
    // Add the actions.
    [alertController addAction:cancelAction];
    [alertController addAction:sureAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)saveTakenPictureData:(NSData *)imgData{
    if (_isLeftEye) {
        self.title = [NSString stringWithFormat:@"%d/6",_leftTakenPictureCount];
    }else{
        self.title = [NSString stringWithFormat:@"%d/6",_rightTakenPictureCount];
    }
    
    UIImage *image = [UIImage imageWithData:imgData];
    UIImage *saveImg = [self cropImage:image withCropSize:self.viewContainer.size];
    NSData *saveImgData = UIImageJPEGRepresentation(saveImg, 1.0f);
    
    JRMediaFileManage *fileManage = [JRMediaFileManage shareInstance];
    NSString *filePath = [fileManage getJRMediaPathWithType:_isLeftEye];
    NSString *imageName;
    if (_isLeftEye) {
        imageName = [NSString stringWithFormat:@"%02d.jpg",_leftTakenPictureCount];
    }else{
        imageName = [NSString stringWithFormat:@"%02d.jpg",_rightTakenPictureCount];
    }
    NSString *imgPath = [NSString stringWithFormat:@"%@/%@",filePath,imageName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager createFileAtPath:imgPath
                                       contents:saveImgData
                                     attributes:nil];
    NSLog(@"result:%d",result);
    if (_isLeftEye) {
        if (_isLeftTouchDown) {
            if (_leftTakenPictureCount==6) {
                _isLeftTouchDown = NO;
                [self pushToPictureScan:YES];
            }else{
                [self performSelector:@selector(takePictureMethod) withObject:nil afterDelay:0.2f];
            }
        }else{
            [self pushToPictureScan:YES];
        }
    }else{
        if (_isRightTouchDown) {
            if (_rightTakenPictureCount==6) {
                _isRightTouchDown = NO;
                [self pushToPictureScan:YES];
            }else{
                [self performSelector:@selector(takePictureMethod) withObject:nil afterDelay:0.2f];
            }
        }else{
            [self pushToPictureScan:YES];
        }
    }
}

#pragma mark - private
- (void)restoreBtn {
    _leftBtn.frame = _leftBtnFrame;
    _centerBtn.frame = _centerBtnFrame;
    _rightBtn.frame = _rightBtnFrame;
    [_centerBtn setTitleColor:RGB(0x76c000) forState:UIControlStateNormal];
}

- (void)initTakenParameters{
    _isLeftTouchDown = NO;
    _isRightTouchDown = NO;
    _isLeftTouchUpInside = NO;
    _isRightToucUpInside = NO;
    _leftTakenPictureCount = 0;
    _rightTakenPictureCount = 0;
}
/// 切换拍照和视频录制
///
/// @param isPhoto YES->拍照  NO->视频录制
- (void)ChangeToLeft:(BOOL)isLeft{
    [self restoreBtn];
    _isLeftEye = isLeft;
    self.title = [NSString stringWithFormat:@"%d/6",isLeft?_leftTakenPictureCount:_rightTakenPictureCount];
    NSString *centerTitle = isLeft ? @"左眼" : @"右眼";
    [_centerBtn setTitle:centerTitle forState:UIControlStateNormal];
    _leftBtn.hidden = isLeft;
    _rightBtn.hidden = !isLeft;
}

#pragma mark 裁剪照片尺寸
- (UIImage *)cropImage:(UIImage *)image withCropSize:(CGSize)cropSize{
    UIImage *newImage = nil;
    
    CGSize imageSize = image.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    
    CGFloat targetWidth = cropSize.width;
    CGFloat targetHeight = cropSize.height;
    
    CGFloat scaleFactor = 0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    
    CGPoint thumbnailPoint = CGPointMake(0, 0);
    
    if (CGSizeEqualToSize(imageSize, cropSize) == NO) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor > heightFactor) {
            scaleFactor = widthFactor;
        } else {
            scaleFactor = heightFactor;
        }
        
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        
        if (widthFactor > heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * .5f;
        } else {
            if (widthFactor < heightFactor) {
                thumbnailPoint.x = (targetWidth - scaledWidth) * .5f;
            }
        }
    }
    
    UIGraphicsBeginImageContextWithOptions(cropSize, YES, 0);
    
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [image drawInRect:thumbnailRect];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
