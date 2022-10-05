// Copyright 2019, ComgineGRPC
// Licensed under the Apache License, Version 2.0

import Foundation
import Combine
import GRPC
import NIO
import NIOHPACK
@testable import CombineGRPC

class BidirectionalStreamingTestsService: BidirectionalStreamingScenariosProvider {

  var interceptors: BidirectionalStreamingScenariosServerInterceptorFactoryProtocol?
  
  // OK, echoes back each message in the request stream
  func ok(context: StreamingResponseCallContext<EchoResponse>)
    -> EventLoopFuture<(StreamEvent<EchoRequest>) -> Void>
  {
    CombineGRPC.handle(context) { requests in
      requests
        .map { req in
          EchoResponse.with { $0.message = req.message }
        }
        .setFailureType(to: RPCError.self)
        .eraseToAnyPublisher()
    }
  }
  
  // Fails
  func failedPrecondition(context: StreamingResponseCallContext<Empty>)
    -> EventLoopFuture<(StreamEvent<EchoRequest>) -> Void>
  {
    CombineGRPC.handle(context) { _ in
      let status = GRPCStatus(code: .failedPrecondition, message: "Failed precondition message")
      let additionalMetadata = HPACKHeaders([("custom", "info")])
      let error = RPCError(status: status, trailingMetadata: additionalMetadata)
      return Fail<Empty, RPCError>(error: error).eraseToAnyPublisher()
    }
  }
  
  // An RPC that never completes
  func noResponse(context: StreamingResponseCallContext<Empty>)
    -> EventLoopFuture<(StreamEvent<EchoRequest>) -> Void>
  {
    CombineGRPC.handle(context) { _ in
      Combine.Empty<Empty, RPCError>(completeImmediately: false).eraseToAnyPublisher()
    }
  }
}
