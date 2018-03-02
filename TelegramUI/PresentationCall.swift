import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import AVFoundation

public enum PresentationCallState: Equatable {
    case waiting
    case ringing
    case requesting(Bool)
    case connecting(Data?)
    case active(Double, Data)
    case terminating
    case terminated(CallSessionTerminationReason?)
    
    public static func ==(lhs: PresentationCallState, rhs: PresentationCallState) -> Bool {
        switch lhs {
            case .waiting:
                if case .waiting = rhs {
                    return true
                } else {
                    return false
                }
            case .ringing:
                if case .ringing = rhs {
                    return true
                } else {
                    return false
                }
            case let .requesting(ringing):
                if case .requesting(ringing) = rhs {
                    return true
                } else {
                    return false
                }
            case .connecting:
                if case .connecting = rhs {
                    return true
                } else {
                    return false
                }
            case let .active(timestamp, keyVisualHash):
                if case .active(timestamp, keyVisualHash) = rhs {
                    return true
                } else {
                    return false
                }
            case .terminating:
                if case .terminating = rhs {
                    return true
                } else {
                    return false
                }
            case let .terminated(lhsReason):
                if case let .terminated(rhsReason) = rhs, lhsReason == rhsReason {
                    return true
                } else {
                    return false
                }
        }
    }
}

private final class PresentationCallToneRenderer {
    let queue: Queue
    
    let tone: PresentationCallTone
    
    private let toneRenderer: MediaPlayerAudioRenderer
    private var toneRendererAudioSession: MediaPlayerAudioSessionCustomControl?
    private var toneRendererAudioSessionActivated = false
    
    init(tone: PresentationCallTone) {
        let queue = Queue.mainQueue()
        self.queue = queue
        
        self.tone = tone
        let data = presentationCallToneData(tone)
        
        var controlImpl: ((MediaPlayerAudioSessionCustomControl) -> Disposable)?
        
        self.toneRenderer = MediaPlayerAudioRenderer(audioSession: .custom({ control in
            return controlImpl?(control) ?? EmptyDisposable
        }), playAndRecord: false, forceAudioToSpeaker: false, updatedRate: {}, audioPaused: {})
        
        controlImpl = { [weak self] control in
            queue.async {
                if let strongSelf = self {
                    strongSelf.toneRendererAudioSession = control
                    if strongSelf.toneRendererAudioSessionActivated {
                        control.activate()
                    }
                }
            }
            return ActionDisposable {
            }
        }
        
        let toneDataOffset = Atomic<Int>(value: 0)
        self.toneRenderer.beginRequestingFrames(queue: DispatchQueue.global(), takeFrame: {
            guard let toneData = data else {
                return .finished
            }
            
            let frameSize = 44100
            
            var takeOffset: Int?
            let _ = toneDataOffset.modify { current in
                takeOffset = current
                return current + frameSize
            }
            
            if let takeOffset = takeOffset {
                var blockBuffer: CMBlockBuffer?
                
                let bytes = malloc(frameSize)!
                toneData.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>) -> Void in
                    var takenCount = 0
                    while takenCount < frameSize {
                        let dataOffset = (takeOffset + takenCount) % toneData.count
                        let dataCount = min(frameSize, toneData.count - dataOffset)
                        memcpy(bytes, dataBytes.advanced(by: dataOffset), dataCount)
                        takenCount += dataCount
                    }
                }
                let status = CMBlockBufferCreateWithMemoryBlock(nil, bytes, frameSize, nil, nil, 0, frameSize, 0, &blockBuffer)
                if status != noErr {
                    return .finished
                }
                
                let sampleCount = frameSize / 2
                
                let pts = CMTime(value: Int64(takeOffset / 2), timescale: 44100)
                var timingInfo = CMSampleTimingInfo(duration: CMTime(value: Int64(sampleCount), timescale: 44100), presentationTimeStamp: pts, decodeTimeStamp: pts)
                var sampleBuffer: CMSampleBuffer?
                var sampleSize = frameSize
                guard CMSampleBufferCreate(nil, blockBuffer, true, nil, nil, nil, 1, 1, &timingInfo, 1, &sampleSize, &sampleBuffer) == noErr else {
                    return .finished
                }
                
                if let sampleBuffer = sampleBuffer {
                    return .frame(MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer, resetDecoder: false, decoded: true))
                } else {
                    return .finished
                }
            } else {
                return .finished
            }
        })
        self.toneRenderer.start()
        self.toneRenderer.setRate(1.0)
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.toneRenderer.stop()
    }
    
    func setAudioSessionActive(_ value: Bool) {
        if self.toneRendererAudioSessionActivated != value {
            self.toneRendererAudioSessionActivated = value
            if let control = self.toneRendererAudioSession {
                if value {
                    self.toneRenderer.setRate(1.0)
                    control.activate()
                } else {
                    self.toneRenderer.setRate(0.0)
                    control.deactivate()
                }
            }
        }
    }
}

