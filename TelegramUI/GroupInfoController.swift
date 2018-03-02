import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

import SafariServices

private final class GroupInfoArguments {
    let account: Account
    let peerId: PeerId
    
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    let tapAvatarAction: () -> Void
    let changeProfilePhoto: () -> Void
    let pushController: (ViewController) -> Void
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    let changeNotificationMuteSettings: () -> Void
    let changeNotificationSoundSettings: () -> Void
    let togglePreHistory: (Bool) -> Void
    let openSharedMedia: () -> Void
    let openAdminManagement: () -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addMember: () -> Void
    let removePeer: (PeerId) -> Void
    let convertToSupergroup: () -> Void
    let leave: () -> Void
    let displayUsernameContextMenu: (String) -> Void
    let displayAboutContextMenu: (String) -> Void
    let aboutLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    
    init(account: Account, peerId: PeerId, avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext, tapAvatarAction: @escaping () -> Void, changeProfilePhoto: @escaping () -> Void, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, changeNotificationMuteSettings: @escaping () -> Void, changeNotificationSoundSettings: @escaping () -> Void, togglePreHistory: @escaping (Bool) -> Void, openSharedMedia: @escaping () -> Void, openAdminManagement: @escaping () -> Void, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updateEditingDescriptionText: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addMember: @escaping () -> Void, removePeer: @escaping (PeerId) -> Void, convertToSupergroup: @escaping () -> Void, leave: @escaping () -> Void, displayUsernameContextMenu: @escaping (String) -> Void, displayAboutContextMenu: @escaping (String) -> Void, aboutLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void) {
        self.account = account
        self.peerId = peerId
        self.avatarAndNameInfoContext = avatarAndNameInfoContext
        self.tapAvatarAction = tapAvatarAction
        self.changeProfilePhoto = changeProfilePhoto
        self.pushController = pushController
        self.presentController = presentController
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.changeNotificationSoundSettings = changeNotificationSoundSettings
        self.togglePreHistory = togglePreHistory
        self.openSharedMedia = openSharedMedia
        self.openAdminManagement = openAdminManagement
        self.updateEditingName = updateEditingName
        self.updateEditingDescriptionText = updateEditingDescriptionText
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.addMember = addMember
        self.removePeer = removePeer
        self.convertToSupergroup = convertToSupergroup
        self.leave = leave
        self.displayUsernameContextMenu = displayUsernameContextMenu
        self.displayAboutContextMenu = displayAboutContextMenu
        self.aboutLinkAction = aboutLinkAction
    }
}

private enum GroupInfoSection: ItemListSectionId {
    case info
    case about
    case infoManagement
    case sharedMediaAndNotifications
    case memberManagement
    case members
    case leave
}

private enum GroupInfoEntryTag {
    case about
}

private enum GroupInfoMemberStatus {
    case member
    case admin
}

private enum GroupEntryStableId: Hashable, Equatable {
    case peer(PeerId)
    case index(Int)
    
    static func ==(lhs: GroupEntryStableId, rhs: GroupEntryStableId) -> Bool {
        switch lhs {
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .peer(peerId):
                return peerId.hashValue
            case let .index(index):
                return index.hashValue
        }
    }
}

