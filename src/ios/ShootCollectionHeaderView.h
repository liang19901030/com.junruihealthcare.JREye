//
//  ShootCollectionHeaderView.h
//  JRHealthcare
//
//  Created by 路亮 on 15/10/26.
//  Copyright (c) 2015年 路亮. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TDHeader.h"
#import "ShootCollectionButton.h"

@interface ShootCollectionHeaderView : UIView

@property (nonatomic, strong) UIImageView *iconImgView;
@property (nonatomic, strong) UILabel *typeNameLabel;
@property (nonatomic, strong) UILabel *selectedLabel;
@property (nonatomic, strong) UIView *headerLineView;
@property (nonatomic, strong) ShootCollectionButton *chooseBtn;

@end
