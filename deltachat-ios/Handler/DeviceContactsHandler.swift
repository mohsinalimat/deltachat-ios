import Contacts
import UIKit

class DeviceContactsHandler {
    private let store = CNContactStore()
    weak var contactListDelegate: ContactListDelegate?

    private func makeContactString(contacts: [CNContact]) -> String {
        var contactString: String = ""
        for contact in contacts {
            let displayName: String = "\(contact.givenName) \(contact.familyName)"
            // cnContact can have multiple email addresses -> create contact for each email address
            for emailAddress in contact.emailAddresses {
                contactString += "\(displayName)\n\(emailAddress.value)\n"
            }
        }
        return contactString
    }

    private func addContactsToCore() {
        let storedContacts = fetchContactsWithEmailFromDevice()
        let contactString = makeContactString(contacts: storedContacts)
        dc_add_address_book(mailboxPointer, contactString)
        contactListDelegate?.deviceContactsImported()
    }

    private func fetchContactsWithEmailFromDevice() -> [CNContact] {
        var fetchedContacts: [CNContact] = []

        // takes id from userDefaults (system settings)
        let defaultContainerId = store.defaultContainerIdentifier()
        let predicates = CNContact.predicateForContactsInContainer(withIdentifier: defaultContainerId)
        let keys = [CNContactFamilyNameKey, CNContactGivenNameKey, CNContactEmailAddressesKey]
        let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
        request.mutableObjects = true
        request.unifyResults = true
        request.sortOrder = .userDefault
        request.predicate = predicates

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                if !contact.emailAddresses.isEmpty {
                    fetchedContacts.append(contact)
                }
            }
        } catch {
            print(error)
        }
        return fetchedContacts
    }

    public func importDeviceContacts() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            addContactsToCore()
            contactListDelegate?.accessGranted()
        case .denied:
            contactListDelegate?.accessDenied()
        case .restricted, .notDetermined:
            store.requestAccess(for: .contacts) { [unowned self] granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        self.addContactsToCore()
                        self.contactListDelegate?.accessGranted()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.contactListDelegate?.accessDenied()
                    }
                }
            }
        }
    }
}
