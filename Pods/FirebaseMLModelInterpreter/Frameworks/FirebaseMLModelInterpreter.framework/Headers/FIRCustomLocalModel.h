#import <Foundation/Foundation.h>


#import <FirebaseMLCommon/FirebaseMLCommon.h>


NS_ASSUME_NONNULL_BEGIN

/** A custom model stored locally on the device. */
NS_SWIFT_NAME(CustomLocalModel)
@interface FIRCustomLocalModel : FIRLocalModel

/**
 * Creates a new instance with the given model file path.
 *
 * @param modelPath An absolute path to the TensorFlow Lite model file stored locally on the device.
 * @return A new `CustomLocalModel` instance.
 */
- (instancetype)initWithModelPath:(NSString *)modelPath NS_DESIGNATED_INITIALIZER;

/** Unavailable. */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
