//
//  IAMenuController.m
//  IAMenuController
//
//  Created by Mark Adams on 12/16/11.
//  MIT License
//

#import "IAMenuController.h"
#import <QuartzCore/QuartzCore.h>

@interface IAMenuController ()

@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, assign) BOOL panningEnabled;

@end

#pragma mark -

@implementation IAMenuController

#pragma mark - Initialization

- (id)initWithMenuViewController:(UIViewController *)menu contentViewController:(UIViewController *)content;
{
    NSParameterAssert(menu && content);
    
    self = [super init];
    
    if (!self)
        return nil;
    
    _menuViewController = menu;
    _contentViewController = content;

    return self;
}

#pragma mark - Setters

- (void)setContentViewController:(UIViewController *)controller
{
    if (controller == _contentViewController)
        return;
    
    UIViewController *oldContent = _contentViewController;
    _contentViewController = controller;
    
    [self removeTapToDismissGestureRecognizer];
    [oldContent willMoveToParentViewController:nil];
    [oldContent viewWillDisappear:YES];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:0 animations:^{
        self.contentView.frame = [self contentViewFrameForStaging];
    } completion:^(BOOL finished) {
        [oldContent.view removeFromSuperview];
        [oldContent viewDidDisappear:YES];
        [oldContent removeFromParentViewController];
        
        [self addChildViewController:_contentViewController];
        [_contentViewController viewWillAppear:YES];
        [self.contentView addSubview:_contentViewController.view];
        [self resizeViewForContentView:_contentViewController.view];
        [_contentViewController didMoveToParentViewController:self];
        
        [UIView animateWithDuration:0.22 delay:0.1 options:0 animations:^{
            self.contentView.frame = [self contentViewFrameForClosedMenu];
        } completion:^(BOOL finished) {
            [_contentViewController viewDidAppear:YES];
            self.menuIsVisible = NO;
        }];
    }];
}

#pragma mark - UIViewController

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupViewControllers];
}

#pragma mark - Child Controller Setup
- (void)setupViewControllers
{
    [self setupContentViewController];
    [self setupMenuViewController];
}

- (void)setupContentViewController
{
    [self addChildViewController:self.contentViewController];
    [self.contentViewController viewWillAppear:NO];
    [self setupContentView];
    [self.contentViewController viewDidAppear:NO];
    [self.contentViewController didMoveToParentViewController:self];
}

- (void)setupContentView
{
    self.contentView = [[UIView alloc] initWithFrame:self.view.bounds];
    
    [self addPanGestureRecognizer];
    [self.contentView addSubview:self.contentViewController.view];
    [self resizeViewForContentView:self.contentViewController.view];
    [self.view addSubview:self.contentView];
    
    self.contentView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.contentView.layer.shadowOffset = CGSizeMake(-2.0f, 0.0f);
    self.contentView.layer.shadowOpacity = 0.75f;
    self.contentView.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.contentView.frame].CGPath;
    self.contentView.layer.shadowRadius = 3.0f;
}

- (void)setupMenuViewController
{
    [self addChildViewController:self.menuViewController];
    self.menuViewController.view.frame = self.view.bounds;
    [self.view insertSubview:self.menuViewController.view belowSubview:self.contentView];
    [self.menuViewController didMoveToParentViewController:self];
}

#pragma mark - Gesture Management
- (void)addPanGestureRecognizer
{
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    pan.cancelsTouchesInView = YES;
    [self.contentView addGestureRecognizer:pan];
}

- (void)addTapToDismissGestureRecognizer
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideMenu)];
    [self.contentView addGestureRecognizer:tap];
}

- (void)removeTapToDismissGestureRecognizer
{
    for (UIGestureRecognizer *recognizer in self.contentView.gestureRecognizers)
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]])
            [self.contentView removeGestureRecognizer:recognizer];
}

#pragma mark - Menu Presentation

- (void)toggleMenu
{
    (self.menuIsVisible)? [self hideMenu] : [self showMenu];
}

- (void)showMenu
{
    self.menuIsVisible = YES;
    [self.menuViewController viewWillAppear:YES];

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    [UIView animateWithDuration:0.225 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.contentView.frame = [self contentViewFrameForOpenMenu];
    } completion:^(BOOL finished) {
        [self.menuViewController viewDidAppear:YES];
        [self addTapToDismissGestureRecognizer];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    }];
}

