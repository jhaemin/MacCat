import AppKit

struct CatPalette {
    let fur: NSColor
    let patch: NSColor
    let light: NSColor
    let ink: NSColor
    let accent: NSColor
    let backdrop: NSColor
}

enum CatDesign: Int, CaseIterable, Identifiable {
    case cheese, milk, tuxedo, calico, siamese, cloud, cocoa, peach
    var id: Int { rawValue }
    var assetName: String {
        ["cheese", "milk", "tuxedo", "calico", "siamese", "cloud", "cocoa", "peach"][rawValue]
    }

    var name: String {
        ["치즈", "우유", "오레오", "모모", "라떼", "구름", "코코", "복숭아"][rawValue]
    }
    var subtitle: String {
        ["햇살을 닮은 치즈냥", "말랑한 우유 한 방울", "작은 턱시도 신사", "알록달록 행운의 삼색이",
         "커피 향 나는 샴냥", "느긋한 회색 솜뭉치", "달콤한 초콜릿 친구", "발그레한 꿈꾸는 고양이"][rawValue]
    }
    var palette: CatPalette {
        let colors: [String]
        switch self {
        case .cheese: colors = ["EDB56C", "D58C45", "FFF3D9", "604735", "8B9F82", "F5EBDD"]
        case .milk: colors = ["FFF9ED", "E9D9C5", "FFFFFF", "716256", "B99BC7", "EFE9F3"]
        case .tuxedo: colors = ["454952", "32363F", "FFF7E8", "30343D", "D69B91", "E9ECEC"]
        case .calico: colors = ["FFF4E1", "D89C61", "FFFFFF", "655348", "89A59A", "F2EADB"]
        case .siamese: colors = ["E9D6BA", "887366", "FAEDDA", "594A43", "98AFC0", "EAECEF"]
        case .cloud: colors = ["B4BBC4", "8C96A4", "EDF0EF", "505B69", "E1BC6D", "E7EDF0"]
        case .cocoa: colors = ["A07F70", "7D5C50", "EFDDCB", "503D37", "B6BE99", "EDE6DF"]
        case .peach: colors = ["F1C6BE", "DBA29A", "FFF0E5", "875F5E", "A5B6A0", "F5E8E6"]
        }
        return CatPalette(fur: .hex(colors[0]), patch: .hex(colors[1]), light: .hex(colors[2]),
                          ink: .hex(colors[3]), accent: .hex(colors[4]), backdrop: .hex(colors[5]))
    }
}

extension NSColor {
    static func hex(_ value: String) -> NSColor {
        let n = UInt32(value, radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((n >> 16) & 255) / 255,
                       green: CGFloat((n >> 8) & 255) / 255,
                       blue: CGFloat(n & 255) / 255, alpha: 1)
    }
}

enum CatSize: Int, CaseIterable {
    case small, medium, large
    var title: String { ["작게", "보통", "크게"][rawValue] }
    var size: CGSize {
        let width: CGFloat = [140, 190, 250][rawValue]
        return CGSize(width: width, height: width * 200 / 240)
    }
}

enum RoamingArea: Int, CaseIterable {
    case everywhere, bottom
    var title: String { self == .everywhere ? "화면 곳곳" : "화면 아래쪽" }
}
