//
//  FSDecisionManager.swift
//  Flagship
//
//  Created by Adel on 02/09/2021.
//


internal class FSDecisionManager {
    var userId:String
    var networkService:FSService

    
    init(service:FSService, userId:String,currentContext:[String:Any]){
        
        self.userId = userId
        networkService = service
    }
    
    func getCampaigns(_ currentContext:[String:Any], withConsent:Bool,completion: @escaping (FSCampaigns?, Error?) -> Void){
        
    }
    
    
    
    /// Send activate via /activate
    /// - Parameter activateInfos: Information relative to activate
    func activate(_ currentActivate:[String:Any]){
        
        
     
        
        self.networkService.activate(currentActivate) { error in
            
            if (error == nil){
                
                
            }

        }
    }
    
    
    
    
    
    
    /// private
    internal func launchPolling(){
        
        
    }
    
    internal func stopPolling(){
        
        
    }
}


class APIManager: FSDecisionManager  {
    
    override func getCampaigns(_ currentContext:[String:Any],withConsent:Bool, completion: @escaping (FSCampaigns?, Error?) -> Void){
        
        /// Service get camapign
        networkService.getCampaigns(currentContext,hasConsented:withConsent) { campaigns, error in
            
            if (error == nil){
                completion(campaigns, nil)
            }else{
                completion(nil, error)
            }
        }
    }
}
