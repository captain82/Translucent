import UIKit
import DeviceKit

public class Wallpaper: NSObject {
    
    private let wallpaperImage: UIImage
    
    private var phoneMappings: [String: Any]

    private var isIOS18OrHigher: Bool

    
    public init(_ img: UIImage) {
        self.wallpaperImage = img
        do{

            let currentVersion = UIDevice.current.systemVersion
            let majorVersion = Int(currentVersion.split(separator: ".").first!) ?? 0
             self.isIOS18OrHigher = majorVersion >= 18
            
            let fileName: String
            if majorVersion >= 18 {
                fileName = "mappings"
                print("Loading mappings-ios-18.json")
            } else {
                fileName = "mappings"
                print("Loading mappings.json")
            }

            //  load mappings into code. mapping file is based on https://gist.github.com/CyberBatMan2077/8ac39f169066a4a20320ee4572e1eafa
            guard let mappings = Bundle.module.url(forResource: fileName, withExtension: "json") else {
                fatalError("Mapping file not found.")
            }
            
            
            let jsonData = try Data(contentsOf: mappings)
            let jsonDictionary = try JSONDecoder().decode([String: PhoneModel].self, from: jsonData)
            phoneMappings = jsonDictionary

        } catch {
            fatalError("unexpected resource..")
        }
    }

    public func isIphoneScreenshot() -> Bool {
        let height = Int(wallpaperImage.size.height)
        
        guard let _ = phoneMappings["\(height)"] as? PhoneModel else {
            print("It looks like you selected an image that isn't an iPhone screenshot, or your iPhone is not supported. Try again with a different image.")
            return false
        }
        
        return true
    }
    
    required override init() {
        fatalError()
    }
    
    public func widgetBackground(for position: WidgetCropPosition, widgetType: Int = 1) -> UIImage? {
        let height = Int(wallpaperImage.size.height)
        
        var heightKey = String(height)
        //  Extra setup needed for 2436-sized phones, i.e. for 13 mini, 12 mini / 11 Pro, XS, X
        if Device.current == .iPhone13Mini || Device.current == .iPhone12Mini{
            heightKey += "mini"
        } else if Device.current == .iPhoneX || Device.current == .iPhoneXS || Device.current == .iPhone11Pro{
            heightKey += "x"
        }
        
        // Debug info to help diagnose iPhone 15 cropping issues
        print("Device: \(Device.current)")
        print("Screen height: \(height)")
        print("HeightKey: \(heightKey)")
        print("iOS Version: \(UIDevice.current.systemVersion)")
        print("iOS 18 or higher: \(isIOS18OrHigher)")
        
        guard let phone = phoneMappings["\(heightKey)"] as? PhoneModel else {
            print("It looks like you selected an image that isn't an iPhone screenshot, or your iPhone is not supported. Try again with a different image.")
            return nil
        }
        
        // Select the appropriate phone properties based on the widgetType
        let selectedPhone: Phone
        
        if isIOS18OrHigher {
            // For iOS 18 or higher, use the text or notext properties
            selectedPhone = widgetType == 1 ? phone.text : (phone.notext ?? phone.text)
            print("iOS 18 or higher - Using \(widgetType == 1 ? "text" : "notext") mappings")
            print("Selected phone coordinates - small: \(selectedPhone.small), left: \(selectedPhone.left), right: \(selectedPhone.right), top: \(selectedPhone.top), middle: \(selectedPhone.middle), bottom: \(selectedPhone.bottom)")
        } else {
            selectedPhone = phone.text
            print("Lower than iOS 18 - Using text mappings")
            print("Selected phone coordinates - small: \(selectedPhone.small), left: \(selectedPhone.left), right: \(selectedPhone.right), top: \(selectedPhone.top), middle: \(selectedPhone.middle), bottom: \(selectedPhone.bottom)")
        }
        
        // Improved cropping logic based on reference implementation
        let crop = calculateCropDimensions(for: position, using: selectedPhone)
        
        print("Final crop coordinates - x: \(crop.x), y: \(crop.y), width: \(crop.w), height: \(crop.h)")
        print("Widget position: \(position)")
        
        let croppedCGImage = wallpaperImage.cgImage?.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.w, height: crop.h))
        let croppedImage = UIImage(cgImage: croppedCGImage!)
        
        return croppedImage
            
    }
    
    // Helper function to calculate crop dimensions using improved logic from reference implementation
    private func calculateCropDimensions(for position: WidgetCropPosition, using phone: Phone) -> CropDimensions {
        // Determine widget size category
        let widgetSize: WidgetSize
        let verticalPosition: VerticalPosition
        let horizontalPosition: HorizontalPosition?
        
        switch position {
        case .smallTopLeft, .smallTopRight, .smallCenterLeft, .smallCenterRight, .smallBottomLeft, .smallBottomRight:
            widgetSize = .small
        case .mediumTop, .mediumCenter, .mediumBottom:
            widgetSize = .medium
        case .largeTop, .largeBottom:
            widgetSize = .large
        }
        
        // Extract position components
        switch position {
        case .smallTopLeft, .mediumTop, .largeTop:
            verticalPosition = .top
            horizontalPosition = .left
        case .smallTopRight:
            verticalPosition = .top
            horizontalPosition = .right
        case .smallCenterLeft, .mediumCenter:
            verticalPosition = .middle
            horizontalPosition = .left
        case .smallCenterRight:
            verticalPosition = .middle
            horizontalPosition = .right
        case .smallBottomLeft, .mediumBottom:
            verticalPosition = .bottom
            horizontalPosition = .left
        case .smallBottomRight:
            verticalPosition = .bottom
            horizontalPosition = .right
        case .largeBottom:
            verticalPosition = .middle
            horizontalPosition = .left
        }
        
        // Calculate dimensions using the reference logic
        let w: CGFloat = (widgetSize == .small) ? phone.small : phone.medium
        let h: CGFloat = (widgetSize == .large) ? phone.large : phone.small
        
        let x: CGFloat
        if widgetSize == .small {
            x = (horizontalPosition == .left) ? phone.left : phone.right
        } else {
            x = phone.left  // Medium and large widgets always use left position
        }
        
        let y: CGFloat
        switch verticalPosition {
        case .top:
            y = phone.top
        case .middle:
            y = phone.middle
        case .bottom:
            y = phone.bottom
        }
        
        return CropDimensions(x: x, y: y, w: w, h: h)
    }
}

// Helper structs for improved crop logic
struct CropDimensions {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
}

enum WidgetSize {
    case small, medium, large
}

enum VerticalPosition {
    case top, middle, bottom
}

enum HorizontalPosition {
    case left, right
}

struct Phone: Codable {
    var small:  CGFloat
    var medium: CGFloat
    var large:  CGFloat
    var left:   CGFloat
    var right:  CGFloat
    var top:    CGFloat
    var middle: CGFloat
    var bottom: CGFloat
}

struct PhoneModel: Codable {
    var text: Phone
    var notext: Phone?
}

