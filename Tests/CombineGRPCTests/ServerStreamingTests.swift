// Copyright 2019, Vy-Shane Xie
// Licensed under the Apache License, Version 2.0

import XCTest
import Combine
import GRPC
import NIO
@testable import CombineGRPC

class ServerStreamingTests: XCTestCase {
  
  static var serverEventLoopGroup: EventLoopGroup?
  static var client: ServerStreamingScenariosServiceClient?
  
  override class func setUp() {
    super.setUp()
    serverEventLoopGroup = try! makeTestServer(services: [ServerStreamingTestsService()])
    client = makeTestClient { connection, callOptions in
      ServerStreamingScenariosServiceClient(connection: connection, defaultCallOptions: callOptions)
    }
  }
  
  override class func tearDown() {
    try! client?.connection.close().wait()
    try! serverEventLoopGroup?.syncShutdownGracefully()
    super.tearDown()
  }
  
  func testServerStreamCompletesWithStatusOk() {
    let promise = expectation(description: "Call completes successfully")
    let client = ServerStreamingTests.client!
    
    _ = call(client.serverStreamOk)(EchoRequest.with { $0.message = "hello" })
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let status):
            XCTFail("Unexpected status: " + status.localizedDescription)
          case .finished:
            promise.fulfill()
          }
        },
        receiveValue: { response in
          XCTAssert(response.message == "hello")
        })
    
    wait(for: [promise], timeout: 1)
  }
  
  func testServerStreamPublishesExpectedResponses() {
    let promise = expectation(description: "Call completes successfully")
    let client = ServerStreamingTests.client!
    
    _ = call(client.serverStreamOk)(EchoRequest.with { $0.message = "hello" })
      .filter { $0.message == "hello" }
      .count()
      .sink(
        receiveValue: { count in
          if count == 3 {
            promise.fulfill()
          }
        }
      )
    
    wait(for: [promise], timeout: 1)
  }
  
  func testServerStreamFailedPrecondition() {
    let promise = expectation(description: "Call fails with failed precondition status")
    let serverStreamFailedPrecondition = ServerStreamingTests.client!.serverStreamFailedPrecondition
    
    _ = call(serverStreamFailedPrecondition)(EchoRequest.with { $0.message = "hello" })
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let status):
            if status.code == .failedPrecondition {
              promise.fulfill()
            } else {
              XCTFail("Unexpected status: " + status.localizedDescription)
            }
          case .finished:
            XCTFail("Call should not succeed")
          }
      },
        receiveValue: { empty in
          XCTFail("Call should not return a response")
      })
    
    wait(for: [promise], timeout: 1)
  }
  
  func testServerStreamNoResponse() {
    let promise = expectation(description: "Call fails with deadline exceeded status")
    let client = ServerStreamingTests.client!
    let options = CallOptions(timeout: try! .milliseconds(50))
    
    // Example of partial application of call options to create a pre-configured client call.
    let callWithTimeout: ConfiguredServerStreamingRPC<EchoRequest, Empty> = call(options)
    
    _ = callWithTimeout(client.serverStreamNoResponse)(EchoRequest.with { $0.message = "hello" })
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let status):
            if status.code == .deadlineExceeded {
              promise.fulfill()
            } else {
              XCTFail("Unexpected status: " + status.localizedDescription)
            }
          case .finished:
            XCTFail("Call should not succeed")
          }
      },
        receiveValue: { empty in
          XCTFail("Call should not return a response")
      })
    
    wait(for: [promise], timeout: 1)
  }
  
  static var allTests = [
    ("Server stream completes with status OK", testServerStreamCompletesWithStatusOk),
    ("Server stream publishes expected responses", testServerStreamPublishesExpectedResponses),
    ("Server stream failed precondition", testServerStreamFailedPrecondition),
    ("Server stream no response", testServerStreamNoResponse),
  ]
}