public final class PresentationCall {
    private let audioSession: ManagedAudioSession
    private let callSessionManager: CallSessionManager
    private let callKitIntegration: CallKitIntegration?
    
    let internalId: CallSessionInternalId
    let peerId: PeerId
    let isOutgoing: Bool
    let peer: Peer?
    
    private var sessionState: CallSession?
    private var callContextState: OngoingCallContextState?
    private var ongoingGontext: OngoingCallContext
    private var ongoingGontextStateDisposable: Disposable?
    private var reportedIncomingCall = false
    
    private var sessionStateDisposable: Disposable?
    
    private let statePromise = ValuePromise<PresentationCallState>(.waiting, ignoreRepeated: true)
    public var state: Signal<PresentationCallState, NoError> {
        return self.statePromise.get()
    }
    
    private let isMutedPromise = ValuePromise<Bool>(false)
    private var isMutedValue = false
    public var isMuted: Signal<Bool, NoError> {
        return self.isMutedPromise.get()
    }
    
    private let speakerModePromise = ValuePromise<Bool>(false)
    private var speakerModeValue = false
    public var speakerMode: Signal<Bool, NoError> {
        return self.speakerModePromise.get()
    }
    
    private let canBeRemovedPromise = Promise<Bool>(false)
    private var didSetCanBeRemoved = false
    var canBeRemoved: Signal<Bool, NoError> {
        return self.canBeRemovedPromise.get()
    }
    
    private let hungUpPromise = ValuePromise<Bool>()
    
    private var activeTimestamp: Double?
    
    private var audioSessionControl: ManagedAudioSessionControl?
    private var audioSessionDisposable: Disposable?
    private let audioSessionShouldBeActive = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var audioSessionShouldBeActiveDisposable: Disposable?
    private let audioSessionActive = Promise<Bool>(false)
    private var audioSessionActiveDisposable: Disposable?
    private var isAudioSessionActive = false
    
    private var toneRenderer: PresentationCallToneRenderer?
    
    private var droppedCall = false
    private var dropCallKitCallTimer: SwiftSignalKit.Timer?
    
    init(audioSession: ManagedAudioSession, callSessionManager: CallSessionManager, callKitIntegration: CallKitIntegration?, internalId: CallSessionInternalId, peerId: PeerId, isOutgoing: Bool, peer: Peer?) {
        self.audioSession = audioSession
        self.callSessionManager = callSessionManager
        self.callKitIntegration = callKitIntegration
        
        self.internalId = internalId
        self.peerId = peerId
        self.isOutgoing = isOutgoing
        self.peer = peer
        
        self.ongoingGontext = OngoingCallContext(callSessionManager: self.callSessionManager, internalId: self.internalId)
        
        self.sessionStateDisposable = (callSessionManager.callState(internalId: internalId)
        |> deliverOnMainQueue).start(next: { [weak self] sessionState in
            if let strongSelf = self {
                strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, audioSessionControl: strongSelf.audioSessionControl)
            }
        })
        
        self.ongoingGontextStateDisposable = (self.ongoingGontext.state
        |> deliverOnMainQueue).start(next: { [weak self] contextState in
            if let strongSelf = self {
                if let sessionState = strongSelf.sessionState {
                    strongSelf.updateSessionState(sessionState: sessionState, callContextState: contextState, audioSessionControl: strongSelf.audioSessionControl)
                } else {
                    strongSelf.callContextState = contextState
                }
            }
        })
        
