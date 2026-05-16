import Foundation
#if canImport(Contacts)
import Contacts
#endif

public struct ContactsTool: ToolProtocol {
    public let name = "search_contacts"
    public let description = "Search the user's contacts by name. Returns matching contacts with phone numbers and emails. Input: 'name' (the search query — can be partial)."

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Contact name to search for. Can be partial.",
                ],
            ],
            "required": ["name"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let name = (input["name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { return "Missing 'name' parameter." }

        #if canImport(Contacts) && os(iOS)
        let store = CNContactStore()

        let granted: Bool = try await withCheckedThrowingContinuation { cont in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: granted)
                }
            }
        }
        guard granted else { return "Contacts access not granted." }

        let predicate = CNContact.predicateForContacts(matchingName: name)
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

        if contacts.isEmpty {
            return "No contacts found matching '\(name)'."
        }

        let lines = contacts.prefix(10).map { c -> String in
            let fullName = "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces)
            var bits: [String] = ["• \(fullName.isEmpty ? "(no name)" : fullName)"]
            if !c.phoneNumbers.isEmpty {
                let phones = c.phoneNumbers.map { $0.value.stringValue }.joined(separator: ", ")
                bits.append("phone: \(phones)")
            }
            if !c.emailAddresses.isEmpty {
                let emails = c.emailAddresses.map { $0.value as String }.joined(separator: ", ")
                bits.append("email: \(emails)")
            }
            return bits.joined(separator: " — ")
        }

        var output = "Found \(contacts.count) contact(s) matching '\(name)':\n" + lines.joined(separator: "\n")
        if contacts.count > 10 {
            output += "\n(+\(contacts.count - 10) more)"
        }
        return output
        #else
        return "Contacts not available on this platform. Mock: 妈妈 — phone: 138-xxxx-xxxx"
        #endif
    }
}
