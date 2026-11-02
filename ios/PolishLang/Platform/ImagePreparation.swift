import UIKit

/// Turns a photo into a JPEG for the model: at most 2048 px on the long side, orientation applied.
enum ImagePreparation {
    static let maxDimension: CGFloat = 2048
    static let maxInputBytes = 40 * 1024 * 1024

    enum Failure: Error {
        case tooLarge
        case unreadable

        /// TZ 1, section 7: a clear message about the allowed types and size.
        var message: String {
            switch self {
            case .tooLarge: return "Фото слишком большое: можно до 40 МБ. Подходят JPEG, PNG и HEIC."
            case .unreadable: return "Не получилось открыть изображение. Подходят фото в форматах JPEG, PNG и HEIC до 40 МБ."
            }
        }
    }

    static func jpeg(fromData data: Data) throws -> Data {
        guard data.count <= maxInputBytes else { throw Failure.tooLarge }
        guard let image = UIImage(data: data) else { throw Failure.unreadable }
        return try jpeg(from: image)
    }

    static func jpeg(from image: UIImage) throws -> Data {
        let size = image.size
        guard size.width > 0, size.height > 0 else { throw Failure.unreadable }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { throw Failure.unreadable }
        return data
    }
}