private enum GroupInfoEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setGroupPhoto(PresentationTheme, String)
    case about(PresentationTheme, String)
    case link(PresentationTheme, String)
    case sharedMedia(PresentationTheme, String)
    case notifications(PresentationTheme, String, String)
    case notificationSound(PresentationTheme, String, String)
    case adminManagement(PresentationTheme, String)
    case groupTypeSetup(PresentationTheme, String, String)
    case preHistory(PresentationTheme, String, Bool)
    case groupDescriptionSetup(PresentationTheme, String, String)
    case groupManagementInfoLabel(PresentationTheme, String, String)
    case membersAdmins(PresentationTheme, String, String)
    case membersBlacklist(PresentationTheme, String, String)
    case addMember(PresentationTheme, String, editing: Bool)
    case member(PresentationTheme, PresentationStrings, index: Int, peerId: PeerId, peer: Peer, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus, editing: ItemListPeerItemEditing, enabled: Bool)
    case convertToSupergroup(PresentationTheme, String)
    case leave(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .setGroupPhoto:
                return GroupInfoSection.info.rawValue
            case .about, .link:
                return GroupInfoSection.about.rawValue
            case .groupTypeSetup, .preHistory, .groupDescriptionSetup, .groupManagementInfoLabel:
                return GroupInfoSection.infoManagement.rawValue
            case .sharedMedia, .notifications, .notificationSound, .adminManagement:
                return GroupInfoSection.sharedMediaAndNotifications.rawValue
            case .membersAdmins, .membersBlacklist:
                return GroupInfoSection.memberManagement.rawValue
            case .addMember, .member:
                return GroupInfoSection.members.rawValue
            case .convertToSupergroup, .leave:
                return GroupInfoSection.leave.rawValue
        }
    }
    
    static func ==(lhs: GroupInfoEntry, rhs: GroupInfoEntry) -> Bool {
        switch lhs {
        case let .info(lhsTheme, lhsStrings, lhsPeer, lhsCachedData, lhsState, lhsUpdatingAvatar):
                if case let .info(rhsTheme, rhsStrings, rhsPeer, rhsCachedData, rhsState, rhsUpdatingAvatar) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer == nil) != (rhsPeer != nil) {
                        return false
                    }
                    if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                        if !lhsCachedData.isEqual(to: rhsCachedData) {
                            return false
                        }
                    } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                        return false
                    }
                    if lhsState != rhsState {
                        return false
                    }
                    if lhsUpdatingAvatar != rhsUpdatingAvatar {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .setGroupPhoto(lhsTheme, lhsText):
                if case let .setGroupPhoto(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .sharedMedia(lhsTheme, lhsText):
                if case let .sharedMedia(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .leave(lhsTheme, lhsText):
                if case let .leave(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .convertToSupergroup(lhsTheme, lhsText):
                if case let .convertToSupergroup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adminManagement(lhsTheme, lhsText):
                if case let .adminManagement(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .about(lhsTheme, lhsText):
                if case let .about(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .link(lhsTheme, lhsText):
                if case let .link(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsTheme, lhsTitle, lhsText):
                if case let .notifications(rhsTheme, rhsTitle, rhsText) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    if lhsText != rhsText {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .notificationSound(lhsTheme, lhsTitle, lhsValue):
                if case let .notificationSound(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .preHistory(lhsTheme, lhsTitle, lhsValue):
                if case let .preHistory(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupTypeSetup(lhsTheme, lhsTitle, lhsText):
                if case let .groupTypeSetup(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .groupDescriptionSetup(lhsTheme, lhsPlaceholder, lhsText):
                if case let .groupDescriptionSetup(rhsTheme, rhsPlaceholder, rhsText) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .groupManagementInfoLabel(lhsTheme, lhsTitle, lhsText):
                if case let .groupManagementInfoLabel(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .membersAdmins(lhsTheme, lhsTitle, lhsText):
                if case let .membersAdmins(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .membersBlacklist(lhsTheme, lhsTitle, lhsText):
                if case let .membersBlacklist(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addMember(lhsTheme, lhsTitle, lhsEditing):
                if case let .addMember(rhsTheme, rhsTitle, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
            case let .member(lhsTheme, lhsStrings, lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsMemberStatus, lhsEditing, lhsEnabled):
                if case let .member(rhsTheme, rhsStrings, rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsMemberStatus, rhsEditing, rhsEnabled) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsMemberStatus != rhsMemberStatus {
                        return false
                    }
                    if lhsPeerId != rhsPeerId {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence != nil) != (rhsPresence != nil) {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    var stableId: GroupEntryStableId {
        switch self {
            case let .member(_, _, _, peerId, _, _, _, _, _):
                return .peer(peerId)
            default:
                return .index(self.sortIndex)
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .setGroupPhoto:
                return 1
            case .about:
                return 2
            case .link:
                return 3
            case .adminManagement:
                return 4
            case .groupTypeSetup:
                return 5
            case .preHistory:
                return 6
            case .groupDescriptionSetup:
                return 7
            case .notifications:
                return 8
            case .notificationSound:
                return 9
            case .sharedMedia:
                return 10
            case .groupManagementInfoLabel:
                return 11
            case .membersAdmins:
                return 12
            case .membersBlacklist:
                return 13
            case .addMember:
                return 14
            case let .member(_, _, index, _, _, _, _, _, _):
                return 20 + index
            case .convertToSupergroup:
                return 100000
            case .leave:
                return 100000 + 1
        }
    }
    
    static func <(lhs: GroupInfoEntry, rhs: GroupInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: GroupInfoArguments) -> ListViewItem {
        switch self {
            case let .info(theme, strings, peer, cachedData, state, updatingAvatar):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, mode: .generic, peer: peer, presence: nil, cachedData: cachedData, state: state, sectionId: self.section, style: .blocks(withTopInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.tapAvatarAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingAvatar)
            case let .setGroupPhoto(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .about(theme, text):
                return ItemListMultilineTextItem(theme: theme, text: text, enabledEntitiyTypes: [.url, .mention, .hashtag], sectionId: self.section, style: .blocks, longTapAction: {
                    arguments.displayAboutContextMenu(text)
                }, linkItemAction: { action, itemLink in
                    arguments.aboutLinkAction(action, itemLink)
                }, tag: GroupInfoEntryTag.about)
            case let .link(theme, url):
                return ItemListActionItem(theme: theme, title: url, kind: .neutral, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.displayUsernameContextMenu(url)
                })
            case let .notifications(theme, title, text):
                return ItemListDisclosureItem(theme: theme, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .notificationSound(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.changeNotificationSoundSettings()
                })
            case let .preHistory(theme, title, value):
                return ItemListSwitchItem(theme: theme, title: title, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.togglePreHistory(value)
                })
            case let .sharedMedia(theme, title):
                return ItemListDisclosureItem(theme: theme, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openSharedMedia()
                })
            case let .adminManagement(theme, title):
                return ItemListDisclosureItem(theme: theme, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openAdminManagement()
                })
            case let .addMember(theme, title, editing):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.addPersonIcon(theme), title: title, sectionId: self.section, editing: editing, action: {
                    arguments.addMember()
                })
            case let .groupTypeSetup(theme, title, text):
                return ItemListDisclosureItem(theme: theme, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.presentController(channelVisibilityController(account: arguments.account, peerId: arguments.peerId, mode: .generic), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                })
            case let .groupDescriptionSetup(theme, placeholder, text):
                return ItemListMultilineInputItem(theme: theme, text: text, placeholder: placeholder, maxLength: 1000, sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, action: {
                    
                })
            case let .membersAdmins(theme, title, text):
                return ItemListDisclosureItem(theme: theme, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(channelAdminsController(account: arguments.account, peerId: arguments.peerId))
                })
            case let .membersBlacklist(theme, title, text):
                return ItemListDisclosureItem(theme: theme, title: title, label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(channelBlacklistController(account: arguments.account, peerId: arguments.peerId))
                })
            case let .member(theme, strings, _, _, peer, presence, memberStatus, editing, enabled):
                let label: String?
                switch memberStatus {
                    case .admin:
                        label = strings.ChatAdmins_AdminLabel
                    case .member:
                        label = nil
                }
                return ItemListPeerItem(theme: theme, strings: strings, account: arguments.account, peer: peer, presence: presence, text: .presence, label: label == nil ? .none : .text(label!), editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: {
                    if let infoController = peerInfoController(account: arguments.account, peer: peer) {
                        arguments.pushController(infoController)
                    }
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
            case let .convertToSupergroup(theme, title):
                return ItemListActionItem(theme: theme, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.convertToSupergroup()
                })
            case let .leave(theme, title):
                return ItemListActionItem(theme: theme, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.leave()
                })
            default:
                preconditionFailure()
        }
    }
}

private struct TemporaryParticipant: Equatable {
    let peer: Peer
    let presence: PeerPresence?
    let timestamp: Int32
    
    static func ==(lhs: TemporaryParticipant, rhs: TemporaryParticipant) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        return true
    }
}

private struct GroupInfoState: Equatable {
    let updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    let editingState: GroupInfoEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let peerIdWithRevealedOptions: PeerId?
    
    let temporaryParticipants: [TemporaryParticipant]
    let successfullyAddedParticipantIds: Set<PeerId>
    let removingParticipantIds: Set<PeerId>
    
    let savingData: Bool
    
    let searchingMembers: Bool
    
    static func ==(lhs: GroupInfoState, rhs: GroupInfoState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.temporaryParticipants != rhs.temporaryParticipants {
            return false
        }
        if lhs.successfullyAddedParticipantIds != rhs.successfullyAddedParticipantIds {
            return false
        }
        if lhs.removingParticipantIds != rhs.removingParticipantIds {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        if lhs.searchingMembers != rhs.searchingMembers {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }

    func withUpdatedTemporaryParticipants(_ temporaryParticipants: [TemporaryParticipant]) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedSuccessfullyAddedParticipantIds(_ successfullyAddedParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingParticipantIds(_ removingParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: removingParticipantIds, savingData: self.savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: savingData, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedSearchingMembers(_ searchingMembers: Bool) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, searchingMembers: searchingMembers)
    }
}

private struct GroupInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let editingDescriptionText: String
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> GroupInfoEditingState {
        return GroupInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: GroupInfoEditingState, rhs: GroupInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

private func canRemoveParticipant(account: Account, isAdmin: Bool, participantId: PeerId, invitedBy: PeerId?) -> Bool {
    if participantId == account.peerId {
        return false
    }
    
    if account.peerId == invitedBy {
        return true
    }
    
    return isAdmin
}

private func groupInfoEntries(account: Account, presentationData: PresentationData, view: PeerView, globalNotificationSettings: GlobalNotificationSettings, state: GroupInfoState) -> [GroupInfoEntry] {
    var entries: [GroupInfoEntry] = []
    
    var highlightAdmins = false
    var canEditGroupInfo = false
    var canEditMembers = false
    var canAddMembers = false
    var isPublic = false
    var isCreator = false
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .creator = group.role {
            isCreator = true
        }
        if group.flags.contains(.adminsEnabled) {
            highlightAdmins = true
            switch group.role {
                case .admin, .creator:
                    canEditGroupInfo = true
                    canEditMembers = true
                    canAddMembers = true
                case .member:
                    break
            }
        } else {
            canEditGroupInfo = true
            canAddMembers = true
            switch group.role {
                case .admin, .creator:
                    canEditMembers = true
                case .member:
                    break
            }
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        highlightAdmins = true
        isPublic = channel.username != nil
        isCreator = channel.flags.contains(.isCreator)
        if channel.hasAdminRights(.canChangeInfo) {
            canEditGroupInfo = true
        }
        if channel.hasAdminRights(.canBanUsers) {
            canEditMembers = true
        }
        if channel.hasAdminRights(.canInviteUsers) {
            canAddMembers = true
        }
    }
    
    if let peer = peerViewMainPeer(view) {
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: canEditGroupInfo ? state.editingState?.editingName : nil, updatingName: state.updatingName)
        entries.append(.info(presentationData.theme, presentationData.strings, peer: peer, cachedData: view.cachedData, state: infoState, updatingAvatar: state.updatingAvatar))
    }
    
    if canEditGroupInfo {
        entries.append(GroupInfoEntry.setGroupPhoto(presentationData.theme, presentationData.strings.GroupInfo_SetGroupPhoto))
    }
    
    let peerNotificationSettings: TelegramPeerNotificationSettings = (view.notificationSettings as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
    let notificationsText: String
    switch peerNotificationSettings.muteState {
        case .muted:
            notificationsText = presentationData.strings.UserInfo_NotificationsDisabled
        case .unmuted:
            notificationsText = presentationData.strings.UserInfo_NotificationsEnabled
    }
    
    if let editingState = state.editingState {
        if let group = view.peers[view.peerId] as? TelegramGroup, case .creator = group.role {
            entries.append(.adminManagement(presentationData.theme, presentationData.strings.GroupInfo_ChatAdmins))
        } else if let cachedChannelData = view.cachedData as? CachedChannelData {
            if isCreator {
                entries.append(GroupInfoEntry.groupTypeSetup(presentationData.theme, presentationData.strings.GroupInfo_GroupType, isPublic ? presentationData.strings.Channel_Setup_TypePublic : presentationData.strings.Channel_Setup_TypePrivate))
                if !isPublic, let cachedData = view.cachedData as? CachedChannelData {
                    entries.append(GroupInfoEntry.preHistory(presentationData.theme, "Group History For New Members", cachedData.flags.contains(.preHistoryEnabled)))
                }
            }
            if canEditGroupInfo {
                entries.append(GroupInfoEntry.groupDescriptionSetup(presentationData.theme, presentationData.strings.Channel_Edit_AboutItem, editingState.editingDescriptionText))
            }
            
            entries.append(GroupInfoEntry.notifications(presentationData.theme, presentationData.strings.GroupInfo_Notifications, notificationsText))
            entries.append(GroupInfoEntry.notificationSound(presentationData.theme, presentationData.strings.GroupInfo_Sound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: peerNotificationSettings.messageSound, default: globalNotificationSettings.effective.groupChats.sound)))
            
            var canViewAdminsAndBanned = false
            if let channel = view.peers[view.peerId] as? TelegramChannel {
                if let adminRights = channel.adminRights, !adminRights.isEmpty {
                    canViewAdminsAndBanned = true
                } else if channel.flags.contains(.isCreator) {
                    canViewAdminsAndBanned = true
                }
            }
            
            if canViewAdminsAndBanned {
                entries.append(GroupInfoEntry.membersAdmins(presentationData.theme, presentationData.strings.Channel_Info_Management, cachedChannelData.participantsSummary.adminCount.flatMap { "\($0)" } ?? ""))
                
                entries.append(GroupInfoEntry.membersBlacklist(presentationData.theme, presentationData.strings.Channel_Info_Banned, cachedChannelData.participantsSummary.bannedCount.flatMap { "\($0)" } ?? "" ))
            }
        }
    } else {
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            if let about = cachedChannelData.about, !about.isEmpty {
                entries.append(.about(presentationData.theme, about))
            }
            if let peer = view.peers[view.peerId] as? TelegramChannel, let username = peer.username, !username.isEmpty {
                entries.append(.link(presentationData.theme, "t.me/" + username))
            }
        }
        
        entries.append(GroupInfoEntry.notifications(presentationData.theme, presentationData.strings.GroupInfo_Notifications, notificationsText))
        entries.append(GroupInfoEntry.sharedMedia(presentationData.theme, presentationData.strings.GroupInfo_SharedMedia))
    }
    
    var canRemoveAnyMember = false
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: participant.peerId, invitedBy: participant.invitedBy) {
                canRemoveAnyMember = true
                break
            }
        }
    } else if let cachedChannelData = view.cachedData as? CachedChannelData, let participants = cachedChannelData.topParticipants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: participant.peerId, invitedBy: nil) {
                canRemoveAnyMember = true
                break
            }
        }
    }
    
    if canAddMembers {
        entries.append(GroupInfoEntry.addMember(presentationData.theme, presentationData.strings.GroupInfo_AddParticipant, editing: state.editingState != nil && canRemoveAnyMember))
    }
    
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        var updatedParticipants = participants.participants
        let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
        
        var peerPresences: [PeerId: PeerPresence] = view.peerPresences
        var peers: [PeerId: Peer] = view.peers
        var disabledPeerIds = state.removingParticipantIds
        
        if !state.temporaryParticipants.isEmpty {
            for participant in state.temporaryParticipants {
                if !existingParticipantIds.contains(participant.peer.id) {
                    updatedParticipants.append(.member(id: participant.peer.id, invitedBy: account.peerId, invitedAt: participant.timestamp))
                    if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                        peerPresences[participant.peer.id] = presence
                    }
                    if peers[participant.peer.id] == nil {
                        peers[participant.peer.id] = participant.peer
                    }
                    disabledPeerIds.insert(participant.peer.id)
                }
            }
        }
        
        let sortedParticipants = updatedParticipants.sorted(by: { lhs, rhs in
            let lhsPresence = peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = peerPresences[rhs.peerId] as? TelegramUserPresence
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if lhsPresence.status < rhsPresence.status {
                    return false
                } else if lhsPresence.status > rhsPresence.status {
                    return true
                }
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }
            
            switch lhs {
                case .creator:
                    return false
                case let .admin(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .admin(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
                case let .member(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .admin(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
            }
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = peers[sortedParticipants[i].peerId] {
                let memberStatus: GroupInfoMemberStatus
                if highlightAdmins {
                    switch sortedParticipants[i] {
                        case .admin, .creator:
                            memberStatus = .admin
                        case .member:
                            memberStatus = .member
                    }
                } else {
                    memberStatus = .member
                }
                entries.append(GroupInfoEntry.member(presentationData.theme, presentationData.strings, index: i, peerId: peer.id, peer: peer, presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: peer.id, invitedBy: sortedParticipants[i].invitedBy), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), enabled: !disabledPeerIds.contains(peer.id)))
            }
        }
    } else if let cachedChannelData = view.cachedData as? CachedChannelData, let participants = cachedChannelData.topParticipants {
        var updatedParticipants = participants.participants
        let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
        var peerPresences: [PeerId: PeerPresence] = view.peerPresences
        var peers: [PeerId: Peer] = view.peers
        var disabledPeerIds = state.removingParticipantIds
        
        if !state.temporaryParticipants.isEmpty {
            for participant in state.temporaryParticipants {
                if !existingParticipantIds.contains(participant.peer.id) {
                    updatedParticipants.append(.member(id: participant.peer.id, invitedAt: participant.timestamp, adminInfo: nil, banInfo: nil))
                    if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                        peerPresences[participant.peer.id] = presence
                    }
                    if peers[participant.peer.id] == nil {
                        peers[participant.peer.id] = participant.peer
                    }
                    disabledPeerIds.insert(participant.peer.id)
                }
            }
        }
        
        let sortedParticipants = updatedParticipants.sorted(by: { lhs, rhs in
            let lhsPresence = peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = peerPresences[rhs.peerId] as? TelegramUserPresence
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if lhsPresence.status < rhsPresence.status {
                    return false
                } else if lhsPresence.status > rhsPresence.status {
                    return true
                }
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }
            
            switch lhs {
                case .creator:
                    return false
                case let .member(lhsId, lhsInvitedAt, _, _):
                    switch rhs {
                        case .creator:
                            return true
                        case let .member(rhsId, rhsInvitedAt, _, _):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
            }
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = peers[sortedParticipants[i].peerId] {
                let memberStatus: GroupInfoMemberStatus
                if highlightAdmins {
                    switch sortedParticipants[i] {
                        case .creator:
                            memberStatus = .admin
                        case let .member(_, _, adminInfo, _):
                            if adminInfo != nil {
                                memberStatus = .admin
                            } else {
                                memberStatus = .member
                            }
                    }
                } else {
                    memberStatus = .member
                }
                entries.append(GroupInfoEntry.member(presentationData.theme, presentationData.strings, index: i, peerId: peer.id, peer: peer, presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: peer.id, invitedBy: nil), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), enabled: !disabledPeerIds.contains(peer.id)))
            }
        }
    }
    
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .Member = group.membership {
            if case .creator = group.role, state.editingState != nil {
                entries.append(.convertToSupergroup(presentationData.theme, presentationData.strings.GroupInfo_ConvertToSupergroup))
            }
            entries.append(.leave(presentationData.theme, presentationData.strings.GroupInfo_DeleteAndExit))
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        if case .member = channel.participationStatus, let cachedChannelData = view.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount, memberCount <= 200 {
            entries.append(.leave(presentationData.theme, presentationData.strings.GroupInfo_DeleteAndExit))
        }
    }
    
    return entries
}

