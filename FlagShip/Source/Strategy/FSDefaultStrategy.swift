//
//  FSDefaultStrategy.swift
//  Flagship
//
//  Created by Adel on 10/09/2021.
//

import Foundation


class FSStrategy {
    
    let visitor:FSVisitor
    
    var status:FStatus
    
    internal var delegate:FSDelegateStrategy?
    
    internal func getStrategy()->FSDelegateStrategy{
        
        switch Flagship.sharedInstance.currentStatus {
        case .READY:
            if (visitor.hasConsented == true){
                return FSDefaultStrategy(visitor)
            }else{
                return FSNoConsentStrategy(visitor)
            }
        case .NOT_INITIALIZED:
            return FSNotReadyStrategy(visitor)
        case .PANIC_ON:
            return FSPanicStrategy(visitor)
        default:
            return FSDefaultStrategy(visitor)
        }
    }
    
    
    init(_ pVisitor:FSVisitor, state:FStatus) {
        
        self.visitor = pVisitor
        
        self.status = state
        
    }
}


/////////// DEFAULT /////////////////////

class FSDefaultStrategy : FSDelegateStrategy{
    
    var visitor:FSVisitor
    
    var assignedHistory:[String:String] = [:]

    
    init(_ pVisitor:FSVisitor) {
        
        self.visitor = pVisitor
    }
    
    
    
    /// Activate
    func activate(_ key: String) {
        /// Add envId to dictionary
        let shared = Flagship.sharedInstance
            
        if let aModification = visitor.currentFlags[key]{
            
            var infosTrack = ["vaid": aModification.variationId, "caid": aModification.variationGroupId,"vid":visitor.visitorId ]
            
            if let aId = visitor.anonymousId{
                
                infosTrack.updateValue(aId, forKey: "aid")
            }
            if let aEnvId = shared.envId {
                
                infosTrack.updateValue(aEnvId, forKey: "cid")
            }
            
            if FSTools.isConnexionAvailable(){
                
                FlagshipLogManager.Log(level: .ALL, tag: .ACTIVATE, messageToDisplay: .ACTIVATE_SUCCESS(""))
                self.visitor.configManager.decisionManager?.activate(infosTrack)
                
            }else{
                FlagshipLogManager.Log(level: .ALL, tag: .ACTIVATE, messageToDisplay: .STORE_ACTIVATE)
                self.saveHit(infosTrack, isActivateTracking: true)
            }
        }
    }
    
    
    func synchronize(onSyncCompleted: @escaping (FStatus) -> Void){
        
        self.visitor.configManager.decisionManager?.getCampaigns(self.visitor.context.getCurrentContext(),withConsent: self.visitor.hasConsented, completion: { campaigns, error in
            
            /// Create the dictionary for all flags
            if(error == nil){
                
                if (campaigns?.panic == true){
                    Flagship.sharedInstance.currentStatus = .PANIC_ON
                    self.visitor.currentFlags.removeAll()
                    onSyncCompleted(.PANIC_ON)
                    
                }else{
                    /// Update new flags
                     self.visitor.updateFlags(campaigns?.getAllModification())
                    Flagship.sharedInstance.currentStatus = .READY
                    onSyncCompleted(.READY)
                }
            }else{
                
                FlagshipLogManager.Log(level: .ALL, tag: .INITIALIZATION, messageToDisplay: .MESSAGE(error.debugDescription))
                onSyncCompleted(.READY) /// Even if we got an error, the sdk is ready to read flags, in this cas the flag will be the default vlaue
            }
        })
    }
    
    
    func updateContext(_ newContext:[String:Any]){
        
        visitor.context.updateContext(newContext)
    }
    
    func getModification<T>(_ key: String, defaultValue: T) -> T {
        
        if let flagObject =  visitor.currentFlags[key] {
        
            if flagObject.value is T{
                
                return flagObject.value as? T ?? defaultValue
                
            }
        }
        return defaultValue
    }
    
    
    /// Get Flag Modification value
    func getFlagModification(_ key: String) -> FSModification? {
        
       return visitor.currentFlags[key]
    }
        
        
    
    func getModificationInfo(_ key: String) -> [String : Any]? {
        
        if let flagObject = visitor.currentFlags[key]{
            
            return ["campaignId":flagObject.campaignId,
                               "variationGroupId":flagObject.variationGroupId,
                               "variationId":flagObject.variationId,
                               "isReference":flagObject.isReference,
                                "campaignType":flagObject.type]
        }
        return nil
    }
    
    func sendHit(_ hit: FSTrackingProtocol) {
        
        visitor.configManager.trackingManger?.sendEvent(hit, forTuple: visitor.createTupleId())
        
    }
    
    /// _ Set Consent
    func setConsent(newValue: Bool) {
        /// Send new value on change consent
        visitor.sendHitConsent(newValue)
    }
    
    func authenticateVisitor(visitorId: String) {
        
        if visitor.configManager.flagshipConfig.mode == .DECISION_API{
            
            /// Update the visitor an anonymous id
            if visitor.anonymousId == nil {
                visitor.anonymousId = visitor.visitorId
            }
            
        }else{
            
            FlagshipLogManager.Log(level: .ALL, tag: .AUTHENTICATE, messageToDisplay:FSLogMessage.IGNORE_AUTHENTICATE)
        }
        
        visitor.visitorId = visitorId
    }
    
    
    
