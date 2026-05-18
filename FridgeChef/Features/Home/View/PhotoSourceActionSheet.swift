import UIKit
import PhotosUI

enum PhotoSource {
    case camera
    case library
}

enum PhotoSourceActionSheet {
    static func present(on vc: UIViewController, completion: @escaping (PhotoSource) -> Void) {
        let sheet = UIAlertController(title: "Photo of ingredients", message: nil,
                                      preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take photo", style: .default) { _ in
                completion(.camera)
            })
        }
        sheet.addAction(UIAlertAction(title: "Choose from library", style: .default) { _ in
            completion(.library)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        vc.present(sheet, animated: true)
    }
}