private func valuesRequiringUpdate(state: GroupInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramGroup {
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                return (title, nil)
            }
        }
        return (nil, nil)
    } else if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

public func groupInfoController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(GroupInfoState(updatingAvatar: nil, editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false, searchingMembers: false), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupInfoState(updatingAvatar: nil, editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false, searchingMembers: false))
    let updateState: ((GroupInfoState) -> GroupInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var popToRootImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        actionsDisposable.add(account.viewTracker.updatedCachedChannelParticipants(peerId, forceImmediateUpdate: true).start())
    }
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerDescriptionDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerDescriptionDisposable)
    
    let addMemberDisposable = MetaDisposable()
    actionsDisposable.add(addMemberDisposable)
    
    let removeMemberDisposable = MetaDisposable()
    actionsDisposable.add(removeMemberDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let updateAvatarDisposable = MetaDisposable()
    actionsDisposable.add(updateAvatarDisposable)
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let updatePreHistoryDisposable = MetaDisposable()
    actionsDisposable.add(updatePreHistoryDisposable)
    
    let navigateDisposable = MetaDisposable()
    actionsDisposable.add(navigateDisposable)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    var displayAboutContextMenuImpl: ((String) -> Void)?
    var aboutLinkActionImpl: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    let arguments = GroupInfoArguments(account: account, peerId: peerId, avatarAndNameInfoContext: avatarAndNameInfoContext, tapAvatarAction: {
        let _ = (account.postbox.loadedPeerWithId(peerId) |> take(1) |> deliverOnMainQueue).start(next: { peer in
            if peer.profileImageRepresentations.isEmpty {
                return
            }
            
            let galleryController = AvatarGalleryController(account: account, peer: peer, replaceRootController: { controller, ready in
                
            })
            hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first
                updateHiddenAvatarImpl?()
            }))
            presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                return avatarGalleryTransitionArguments?(entry)
            }))
        })
    }, changeProfilePhoto: {
        let _ = (account.postbox.modify { modifier -> Peer? in
            return modifier.getPeer(peerId)
            } |> deliverOnMainQueue).start(next: { peer in
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                
                let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
                legacyController.statusBar.statusBarStyle = .Ignore
                
                let emptyController = LegacyEmptyController(context: legacyController.context)!
                let navigationController = makeLegacyNavigationController(rootController: emptyController)
                navigationController.setNavigationBarHidden(true, animated: false)
                navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
                
                legacyController.bind(controller: navigationController)
                
                presentControllerImpl?(legacyController, nil)
                
                var hasPhotos = false
                if let peer = peer, !peer.profileImageRepresentations.isEmpty {
                    hasPhotos = true
                }
                
                let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasDeleteButton: hasPhotos, personalPhoto: true, saveEditedPhotos: false, saveCapturedMedia: false)!
                let _ = currentAvatarMixin.swap(mixin)
                mixin.didFinishWithImage = { image in
                    if let image = image {
                        if let data = UIImageJPEGRepresentation(image, 0.6) {
                            let resource = LocalFileMediaResource(fileId: arc4random64())
                            account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                            let representation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: resource)
                            updateState {
                                $0.withUpdatedUpdatingAvatar(.image(representation))
                            }
                            updateAvatarDisposable.set((updatePeerPhoto(account: account, peerId: peerId, resource: resource) |> deliverOnMainQueue).start(next: { result in
                                switch result {
                                    case .complete:
                                        updateState {
                                            $0.withUpdatedUpdatingAvatar(nil)
                                        }
                                    case .progress:
                                        break
                                }
                            }))
                        }
                    }
                }
                mixin.didFinishWithDelete = {
                    let _ = currentAvatarMixin.swap(nil)
                    updateState {
                        if let profileImage = peer?.smallProfileImage {
                            return $0.withUpdatedUpdatingAvatar(.image(profileImage))
                        } else {
                            return $0.withUpdatedUpdatingAvatar(.none)
                        }
                    }
                    updateAvatarDisposable.set((updatePeerPhoto(account: account, peerId: peerId, resource: nil) |> deliverOnMainQueue).start(next: { result in
                        switch result {
                            case .complete:
                                updateState {
                                    $0.withUpdatedUpdatingAvatar(nil)
                                }
                            case .progress:
                                break
                        }
                    }))
                }
                mixin.didDismiss = { [weak legacyController] in
                    let _ = currentAvatarMixin.swap(nil)
                    legacyController?.dismiss()
                }
                let menuController = mixin.present()
                if let menuController = menuController {
                    menuController.customRemoveFromParentViewController = { [weak legacyController] in
                        legacyController?.dismiss()
                    }
                }
        })
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller, presentationArguments in
        presentControllerImpl?(controller, presentationArguments)
    }, changeNotificationMuteSettings: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let notificationAction: (Int32) -> Void = {  muteUntil in
            let muteInterval: Int32?
            if muteUntil <= 0 {
                muteInterval = nil
            } else if muteUntil == Int32.max {
                muteInterval = Int32.max
            } else {
                muteInterval = muteUntil
            }
            
            changeMuteSettingsDisposable.set(updatePeerMuteSetting(account: account, peerId: peerId, muteInterval: muteInterval).start())
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsEnable, action: {
                    dismissAction()
                    notificationAction(0)
                }),
                ActionSheetButtonItem(title: muteForIntervalString(strings: presentationData.strings, value: 1 * 60 * 60), action: {
                    dismissAction()
                    notificationAction(1 * 60 * 60)
                }),
                ActionSheetButtonItem(title: muteForIntervalString(strings: presentationData.strings, value: 8 * 60 * 60), action: {
                    dismissAction()
                    notificationAction(8 * 60 * 60)
                }),
                ActionSheetButtonItem(title: muteForIntervalString(strings: presentationData.strings, value: 2 * 24 * 60 * 60), action: {
                    dismissAction()
                    notificationAction(2 * 24 * 60 * 60)
                }),
                ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsDisable, action: {
                    dismissAction()
                    notificationAction(Int32.max)
                })
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changeNotificationSoundSettings: {
        let _ = (account.postbox.modify { modifier -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
            let peerSettings: TelegramPeerNotificationSettings = (modifier.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
            let globalSettings: GlobalNotificationSettings = (modifier.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
            return (peerSettings, globalSettings)
        } |> deliverOnMainQueue).start(next: { settings in
            let controller = notificationSoundSelectionController(account: account, isModal: true, currentSound: settings.0.messageSound, defaultSound: settings.1.effective.groupChats.sound, completion: { sound in
                let _ = updatePeerNotificationSoundInteractive(account: account, peerId: peerId, sound: sound).start()
            })
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, togglePreHistory: { value in
        updatePreHistoryDisposable.set(updateChannelHistoryAvailabilitySettingsInteractively(postbox: account.postbox, network: account.network, peerId: peerId, historyAvailableForNewMembers: value).start())
    }, openSharedMedia: {
        if let controller = peerSharedMediaController(account: account, peerId: peerId) {
            pushControllerImpl?(controller)
        }
    }, openAdminManagement: {
        pushControllerImpl?(groupAdminsController(account: account, peerId: peerId))
    }, updateEditingName: { editingName in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(GroupInfoEditingState(editingName: editingName, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }, updateEditingDescriptionText: { text in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, addMember: {
        let _ = (account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { groupPeer in
                var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
                var options: [ContactListAdditionalOption] = []
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                var inviteByLinkImpl: (() -> Void)?
                options.append(ContactListAdditionalOption(title: presentationData.strings.GroupInfo_InviteByLink, icon: generateTintedImage(image: UIImage(bundleImageName: "Contact List/LinkActionIcon"), color: presentationData.theme.list.itemAccentColor), action: {
                    inviteByLinkImpl?()
                }))
                
                let contactsController = ContactSelectionController(account: account, title: { $0.GroupInfo_AddParticipantTitle }, options: options, confirmation: { peerId in
                    if let confirmationImpl = confirmationImpl {
                        return confirmationImpl(peerId)
                    } else {
                        return .single(false)
                    }
                })
                confirmationImpl = { [weak contactsController] peerId in
                    return account.postbox.loadedPeerWithId(peerId)
                    |> deliverOnMainQueue
                    |> mapToSignal { peer in
                        let result = ValuePromise<Bool>()
                        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                        if let contactsController = contactsController {
                            let alertController = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.GroupInfo_AddParticipantConfirmation(peer.displayTitle).0, actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {
                                    result.set(false)
                                }),
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                                    result.set(true)
                                })
                            ])
                            contactsController.present(alertController, in: .window(.root))
                        }
                        
                        return result.get()
                    }
                }
                let addMember = contactsController.result
                    |> deliverOnMainQueue
                    |> mapToSignal { memberId -> Signal<Void, NoError> in
                        if let memberId = memberId {
                            return account.postbox.peerView(id: memberId)
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { view -> Signal<Void, NoError> in
                                    if let peer = view.peers[memberId] {
                                        updateState { state in
                                            var found = false
                                            for participant in state.temporaryParticipants {
                                                if participant.peer.id == memberId {
                                                    found = true
                                                    break
                                                }
                                            }
                                            if !found {
                                                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                                var temporaryParticipants = state.temporaryParticipants
                                                temporaryParticipants.append(TemporaryParticipant(peer: peer, presence: view.peerPresences[memberId], timestamp: timestamp))
                                                return state.withUpdatedTemporaryParticipants(temporaryParticipants)
                                            } else {
                                                return state
                                            }
                                        }
                                    }
                                    
                                    return addPeerMember(account: account, peerId: peerId, memberId: memberId)
                                        |> deliverOnMainQueue
                                        |> afterCompleted {
                                            updateState { state in
                                                var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                                successfullyAddedParticipantIds.insert(memberId)
                                                
                                                return state.withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                            }
                                        } |> `catch` { _ -> Signal<Void, NoError> in
                                            updateState { state in
                                                var temporaryParticipants = state.temporaryParticipants
                                                for i in 0 ..< temporaryParticipants.count {
                                                    if temporaryParticipants[i].peer.id == memberId {
                                                        temporaryParticipants.remove(at: i)
                                                        break
                                                    }
                                                }
                                                var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                                successfullyAddedParticipantIds.remove(memberId)
                                                
                                                return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                            }
                                            
                                            return .complete()
                                        }
                                }
                        } else {
                            return .complete()
                        }
                    }
                inviteByLinkImpl = { [weak contactsController] in
                    contactsController?.dismiss()
                    
                    presentControllerImpl?(channelVisibilityController(account: account, peerId: peerId, mode: .privateLink), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                }
                presentControllerImpl?(contactsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                addMemberDisposable.set(addMember.start())
        })
    }, removePeer: { memberId in
        let signal = account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                let result = ValuePromise<Bool>()
                result.set(true)
                return result.get()
            }
            |> mapToSignal { value -> Signal<Void, NoError> in
                if value {
                    updateState { state in
                        var temporaryParticipants = state.temporaryParticipants
                        for i in 0 ..< state.temporaryParticipants.count {
                            if state.temporaryParticipants[i].peer.id == memberId {
                                temporaryParticipants.remove(at: i)
                                break
                            }
                        }
                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                        successfullyAddedParticipantIds.remove(memberId)
                        
                        var removingParticipantIds = state.removingParticipantIds
                        removingParticipantIds.insert(memberId)
                        
                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds).withUpdatedRemovingParticipantIds(removingParticipantIds)
                    }
                    
                    return removePeerMember(account: account, peerId: peerId, memberId: memberId)
                        |> deliverOnMainQueue
                        |> afterDisposed {
                            updateState { state in
                                var removingParticipantIds = state.removingParticipantIds
                                removingParticipantIds.remove(memberId)
                                
                                return state.withUpdatedRemovingParticipantIds(removingParticipantIds)
                            }
                    }
                } else {
                    return .complete()
                }
            }
        removeMemberDisposable.set(signal.start())
    }, convertToSupergroup: {
        pushControllerImpl?(convertToSupergroupController(account: account, peerId: peerId))
    }, leave: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.DialogList_DeleteConversationConfirmation, color: .destructive, action: {
                    dismissAction()
                    let _ = (removePeerChat(postbox: account.postbox, peerId: peerId, reportChatSpam: false)
                        |> deliverOnMainQueue).start(completed: {
                            popToRootImpl?()
                        })
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, displayUsernameContextMenu: { text in
        let shareController = ShareController(account: account, subject: .url(text))
        presentControllerImpl?(shareController, nil)
    }, displayAboutContextMenu: { text in
        displayAboutContextMenuImpl?(text)
    }, aboutLinkAction: { action, itemLink in
        aboutLinkActionImpl?(action, itemLink)
    })
    
    let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), account.viewTracker.peerView(peerId), account.postbox.combinedView(keys: [globalNotificationsKey]))
        |> map { presentationData, state, view, combinedView -> (ItemListControllerState, (ItemListNodeState<GroupInfoEntry>, GroupInfoEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            
            var globalNotificationSettings: GlobalNotificationSettings = GlobalNotificationSettings.defaultSettings
            if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                    globalNotificationSettings = settings
                }
            }
            
            let rightNavigationButton: ItemListNavigationButton
            var secondaryRightNavigationButton: ItemListNavigationButton?
            if let editingState = state.editingState {
                var doneEnabled = true
                if let editingName = editingState.editingName, editingName.isEmpty {
                    doneEnabled = false
                }
                if peer is TelegramChannel {
                    if (view.cachedData as? CachedChannelData) == nil {
                        doneEnabled = false
                    }
                }
                
                if state.savingData {
                    rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: doneEnabled, action: {})
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: doneEnabled, action: {
                        var updateValues: (title: String?, description: String?) = (nil, nil)
                        updateState { state in
                            updateValues = valuesRequiringUpdate(state: state, view: view)
                            if updateValues.0 != nil || updateValues.1 != nil {
                                return state.withUpdatedSavingData(true)
                            } else {
                                return state.withUpdatedEditingState(nil)
                            }
                        }
                        
                        let updateTitle: Signal<Void, Void>
                        if let titleValue = updateValues.title {
                            updateTitle = updatePeerTitle(account: account, peerId: peerId, title: titleValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateTitle = .complete()
                        }
                        
                        let updateDescription: Signal<Void, Void>
                        if let descriptionValue = updateValues.description {
                            updateDescription = updatePeerDescription(account: account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateDescription = .complete()
                        }
                        
                        let signal = combineLatest(updateTitle, updateDescription)
                        
                        updatePeerNameDisposable.set((signal |> deliverOnMainQueue).start(error: { _ in
                            updateState { state in
                                return state.withUpdatedSavingData(false)
                            }
                        }, completed: {
                            updateState { state in
                                return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                            }
                        }))
                    })
                }
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    if let peer = peer as? TelegramGroup {
                        updateState { state in
                            return state.withUpdatedEditingState(GroupInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(peer), editingDescriptionText: ""))
                        }
                    } else if let channel = peer as? TelegramChannel, case .group = channel.info {
                        var text = ""
                        if let cachedData = view.cachedData as? CachedChannelData, let about = cachedData.about {
                            text = about
                        }
                        updateState { state in
                            return state.withUpdatedEditingState(GroupInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(channel), editingDescriptionText: text))
                        }
                    }
                })
                secondaryRightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedSearchingMembers(true)
                    }
                })
            }
            
            var searchItem: ItemListControllerSearch?
            if state.searchingMembers {
                searchItem = GroupInfoSearchItem(account: account, peerId: peerId, cancel: {
                    updateState { state in
                        return state.withUpdatedSearchingMembers(false)
                    }
                }, openPeer: { peer in
                    if let infoController = peerInfoController(account: account, peer: peer) {
                        arguments.pushController(infoController)
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.GroupInfo_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: groupInfoEntries(account: account, presentationData: presentationData, view: view, globalNotificationSettings: globalNotificationSettings, state: state), style: .blocks, searchItem: searchItem)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments)
    }
    popToRootImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
    }
    displayAboutContextMenuImpl = { [weak controller] text in
        if let strongController = controller {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListMultilineTextItemNode {
                    if let tag = itemNode.tag as? GroupInfoEntryTag {
                        if tag == .about {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = text
                })])
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let strongController = controller, let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                    } else {
                        return nil
                    }
                }))
                
            }
        }
    }
    
    aboutLinkActionImpl = { [weak controller] action, itemLink in
        if let controller = controller {
            handlePeerInfoAboutTextAction(account: account, navigateDisposable: navigateDisposable, controller: controller, action: action, itemLink: itemLink)
        }
    }
    
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: ((ASDisplayNode, () -> UIView?), CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, addToTransitionSurface: { _ in
                })
            }
        }
        return nil
    }
    updateHiddenAvatarImpl = { [weak controller] in
        if let controller = controller {
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    itemNode.updateAvatarHidden()
                }
            }
        }
    }
    return controller
}

