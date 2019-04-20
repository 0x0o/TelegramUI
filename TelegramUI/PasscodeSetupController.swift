import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox

enum PasscodeSetupControllerMode {
    case setup(PasscodeEntryFieldType)
    case entry(PostboxAccessChallengeData)
}

final class PasscodeSetupController: ViewController {
    private var controllerNode: PasscodeSetupControllerNode {
        return self.displayNode as! PasscodeSetupControllerNode
    }
    
    private let context: AccountContext
    private var mode: PasscodeSetupControllerMode
    
    var complete: ((String, Bool) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var presentationData: PresentationData
    
    private var nextAction: UIBarButtonItem?
    
    init(context: AccountContext, mode: PasscodeSetupControllerMode) {
        self.context = context
        self.mode = mode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.nextAction = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        
        self.title = self.presentationData.strings.PasscodeSettings_Title
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PasscodeSetupControllerNode(presentationData: self.presentationData, mode: self.mode)
        self.displayNodeDidLoad()
        
        self.controllerNode.selectPasscodeMode = { [weak self] in
            guard let strongSelf = self, case let .setup(type) = strongSelf.mode else {
                return
            }
            
            let controller = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            
            var items: [ActionSheetButtonItem] = []
            if case .digits6 = type {
            } else {
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.PasscodeSettings_6DigitCode, action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.mode = .setup(.digits6)
                        strongSelf.controllerNode.updateMode(strongSelf.mode)
                    }
                    dismissAction()
                }))
            }
            if case .digits4 = type {
            } else {
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.PasscodeSettings_4DigitCode, action: {
                    if let strongSelf = self {
                        strongSelf.mode = .setup(.digits4)
                        strongSelf.controllerNode.updateMode(strongSelf.mode)
                    }
                    dismissAction()
                }))
            }
            if case .alphanumeric = type {
            } else {
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.PasscodeSettings_AlphanumericCode, action: {
                    if let strongSelf = self {
                        strongSelf.mode = .setup(.alphanumeric)
                        strongSelf.controllerNode.updateMode(strongSelf.mode)
                    }
                    dismissAction()
                }))
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            controller.dismissed = { _ in
                self?.controllerNode.activateInput()
            }
            strongSelf.view.endEditing(true)
            strongSelf.present(controller, in: .window(.root))
        }
        self.controllerNode.updateNextAction = { [weak self] visible in
            guard let strongSelf = self else {
                return
            }
            
            if visible {
                strongSelf.navigationItem.rightBarButtonItem = strongSelf.nextAction
            } else {
                strongSelf.navigationItem.rightBarButtonItem = nil
            }
        }
        self.controllerNode.complete = { [weak self] passcode, numerical in
            if let strongSelf = self {
                strongSelf.complete?(passcode, numerical)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    @objc func nextPressed() {
       self.controllerNode.activateNext()
    }
}