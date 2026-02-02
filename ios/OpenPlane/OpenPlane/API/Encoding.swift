import Foundation

extension JSONEncoder {
  static var plane: JSONEncoder {
    let e = JSONEncoder()
    e.keyEncodingStrategy = .convertToSnakeCase
    return e
  }
}