func handlePeerInfoAboutTextAction(account: Account, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem) {
    let openPeerImpl: (PeerId) -> Void = { [weak controller] peerId in
        let peerSignal: Signal<Peer?, NoError>
        peerSignal = account.postbox.loadedPeerWithId(peerId) |> map { Optional($0) }
        navigateDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { peer in
            if let controller = controller, let peer = peer {
                if let infoController = peerInfoController(account: account, peer: peer) {
                    (controller.navigationController as? NavigationController)?.pushViewController(infoController)
                }
            }
        }))
    }
    
    let openLinkImpl: (String) -> Void = { [weak controller] url in
        navigateDisposable.set((resolveUrl(account: account, url: url) |> deliverOnMainQueue).start(next: { result in
            if let controller = controller {
                switch result {
                case let .externalUrl(url):
                    account.telegramApplicationContext.applicationBindings.openUrl(url)
                case let .peer(peerId):
                    openPeerImpl(peerId)
                case let .channelMessage(peerId, messageId):
                    if let navigationController = controller.navigationController as? NavigationController {
                        navigateToChatController(navigationController: navigationController, account: account, chatLocation: .peer(peerId), messageId: messageId)
                    }
                case let .stickerPack(name):
                    controller.present(StickerPackPreviewController(account: account, stickerPack: .name(name)), in: .window(.root))
                case let .instantView(webpage, anchor):
                    (controller.navigationController as? NavigationController)?.pushViewController(InstantPageController(account: account, webPage: webpage, anchor: anchor))
                case let .join(link):
                    controller.present(JoinLinkPreviewController(account: account, link: link, navigateToPeer: { peerId in
                        openPeerImpl(peerId)
                    }), in: .window(.root))
                default:
                    break
                }
            }
        }))
    }
    
    let openPeerMentionImpl: (String) -> Void = { [weak controller] mention in
        navigateDisposable.set((resolvePeerByName(account: account, name: mention, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peerId in
            if let controller = controller, let peerId = peerId {
                (controller.navigationController as? NavigationController)?.pushViewController(ChatController(account: account, chatLocation: .peer(peerId), messageId: nil))
            }
        }))
    }
    
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    switch action {
    case .tap:
        switch itemLink {
        case let .url(url):
            openLinkImpl(url)
        case let .mention(mention):
            openPeerMentionImpl(mention)
        case let .hashtag(peerName, hashtag):
            let searchController = HashtagSearchController(account: account, peerName: peerName, query: hashtag)
            (controller.navigationController as? NavigationController)?.pushViewController(searchController)
        }
    case .longTap:
        switch itemLink {
        case let .url(url):
            let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: url),
                ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    openLinkImpl(url)
                }),
                ActionSheetButtonItem(title: presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    UIPasteboard.general.string = url
                }),
                ActionSheetButtonItem(title: presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let link = URL(string: url) {
                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                    }
                })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                    ])])
            controller.present(actionSheet, in: .window(.root))
        case let .mention(mention):
            let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: mention),
                ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    openPeerMentionImpl(mention)
                }),
                ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    UIPasteboard.general.string = mention
                })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                    ])])
            controller.present(actionSheet, in: .window(.root))
        case let .hashtag(peerName, hashtag):
            let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: hashtag),
                ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    let searchController = HashtagSearchController(account: account, peerName: peerName, query: hashtag)
                    (controller.navigationController as? NavigationController)?.pushViewController(searchController)
                }),
                ActionSheetButtonItem(title: presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    UIPasteboard.general.string = hashtag
                })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                    ])])
            controller.present(actionSheet, in: .window(.root))
        }
    }
}