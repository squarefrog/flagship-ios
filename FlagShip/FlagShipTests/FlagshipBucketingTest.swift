//
//  FlagshipBucketingTest.swift
//  FlagshipTests
//
//  Created by Adel on 16/11/2021.
//

import Flagship
import XCTest

@testable import Flagship

class FlagshipBucketingTest: XCTestCase {
    var testVisitor: FSVisitor?
    var urlFakeSession: URLSession?
    var fsConfig: FlagshipConfig?
    
    override func setUpWithError() throws {
        /// Configuration
        let configuration = URLSessionConfiguration.ephemeral
        /// Fake session
        // let urlFakeSession: URLSession!
        configuration.protocolClasses = [MockURLProtocol.self]
        urlFakeSession = URLSession(configuration: configuration)
        
        do {
            let testBundle = Bundle(for: type(of: self))
            
            guard let path = testBundle.url(forResource: "bucketMock", withExtension: "json") else {
                return
            }
            
            let data = try Data(contentsOf: path, options: .alwaysMapped)
            
            MockURLProtocol.requestHandler = { _ in
                
                let response = HTTPURLResponse(url: URL(string: "BucketMock")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }
            
        } catch {
            print("---------------- Failed to load the buckeMock file ----------")
        }
    }
    
    func testBucketingWithSucess() {
        let expectationSync = XCTestExpectation(description: "testBucketingWithSucess")
        
        fsConfig = FSConfigBuilder().Bucketing().withBucketingPollingIntervals(5).withStatusListener { newStatus in
            if newStatus == .READY {
                print("Polling is done, we can fetch the flags")
                self.testVisitor?.fetchFlags(onFetchCompleted: {
                    // Get from alloc 100
                    if let flag = self.testVisitor?.getFlag(key: "stringFlag", defaultValue: "default") {
                        XCTAssertTrue(flag.value() as? String == "alloc_100")
                    }
                    expectationSync.fulfill()
                })
            }
        }.build()
        
        /// Start sdk
        Flagship.sharedInstance.start(envId: "gk87t3jggr10c6l6sdob", apiKey: "apiKey", config: fsConfig ?? FSConfigBuilder().build())
        
        /// Create new visitor
        testVisitor = Flagship.sharedInstance.newVisitor("alias").build()
        /// Erase all cached data
        testVisitor?.strategy?.getStrategy().flushVisitor()

        wait(for: [expectationSync], timeout: 60.0)
    }
    
    func testBucketingWithFailedTargeting() { // The visitor id here make the trageting failed
        let expectationSync = XCTestExpectation(description: "testBucketingWithFailedTargeting")
        
        fsConfig = FSConfigBuilder().Bucketing().withBucketingPollingIntervals(5).withStatusListener { newStatus in
            if newStatus == .READY {
                print("Polling is done, we can fetch the flags")
                self.testVisitor?.fetchFlags {
                    // Get from alloc 100
                    let flag2 = self.testVisitor?.getFlag(key: "stringFlag", defaultValue: "default")
                    XCTAssertTrue(flag2?.value() as? String == "default")
                    expectationSync.fulfill()
                }
            }
        }.build()
        
        /// Start sdk
        Flagship.sharedInstance.start(envId: "gk87t3jggr10c6l6sdob", apiKey: "apiKey", config: fsConfig ?? FSConfigBuilder().build())
        /// Create new visitor
        testVisitor = Flagship.sharedInstance.newVisitor("korso").build()
        /// Erase all cached data
        testVisitor?.strategy?.getStrategy().flushVisitor()

        wait(for: [expectationSync], timeout: 60.0)
    }
}
