import CryptoKit
import Foundation

// Verify the archive against the public key actually embedded in the app.
let args = CommandLine.arguments
guard args.count == 4 else {
    fatalError("Usage: verify-update.swift archive.zip signature.txt Info.plist")
}
let archive = try Data(contentsOf: URL(fileURLWithPath: args[1]))
let attributes = try String(contentsOfFile: args[2], encoding: .utf8)
let plistData = try Data(contentsOf: URL(fileURLWithPath: args[3]))
let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]
let expression = try NSRegularExpression(pattern: #"sparkle:edSignature="([^"]+)""#)
guard let match = expression.firstMatch(in: attributes, range: NSRange(attributes.startIndex..., in: attributes)),
      let range = Range(match.range(at: 1), in: attributes),
      let signature = Data(base64Encoded: String(attributes[range])),
      let publicKeyText = plist["SUPublicEDKey"] as? String,
      let publicKey = Data(base64Encoded: publicKeyText) else {
    fatalError("Invalid update signature or embedded public key")
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
guard key.isValidSignature(signature, for: archive) else {
    fatalError("Update does not match the public key embedded in MacCat")
}
print("Sparkle signature matches the app's public key.")
