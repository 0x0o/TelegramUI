import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

enum PasscodeSetupInitialState {
    case createPasscode
    case changePassword(current: String, hasRecoveryEmail: Bool, hasSecureValues: Bool)
}

enum PasscodeSetupStateKind: Int32 {
    case enterPasscode
    case confirmPasscode
}

private func generateFieldBackground(backgroundColor: UIColor, borderColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 1.0, height: 48.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)
        
        context.setFillColor(borderColor.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: 1.0, height: UIScreenPixel)))
    })
}

final class PasscodeSetupControllerNode: ASDisplayNode {
    private var presentationData: PresentationData
    private var mode: PasscodeSetupControllerMode
    
    private let wrapperNode: ASDisplayNode
    
    private let titleNode: ASTextNode
    private let inputFieldNode: PasscodeEntryInputFieldNode
    private let inputFieldBackgroundNode: ASImageNode
    private let modeButtonNode: HighlightableButtonNode
    
    var previousPasscode: String?
    var currentPasscode: String {
        return self.inputFieldNode.text
    }
    
    var selectPasscodeMode: (() -> Void)?
    var complete: ((String, Bool) -> Void)?
    var updateNextAction: ((Bool) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var validLayout: ContainerViewLayout?

    init(presentationData: PresentationData, mode: PasscodeSetupControllerMode) {
        self.presentationData = presentationData
        self.mode = mode
        
        self.wrapperNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.EnterPasscode_EnterNewPasscodeNew, font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        
        self.inputFieldNode = PasscodeEntryInputFieldNode(color: self.presentationData.theme.list.itemPrimaryTextColor, fieldType: .digits6, keyboardAppearance: self.presentationData.theme.chatList.searchBarKeyboardColor.keyboardAppearance)
        self.inputFieldBackgroundNode = ASImageNode()
        self.inputFieldBackgroundNode.alpha = 0.0
        self.inputFieldBackgroundNode.contentMode = .scaleToFill
        self.inputFieldBackgroundNode.image = generateFieldBackground(backgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor, borderColor: self.presentationData.theme.list.itemBlocksSeparatorColor)
        
        self.modeButtonNode = HighlightableButtonNode()
        self.modeButtonNode.setTitle(self.presentationData.strings.PasscodeSettings_PasscodeOptions, with: Font.regular(17.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
      
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.addSubnode(self.wrapperNode)
        
        self.wrapperNode.addSubnode(self.titleNode)
        self.wrapperNode.addSubnode(self.inputFieldBackgroundNode)
        self.wrapperNode.addSubnode(self.inputFieldNode)
        self.wrapperNode.addSubnode(self.modeButtonNode)
        
        self.inputFieldNode.complete = { [weak self] passcode in
            self?.activateNext()
        }
        
        self.modeButtonNode.addTarget(self, action: #selector(self.modePressed), forControlEvents: .touchUpInside)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let insets = layout.insets(options: [.statusBar, .input])
        
        self.wrapperNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        let inputFieldFrame = self.inputFieldNode.updateLayout(layout: layout, transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        transition.updateFrame(node: self.inputFieldBackgroundNode, frame: CGRect(x: 0.0, y: inputFieldFrame.minY - 6.0, width: layout.size.width, height: 48.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: inputFieldFrame.minY - titleSize.height - 20.0), size: titleSize))
        
        transition.updateFrame(node: self.modeButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - 53.0), size: CGSize(width: layout.size.width, height: 44.0)))
    }
    
    func updateMode(_ mode: PasscodeSetupControllerMode) {
        self.mode = mode
        self.inputFieldNode.reset()
        
        if case let .setup(type) = mode {
            self.inputFieldNode.updateFieldType(type, animated: true)
            
            let fieldBackgroundAlpha: CGFloat
            if case .alphanumeric = type {
                fieldBackgroundAlpha = 1.0
                self.updateNextAction?(true)
            } else {
                fieldBackgroundAlpha = 0.0
                self.updateNextAction?(false)
            }
            let previousAlpha = self.inputFieldBackgroundNode.alpha
            self.inputFieldBackgroundNode.alpha = fieldBackgroundAlpha
            self.inputFieldBackgroundNode.layer.animateAlpha(from: previousAlpha, to: fieldBackgroundAlpha, duration: 0.25)
        }
    }
    
    func activateNext() {
        guard !self.currentPasscode.isEmpty else {
            self.animateError()
            return
        }
        
        if let previousPasscode = self.previousPasscode {
            if self.currentPasscode == previousPasscode {
                var numerical = false
                if case let .setup(type) = mode {
                    if case .alphanumeric = type {
                    } else {
                        numerical = true
                    }
                }
                self.complete?(self.currentPasscode, numerical)
            } else {
                self.animateError()
            }
        } else {
            self.previousPasscode = self.currentPasscode
            
            if let snapshotView = self.wrapperNode.view.snapshotContentTree() {
                snapshotView.frame = self.wrapperNode.frame
                self.wrapperNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.wrapperNode.view)
                snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -self.wrapperNode.bounds.width, y: 0.0), duration: 0.25, additive: true, completion : { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.wrapperNode.layer.animatePosition(from: CGPoint(x: self.wrapperNode.bounds.width, y: 0.0), to: CGPoint(), duration: 0.25, additive: true)

                self.inputFieldNode.reset(animated: false)
                self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.EnterPasscode_RepeatNewPasscode, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                self.modeButtonNode.isHidden = true
                
                if let validLayout = self.validLayout {
                    self.containerLayoutUpdated(validLayout, navigationBarHeight: 0.0, transition: .immediate)
                }
            }
        }
    }
    
    func activateInput() {
        self.inputFieldNode.activateInput()
    }
    
    func animateError() {
        self.inputFieldNode.reset()
        self.inputFieldNode.layer.addShakeAnimation(amplitude: -30.0, duration: 0.5, count: 6, decay: true)
        
        self.hapticFeedback.error()
    }
    
    @objc func modePressed() {
        self.selectPasscodeMode?()
    }
}