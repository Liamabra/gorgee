/// Code à quatre lettres, tel qu'AVFoundation l'expose (`transportType`, par exemple `'bltn'`).
public func fourCharCode(_ code: String) -> Int32 {
    var value: UInt32 = 0
    for byte in code.utf8.prefix(4) {
        value = value << 8 | UInt32(byte)
    }
    return Int32(bitPattern: value)
}

/// Seules les caméras physiques prouvent une gorgée : une caméra virtuelle (OBS…) pourrait rejouer une vidéo.
///
/// Liste d'autorisation plutôt que d'exclusion : un transport inconnu est refusé.
public enum CameraPolicy {
    static let allowedTransports: Set<Int32> = [fourCharCode("bltn"), fourCharCode("usb ")]

    public static func isAllowed(transportType: Int32, isContinuityCamera: Bool) -> Bool {
        isContinuityCamera || allowedTransports.contains(transportType)
    }
}
