import SwiftUI
import ContactsUI
import MessageUI

struct InviteFriendsOnboardingView: View {

    var onComplete: () -> Void

    @State private var selectedContacts: [SelectedContact] = []
    @State private var showContactPicker = false
    @State private var showMessageComposer = false
    @State private var currentMessageRecipient: String?
    @State private var currentMessageBody: String?
    @State private var sendIndex: Int = 0
    @State private var inviteLinks: [String: String] = [:]
    @State private var isCreatingLinks = false
    @State private var errorMessage: String?

    private let requiredInvites = 3

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                headerSection
                selectedContactsList

                if selectedContacts.count < requiredInvites {
                    addContactButton
                }

                Spacer()

                bottomSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView(onSelect: { name, phone in
                let contact = SelectedContact(name: name, phone: phone)
                if !selectedContacts.contains(where: { $0.phone == phone }) {
                    selectedContacts.append(contact)
                }
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMessageComposer) {
            if let recipient = currentMessageRecipient,
               let body = currentMessageBody {
                MessageComposeView(
                    recipients: [recipient],
                    body: body,
                    onFinished: { _ in
                        showMessageComposer = false
                        sendIndex += 1
                        sendNextOrFinish()
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Constants.Colors.primary)

            Text("Invite 3 friends")
                .font(.fraunces(28, weight: .semiBold))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("The app works best when your people are on it. Pick 3 friends you'd actually want to catch up with.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Selected Contacts

    private var selectedContactsList: some View {
        VStack(spacing: 10) {
            ForEach(selectedContacts) { contact in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Constants.Colors.primary.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Text(String(contact.name.prefix(1)).uppercased())
                            .font(.fraunces(16, weight: .semiBold))
                            .foregroundColor(Constants.Colors.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.inter(15, weight: .medium))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Text(contact.phone)
                            .font(.inter(12, weight: .regular))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Spacer()

                    Button {
                        selectedContacts.removeAll { $0.id == contact.id }
                        inviteLinks.removeValue(forKey: contact.phone)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Constants.Colors.textTertiary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Constants.Colors.border, lineWidth: 1)
                )
            }

            ForEach(0..<max(0, requiredInvites - selectedContacts.count), id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle()
                        .strokeBorder(Constants.Colors.border, lineWidth: 1)
                        .frame(width: 40, height: 40)

                    Text("Add a friend")
                        .font(.inter(15, weight: .regular))
                        .foregroundColor(Constants.Colors.textTertiary)

                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Constants.Colors.border.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Add Contact Button

    private var addContactButton: some View {
        Button {
            showContactPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text("Choose from Contacts")
                    .font(.inter(14, weight: .medium))
            }
            .foregroundColor(Constants.Colors.primary)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 14) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.inter(13, weight: .regular))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await createLinksAndSend() }
            } label: {
                Group {
                    if isCreatingLinks {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Creating invite links…")
                        }
                    } else if selectedContacts.count < requiredInvites {
                        Text("Pick \(requiredInvites - selectedContacts.count) more")
                    } else {
                        Text("Send Invites")
                    }
                }
                .font(.inter(15, weight: .semiBold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Constants.Colors.primary.opacity(
                    selectedContacts.count >= requiredInvites && !isCreatingLinks ? 1.0 : 0.4
                ))
                .foregroundColor(.white)
                .cornerRadius(28)
            }
            .disabled(selectedContacts.count < requiredInvites || isCreatingLinks)

            Button {
                onComplete()
            } label: {
                Text("Skip for now")
                    .font(.inter(13, weight: .medium))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Create Links + Send

    private func createLinksAndSend() async {
        guard MFMessageComposeViewController.canSendText() else {
            errorMessage = "SMS isn't available on this device."
            return
        }

        isCreatingLinks = true
        errorMessage = nil

        for contact in selectedContacts where inviteLinks[contact.phone] == nil {
            if let link = await QueueViewModel().createInviteLink(invitedName: contact.name) {
                inviteLinks[contact.phone] = link
            }
        }

        isCreatingLinks = false

        if inviteLinks.count < selectedContacts.count {
            errorMessage = "Couldn't create all invite links. Check your connection and try again."
            return
        }

        sendIndex = 0
        sendNextOrFinish()
    }

    private func sendNextOrFinish() {
        guard sendIndex < selectedContacts.count else {
            onComplete()
            return
        }
        let contact = selectedContacts[sendIndex]
        let link = inviteLinks[contact.phone] ?? "https://weshouldcatchup.app"
        currentMessageRecipient = contact.phone
        currentMessageBody = "Hey \(contact.name.components(separatedBy: " ").first ?? ""), we should catch up! Tap this link to connect with me: \(link)"
        showMessageComposer = true
    }
}

// MARK: - SelectedContact

struct SelectedContact: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
}

// MARK: - ContactPickerView

struct ContactPickerView: UIViewControllerRepresentable {
    var onSelect: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (String, String) -> Void

        init(onSelect: @escaping (String, String) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if let phone = contact.phoneNumbers.first?.value.stringValue {
                onSelect(name.isEmpty ? "Unknown" : name, phone)
            }
        }
    }
}

// MARK: - MessageComposeView

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinished: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: (MessageComposeResult) -> Void

        init(onFinished: @escaping (MessageComposeResult) -> Void) {
            self.onFinished = onFinished
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinished(result)
        }
    }
}

#Preview {
    InviteFriendsOnboardingView {
        print("Onboarding complete")
    }
}
