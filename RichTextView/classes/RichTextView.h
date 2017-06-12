//
//  RichTextView.h
//  RichTextView
//
//  Created by jv on 2017/6/5.
//  Copyright © 2017年 jv. All rights reserved.
//

#import <UIKit/UIKit.h>


#pragma mark - define

typedef NS_ENUM(NSUInteger,RichTextEmojiType) {
    
    RichTextEmojiNormal,//emoji normal type
    
};


#pragma mark - protocal

@class RichTextView,RichTextConfig;

@protocol RichTextViewDelegate <NSObject>

@optional
- (void)richtextView:(RichTextView *)richtextView didUrlClicked:(NSString *)url;//click A link
- (void)richtextView:(RichTextView *)richtextView didImageClicked:(NSString *)url image:(UIImage *)image;//click image
- (void)richtextView:(RichTextView *)richtextView didTopicClicked:(NSString *)topic;//click topic
- (void)richtextViewDidTapped:(RichTextView *)richtextView;//tap rich text view

@end


#pragma mark - function

extern NSMutableAttributedString* RichTextParseEmoji(NSMutableAttributedString *contentAttributedString);
extern NSMutableAttributedString* RichTextParseLink(NSMutableAttributedString* string,NSDictionary *attibutes);
extern NSMutableAttributedString* RichTextParseHttp(NSMutableAttributedString* string,NSDictionary *attibutes);
CGSize RichTextHeight(NSAttributedString *string ,int maxWidth, NSUInteger maxRow, BOOL isSingleRowFitWidth);
CGFloat RichTextGetHeight(NSString *text, int maxWidth, NSUInteger maxRow, RichTextConfig *config, NSArray *imageConfig);

#pragma mark - class
@class RichTextConfig;


@interface RichTextView : UIView

@property (readonly, nonatomic) CGSize size;//current UIView size based on content
@property (copy, nonatomic) NSString *text;//content
@property (assign, nonatomic) NSUInteger maxRow;//max row , show '[more]' if more than MAX

@property (assign, nonatomic) CGFloat maxWidth;//max width
@property (nonatomic, strong) RichTextConfig *richTextConfig;//some config
@property (strong, nonatomic) NSArray *localImageConfigs;//local image config sets, to local image
@property (weak, nonatomic) id<RichTextViewDelegate> delegate;

- (void)reload;//update ui

@end

//text config
@interface RichTextConfig : NSObject{
    NSDictionary *_textAttributes;
    NSDictionary *_linkedTextAttributes;
}

+ (instancetype)defaultConfig;

@property (nonatomic,readonly) NSDictionary* textAttributes;
@property (nonatomic,readonly) NSDictionary* linkedTextAttributes;
@property (assign, nonatomic) RichTextEmojiType emojiType;

- (void) defaultAttributes;

@end

//image config
@interface RichTextImageConfig : NSObject

@property (assign, nonatomic) NSUInteger index;
@property (copy, nonatomic) NSString *imageName;

@end

//hash
@interface NSString (Hash)

@property (nonatomic, readonly) NSString* MD5;
@property (nonatomic, readonly) NSString* trim;


@end


