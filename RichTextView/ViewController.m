//
//  ViewController.m
//  RichTextView
//
//  Created by jv on 2017/6/5.
//  Copyright © 2017年 jv. All rights reserved.
//

#import "ViewController.h"
#import "RichTextView.h"

@interface ViewController ()<UITextViewDelegate,RichTextViewDelegate>

@property (strong, nonatomic) RichTextView *richTextView;

@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    _richTextView = [[RichTextView alloc] initWithFrame:(CGRect){0,0,self.view.frame.size.width,100}];
    _richTextView.delegate = self;
    _richTextView.backgroundColor = [UIColor greenColor];
    _richTextView.maxRow = 7;
    [self.view addSubview:_richTextView];
    
}

#pragma mark - rich text view delegate

- (void)richtextView:(RichTextView *)richtextView didUrlClicked:(NSString *)url {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"link selected"
                                                    message:url
                                                   delegate:nil
                                          cancelButtonTitle:@"ok"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)richtextView:(RichTextView *)richtextView didImageClicked:(NSString *)url image:(UIImage *)image {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"image selected"
                                                    message:@"image selected"
                                                   delegate:nil
                                          cancelButtonTitle:@"ok"
                                          otherButtonTitles:nil];
    [alert show];
}


- (void)richtextView:(RichTextView *)richtextView didTopicClicked:(NSString *)topic {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"topic selected"
                                                    message:topic
                                                   delegate:nil
                                          cancelButtonTitle:@"ok"
                                          otherButtonTitles:nil];
    [alert show];

}


- (void)richtextViewDidTapped:(RichTextView *)richtextView {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"tapped"
                                                    message:@"rich text tapped"
                                                   delegate:nil
                                          cancelButtonTitle:@"ok"
                                          otherButtonTitles:nil];
    [alert show];
    
}




#pragma mark - text view delegate

- (void)textViewDidChange:(UITextView *)textView {

    _richTextView.text = textView.text;
    CGRect frame = _richTextView.frame;
    frame.size.height = _richTextView.size.height;
    _richTextView.frame = frame;
    
}

#pragma mark - action

- (IBAction)insertLocalImage:(id)sender {
    
    NSRange range = _textView.selectedRange;
    
    NSUInteger index = range.location;
    
    RichTextImageConfig *imageConfig = [RichTextImageConfig new];
    imageConfig.index = index;
    imageConfig.imageName = @"image";
    _richTextView.localImageConfigs = @[imageConfig];
    [_richTextView reload];
    
}


@end