- (void)hideMenu
{
    [self.menuViewController viewWillDisappear:YES];

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    [UIView animateWithDuration:0.225 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.contentView.frame = [self contentViewFrameForClosedMenu];
    } completion:^(BOOL finished) {
        [self.menuViewController viewDidDisappear:YES];
        [self removeTapToDismissGestureRecognizer];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    }];

    self.menuIsVisible = NO;
}

#pragma mark - Pan Gesture Support
- (void)pan:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self.contentView];
    CGPoint velocity = [pan velocityInView:self.contentView];
    
    CGFloat minimumX = 0.0f;
    CGFloat maximumX = 276.0f;
    
    if (pan.state == UIGestureRecognizerStateBegan)
    {
        if (translation.x < minimumX)
            return;
        
        self.panningEnabled = ([pan locationInView:self.contentView].y < 44);
        
        [self.menuViewController viewWillAppear:YES];
    }
    else if (pan.state == UIGestureRecognizerStateChanged)
    {
        if (!self.panningEnabled) {
            return;
        }
        
        CGRect currentFrame = self.contentView.frame;
        CGFloat newX = currentFrame.origin.x + translation.x;
        
        if (newX < minimumX || newX > maximumX)
            return;
        
        currentFrame.origin.x = currentFrame.origin.x + translation.x;
        self.contentView.frame = currentFrame;
    }
    else if (pan.state == UIGestureRecognizerStateEnded)
    {
        self.panningEnabled = NO;
        
        if (CGRectGetMinX(self.contentView.frame) == 0.0f)
            return;
        
        CGFloat finalX = self.contentView.frame.origin.x + (0.55 * velocity.x);
        CGFloat travelDistance;

        if (finalX >= CGRectGetMidX(self.view.frame))
        {
            finalX = maximumX;
            travelDistance = maximumX - CGRectGetMinX(self.contentView.frame);
        }
        else
        {
            finalX = minimumX;
            travelDistance = minimumX + CGRectGetMinX(self.contentView.frame);
            [self.menuViewController viewWillDisappear:YES];
        }

        NSTimeInterval duration = (travelDistance / ABS(velocity.x));

        if (duration < 0.1) {
            duration = 0.1;
        } else if (duration > 0.25) {
            duration = 0.25;
        }
        
        [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGRect frame = self.contentView.frame;
            frame.origin.x = finalX;
            self.contentView.frame = frame;
        } completion:^(BOOL finished) {
            if (finalX == maximumX)
            {
                self.menuIsVisible = YES;
                [self.menuViewController viewDidAppear:YES];
                [self addTapToDismissGestureRecognizer];
            }
            else if (finalX == 0.0f)
            {
                self.menuIsVisible = NO;
                [self.menuViewController viewDidDisappear:YES];
                [self removeTapToDismissGestureRecognizer];
            }
        }];
    }
    
    [pan setTranslation:CGPointZero inView:self.contentView];
}

#pragma mark - Frame Calculation
- (CGRect)contentViewFrameForOpenMenu
{
    CGRect frame = self.contentView.frame;
    frame.origin.x = 276.0f;
    
    return frame;
}
     
- (CGRect)contentViewFrameForClosedMenu
{
    CGRect frame = self.contentView.frame;
    frame.origin.x = 0.0f;
    
    return frame;
}

- (CGRect)contentViewFrameForStaging
{
    CGRect frame = self.contentView.frame;
    frame.origin.x = CGRectGetMaxX(self.view.frame) + 44.0f;
    
    return frame;
}

- (void)resizeViewForContentView:(UIView *)view
{
    view.frame = self.view.bounds;
}

@end

@implementation UIViewController (IAMenuController)

- (IAMenuController *)menuController
{
    if ([self.parentViewController isKindOfClass:[IAMenuController class]])
        return (IAMenuController *)self.parentViewController;

    if ([self.parentViewController isKindOfClass:[UINavigationController class]] && [self.parentViewController.parentViewController isKindOfClass:[IAMenuController class]])
        return (IAMenuController *)self.parentViewController.parentViewController;

    return nil;
}

@end