    func unAuthenticateVisitor() {
        
        if visitor.configManager.flagshipConfig.mode == .DECISION_API {
            
            if let anonymId = visitor.anonymousId{
                
                visitor.visitorId = anonymId
            }
            
            visitor.anonymousId = nil
            
        }else{
            
            FlagshipLogManager.Log(level: .ALL, tag: .AUTHENTICATE, messageToDisplay:FSLogMessage.IGNORE_UNAUTHENTICATE)
        }
    }
    
    ///_ Cache Managment
    func cacheVisitor() {
        DispatchQueue.main.async {
           
            /// Before replacing the oldest visitor cache we should keep the oldest variation
            self.visitor.configManager.flagshipConfig.cacheManger.cacheVisitor(self.visitor)
        }
    }
    
    /// _ Lookup visitor
    func lookupVisitor() {
        /// Read the visitor cache from storage
        visitor.configManager.flagshipConfig.cacheManger.lookupVisitorCache(visitoId: visitor.visitorId) { error, cachedVisitor in
            
            if (error == nil){
                
                if let aCachedVisitor = cachedVisitor {
                    
                    self.visitor.mergeCachedVisitor(aCachedVisitor)
                    /// Get the oldest assignation history before saving and loose the information
                    self.visitor.assignedVariationHistory.merge(aCachedVisitor.data?.assignationHistory ?? [:]) {(_,new) in new}
                }
            }else{
                
                FlagshipLogManager.Log(level: .ALL, tag: .STORAGE, messageToDisplay: .ERROR_ON_READ_FILE)
            }
        }
    }
    
    /// _ Flush visitor
    func flushVisitor() {
        /// Flush the visitor
        visitor.configManager.flagshipConfig.cacheManger.flushVisitor(visitor.visitorId)
    }
    
    
    /// _ Save hits in device or on custome implementation
    func saveHit(_ hitToSave:[String:Any], isActivateTracking:Bool) {
        
        guard let typeOfHit = isActivateTracking ? "CAMPAIGN" : hitToSave["t"] as? String else {
            
            return
        }
        /// Create Cache hit object
        let cacheHit = FSCacheHit(visitorId: visitor.visitorId, anonymousId: visitor.anonymousId, type:typeOfHit , bodyTrack:hitToSave)
        
        do {
            /// Encode hit to data
            let encodedHit =  try JSONEncoder().encode(cacheHit)
            /// Cache hit
            DispatchQueue(label: "flagShip.CacheHits.queue").async(execute: DispatchWorkItem {
                self.visitor.configManager.flagshipConfig.cacheManger.cacheHit(visitorId: self.visitor.visitorId, data: encodedHit)
            })
        }catch{
            FlagshipLogManager.Log(level: .ALL, tag:.STORAGE, messageToDisplay:FSLogMessage.MESSAGE("Error to encode hit before saving it"))
        }
    }
    
    /// _ Lookup all hit relative to visitor
    func lookupHits(){
        /// If the connexion is available then try to lookup for hit in order to send them
        if FSTools.isConnexionAvailable(){
            
            self.visitor.configManager.flagshipConfig.cacheManger.lookupHits(self.visitor.visitorId) { error, resultArrayhits in
                
                if let allSavedHits = resultArrayhits,!allSavedHits.isEmpty{
                    
                    /// Retreive the saved hits
                    let savedHits = allSavedHits.filter { item in
                        
                        if (item.data?.type != "CAMPAIGN"){
                            
                            return true
                            
                        }else{ /// Otherwise send this activate
                            
                            if let infosTrack = item.data?.content{
                                
                                DispatchQueue(label: "flagShip.cachedActivate.queue").async(execute: DispatchWorkItem {
                                    
                                    self.visitor.configManager.decisionManager?.activate(infosTrack)
                                })
                            }
                            return false
                        }
                    }
                    DispatchQueue(label: "flagShip.batchHits.queue").async(execute: DispatchWorkItem {
                        
                        self.visitor.configManager.trackingManger?.sendBatchHits(savedHits)
                    })
                    
                }
              
            }
        }
    }
    
    ///_ Flush all hits relative to visitor
    func flushHits(){
        
        // Purge data event
        DispatchQueue(label: "flagShip.FlushStoredEvents.queue").async(execute: DispatchWorkItem {
            
            self.visitor.configManager.flagshipConfig.cacheManger.flushHIts(self.visitor.visitorId)
        })
    }
}







///_ DELEGATE ///
protocol FSDelegateStrategy {
    
    /// update context
    func updateContext(_ newContext:[String:Any])
    //// Get generique
    func getModification<T>(_ key:String, defaultValue:T)->T
    /// Get Flag Modification
    func getFlagModification(_ key: String) -> FSModification?
    /// Synchronize
    func synchronize(onSyncCompleted: @escaping (FStatus) -> Void)
    /// Activate
    func activate(_ key:String)
    /// Get Modification infos
    func getModificationInfo(_ key:String)->[String:Any]?
    /// Send Hits
    func sendHit(_ hit:FSTrackingProtocol)
    /// Set Consent
    func setConsent(newValue:Bool)
    /// authenticateVisitor
    func authenticateVisitor(visitorId: String)
    /// unAuthenticateVisitor
    func unAuthenticateVisitor()
    
    /// _Cache Managment
    func cacheVisitor()
    
    /// _ Lookup Visitor
    func lookupVisitor()
    
    /// _ Flush cache
    func flushVisitor()
    
    /// _ cacheHit
    func saveHit(_ hitToSave:[String:Any], isActivateTracking:Bool)
    /// _ Lookup hits
    func lookupHits()
    
    /// _ Flush hits
    func flushHits()
}
