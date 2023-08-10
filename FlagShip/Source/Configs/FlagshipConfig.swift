//
//  FSConfig.swift
//  Flagship
//
//  Created by Adel on 31/08/2021.
//

import Foundation


public let FSTimeoutRequestApi = 2.0

public let FSPollingTime = 60.0 /// 60 seconds

public enum FSMode: Int {
    case DECISION_API = 1
    case BUCKETING = 2
}

@objc public class FlagshipConfig: NSObject {
    let fsQueue = DispatchQueue(label: "com.flagshipConfig.queue", attributes: .concurrent)

    var mode: FSMode = .DECISION_API
    var timeout: TimeInterval
    var logLevel: FSLevel = .ALL
    var pollingTime: TimeInterval = FSPollingTime
    var onStatusChanged: ((_ newStatus: FStatus)->Void)? = nil
    var trackingConfig: FSTrackingManagerConfig
    var onVisitorExposed:((VisitorExposed, ExposedFlag)-> Void)? = nil

    /// Cache Manager
    var cacheManager: FSCacheManager

    internal init(_ mode: FSMode = .DECISION_API,
                  _ timeOut: TimeInterval = FSTimeoutRequestApi,
                  _ logLevel: FSLevel = .ALL,
                  pollingTime: TimeInterval = FSPollingTime,
                  cacheManager: FSCacheManager,
                  _ onStatusChanged: ((_ newStatus: FStatus)->Void)? = nil,
                  _ trackingConfig: FSTrackingManagerConfig, _ onVisitorExposed: ((VisitorExposed, ExposedFlag)-> Void)? = nil)
    {
        self.mode = mode
        self.timeout = timeOut
        self.logLevel = logLevel
        self.pollingTime = pollingTime
        self.cacheManager = cacheManager
        self.onStatusChanged = onStatusChanged
        self.trackingConfig = trackingConfig
        self.onVisitorExposed = onVisitorExposed
    }
}

@objc public class FSConfigBuilder: NSObject {
    override public init() {
        self._cacheManager = FSCacheManager(FSDefaultCacheVisitor(), FSDefaultCacheHit())
        // Init with a default value
        self._trackingConfig = FSTrackingManagerConfig()
    }
    
    /// _ Mode
    public private(set) var _mode: FSMode = .DECISION_API
    
    /// _timeOut
    public private(set) var _timeOut: TimeInterval = FSTimeoutRequestApi
    
    /// _logLevel
    public private(set) var _logLevel: FSLevel = .ALL
    
    /// _pollingTime
    public private(set) var _pollingTime: TimeInterval = FSPollingTime
    
    /// Cache manager
    public private(set) var _cacheManager: FSCacheManager
    
    /// Status listener
    public private(set) var _onStatusChanged: ((_ newStatus: FStatus)->Void)? = nil
    
    /// Tracking Config
    public private(set) var _trackingConfig: FSTrackingManagerConfig
    
    /// On visitor Exposure
    public private(set) var _onVisitorExposure: ((VisitorExposed, ExposedFlag)-> Void)? = nil

    /// _ With
    
    /// Decision Mode
    @objc public func DecisionApi()->FSConfigBuilder {
        _mode = .DECISION_API
        return self
    }
    
    /// Bucketing Mode
    @objc public func Bucketing()->FSConfigBuilder {
        _mode = .BUCKETING
        return self
    }
    
    /// TimeOut
    @objc public func withTimeout(_ timeout: TimeInterval)->FSConfigBuilder {
        /// The input is proposed by the MS, then we devide by 1000 to get seconds
        _timeOut = timeout / 1000
        return self
    }
    
    /// LogLevel
    @objc public func withLogLevel(_ logLevel: FSLevel)->FSConfigBuilder {
        _logLevel = logLevel
        return self
    }
    
    /// Polling Time
    @objc public func withBucketingPollingIntervals(_ pollingTime: TimeInterval)->FSConfigBuilder {
        _pollingTime = pollingTime
        return self
    }
    
    /// Cache Manager
    @objc public func withCacheManager(_ customCacheManager: FSCacheManager)->FSConfigBuilder {
        _cacheManager = customCacheManager
        return self
    }
    
    /// listener status
    @objc public func withStatusListener(_ onStatusChanged: @escaping (_ newStatus: FStatus)->Void)->FSConfigBuilder {
        _onStatusChanged = onStatusChanged
        return self
    }
    
    /// Tracking Configuration
    @objc public func withTrackingManagerConfig(_ trackingMgrConfig: FSTrackingManagerConfig)->FSConfigBuilder {
        _trackingConfig = trackingMgrConfig
        return self
    }
    
    /// Visitor Exposed
    @objc public func withOnVisitorExposed(_ onVisitorExposed: ((VisitorExposed, ExposedFlag)-> Void)?)->FSConfigBuilder {
        _onVisitorExposure = onVisitorExposed
        return self
    }
    
    @objc public func build()->FlagshipConfig {
        return FlagshipConfig(_mode, _timeOut, _logLevel, pollingTime: _pollingTime, cacheManager: _cacheManager, _onStatusChanged, _trackingConfig, _onVisitorExposure)
    }
}