        self.audioSessionDisposable = audioSession.push(audioSessionType: .voiceCall, manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    if let sessionState = strongSelf.sessionState {
                        strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, audioSessionControl: control)
                    } else {
                        strongSelf.audioSessionControl = control
                    }
                }
            }
        }, deactivate: { [weak self] in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateIsAudioSessionActive(false)
                        if let sessionState = strongSelf.sessionState {
                            strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, audioSessionControl: nil)
                        } else {
                            strongSelf.audioSessionControl = nil
                        }
                    }
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        })
        
        self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    if let audioSessionControl = strongSelf.audioSessionControl {
                        let audioSessionActive: Signal<Bool, NoError>
                        if let callKitIntegration = strongSelf.callKitIntegration {
                            audioSessionActive = callKitIntegration.audioSessionActive |> filter { $0 } |> timeout(2.0, queue: Queue.mainQueue(), alternate: Signal { subscriber in
                                if let strongSelf = self, let audioSessionControl = strongSelf.audioSessionControl {
                                    audioSessionControl.activate({ _ in })
                                }
                                subscriber.putNext(true)
                                subscriber.putCompletion()
                                return EmptyDisposable
                            })
                        } else {
                            audioSessionControl.activate({ _ in })
                            audioSessionActive = .single(true)
                        }
                        strongSelf.audioSessionActive.set(audioSessionActive)
                    } else {
                        strongSelf.audioSessionActive.set(.single(false))
                    }
                } else {
                    strongSelf.audioSessionActive.set(.single(false))
                }
            }
        })
        
        self.audioSessionActiveDisposable = (self.audioSessionActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateIsAudioSessionActive(value)
            }
        })
    }
    
    deinit {
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.audioSessionActiveDisposable?.dispose()
        self.sessionStateDisposable?.dispose()
        self.ongoingGontextStateDisposable?.dispose()
        self.audioSessionDisposable?.dispose()
        
        if let dropCallKitCallTimer = self.dropCallKitCallTimer {
            dropCallKitCallTimer.invalidate()
            if !self.droppedCall {
                self.callKitIntegration?.dropCall(uuid: self.internalId)
            }
        }
    }
    
    private func updateSessionState(sessionState: CallSession, callContextState: OngoingCallContextState?, audioSessionControl: ManagedAudioSessionControl?) {
        let previous = self.sessionState
        let previousControl = self.audioSessionControl
        self.sessionState = sessionState
        self.callContextState = callContextState
        self.audioSessionControl = audioSessionControl
        
        if previousControl != nil && audioSessionControl == nil {
            print("updateSessionState \(sessionState.state) \(audioSessionControl != nil)")
        }
        
        let presentationState: PresentationCallState?
        
        var wasActive = false
        var wasTerminated = false
        if let previous = previous {
            switch previous.state {
                case .active:
                    wasActive = true
                case .terminated:
                    wasTerminated = true
                default:
                    break
            }
        }
        
        if let audioSessionControl = audioSessionControl, previous == nil || previousControl == nil {
            audioSessionControl.setOutputMode(self.speakerModeValue ? .custom(.speaker) : .system)
            audioSessionControl.setup(synchronous: true)
        }
        
        switch sessionState.state {
            case .ringing:
                presentationState = .ringing
                if let _ = audioSessionControl, previous == nil || previousControl == nil {
                    if !self.reportedIncomingCall {
                        self.reportedIncomingCall = true
                        self.callKitIntegration?.reportIncomingCall(uuid: self.internalId, handle: "\(self.peerId.id)", displayTitle: self.peer?.displayTitle ?? "Unknown", completion: { [weak self] error in
                            if let error = error {
                                Logger.shared.log("PresentationCall", "reportIncomingCall error \(error)")
                                Queue.mainQueue().async {
                                    if let strongSelf = self {
                                        strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .hangUp)
                                    }
                                }
                            }
                        })
                    }
                }
            case .accepting:
                presentationState = .connecting(nil)
            case .dropping:
                presentationState = .terminating
            case let .terminated(reason, _):
                presentationState = .terminated(reason)
            case let .requesting(ringing):
                presentationState = .requesting(ringing)
            case let .active(_, keyVisualHash, _, _):
                if let callContextState = callContextState {
                    switch callContextState {
                        case .initializing:
                            presentationState = .connecting(keyVisualHash)
                        case .failed:
                            presentationState = nil
                            self.callSessionManager.drop(internalId: self.internalId, reason: .disconnect)
                        case .connected:
                            let timestamp: Double
                            if let activeTimestamp = self.activeTimestamp {
                                timestamp = activeTimestamp
                            } else {
                                timestamp = CFAbsoluteTimeGetCurrent()
                                self.activeTimestamp = timestamp
                            }
                            presentationState = .active(timestamp, keyVisualHash)
                    }
                } else {
                    presentationState = .connecting(keyVisualHash)
                }
        }
        
        switch sessionState.state {
            case .requesting:
                if let _ = audioSessionControl {
                    self.audioSessionShouldBeActive.set(true)
                }
            case let .active(key, _, connections, maxLayer):
                self.audioSessionShouldBeActive.set(true)
                if let _ = audioSessionControl, !wasActive || previousControl == nil {
                    self.ongoingGontext.start(key: key, isOutgoing: sessionState.isOutgoing, connections: connections, maxLayer: maxLayer, audioSessionActive: self.audioSessionActive.get())
                    if sessionState.isOutgoing {
                        self.callKitIntegration?.reportOutgoingCallConnected(uuid: sessionState.id, at: Date())
                    }
                }
            case .terminated:
                self.audioSessionShouldBeActive.set(true)
                if wasActive {
                    self.ongoingGontext.stop()
                }
            default:
                self.audioSessionShouldBeActive.set(false)
                if wasActive {
                    self.ongoingGontext.stop()
                }
        }
        if case .terminated = sessionState.state, !wasTerminated {
            if !self.didSetCanBeRemoved {
                self.didSetCanBeRemoved = true
                self.canBeRemovedPromise.set(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
            }
            self.hungUpPromise.set(true)
            if sessionState.isOutgoing {
                if !self.droppedCall && self.dropCallKitCallTimer == nil {
                    let dropCallKitCallTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.dropCallKitCallTimer = nil
                            if !strongSelf.droppedCall {
                                strongSelf.droppedCall = true
                                strongSelf.callKitIntegration?.dropCall(uuid: strongSelf.internalId)
                            }
                        }
                    }, queue: Queue.mainQueue())
                    self.dropCallKitCallTimer = dropCallKitCallTimer
                    dropCallKitCallTimer.start()
                }
            } else {
                self.callKitIntegration?.dropCall(uuid: self.internalId)
            }
        }
        if let presentationState = presentationState {
            self.statePromise.set(presentationState)
            self.updateTone(presentationState)
        }
    }
    
    private func updateTone(_ state: PresentationCallState) {
        var tone: PresentationCallTone?
        switch state {
            case .connecting:
                tone = .connecting
            case .requesting(true):
                tone = .ringing
            case let .terminated(reason):
                if let reason = reason {
                    switch reason {
                        case let .ended(type):
                            switch type {
                                case .busy:
                                    tone = .busy
                                case .hungUp, .missed:
                                    tone = .ended
                            }
                        case .error:
                            tone = .failed
                    }
                }
            default:
                break
        }
        if tone != self.toneRenderer?.tone {
            if let tone = tone {
                let toneRenderer = PresentationCallToneRenderer(tone: tone)
                self.toneRenderer = toneRenderer
                toneRenderer.setAudioSessionActive(self.isAudioSessionActive)
            } else {
                self.toneRenderer = nil
            }
        }
    }
    
    private func updateIsAudioSessionActive(_ value: Bool) {
        if self.isAudioSessionActive != value {
            self.isAudioSessionActive = value
            self.toneRenderer?.setAudioSessionActive(value)
        }
    }
    
    func answer() {
        self.callSessionManager.accept(internalId: self.internalId)
        self.callKitIntegration?.answerCall(uuid: self.internalId)
    }
    
    func hangUp() -> Signal<Bool, NoError> {
        self.callSessionManager.drop(internalId: self.internalId, reason: .hangUp)
        self.ongoingGontext.stop()
        
        return self.hungUpPromise.get()
    }
    
    func rejectBusy() {
        self.callSessionManager.drop(internalId: self.internalId, reason: .busy)
        self.ongoingGontext.stop()
    }
    
    func toggleIsMuted() {
        self.isMutedValue = !self.isMutedValue
        self.isMutedPromise.set(self.isMutedValue)
        self.ongoingGontext.setIsMuted(self.isMutedValue)
    }
    
    func toggleSpeaker() {
        self.speakerModeValue = !self.speakerModeValue
        self.speakerModePromise.set(self.speakerModeValue)
        if let audioSessionControl = self.audioSessionControl {
            audioSessionControl.setOutputMode(self.speakerModeValue ? .speakerIfNoHeadphones : .system)
        }
    }
}