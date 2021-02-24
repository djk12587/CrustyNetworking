//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

// MARK: - NetworkingSession

public extension NetworkingSession {
    /// The shared singleton `NetworkingSession` object.
    ///
    /// For basic requests, the `NetworkingSession` class provides a shared singleton session object that gives you a reasonable default behavior for creating tasks.
    ///
    /// Unlike the other session types, you don’t create the shared session; you merely access it by using this property directly. As a result, you don’t provide a `URLSession` object, `NetworkingRequestAdapter`, or `NetworkingRequestRetrier`.
    static let shared = NetworkingSession()
}

public class NetworkingSession {

    private let session: URLSession
    private let requestAdapter: NetworkingRequestAdapter?
    private let requestRetrier: NetworkingRequestRetrier?

    public init(session: URLSession = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {

        self.session = session
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    public func createDataTask(from requestConvertible: URLRequestConvertible) -> NetworkingSessionDataTask {
        return NetworkingSessionDataTask(requestConvertible: requestConvertible,
                                         requestRetrier: requestRetrier,
                                         delegate: self)
    }
}

extension NetworkingSession {

    private func start(_ urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask) {
        do {
            let adaptedRequest = try requestAdapter?.adapt(urlRequest: urlRequest, for: session)
            execute(adaptedRequest ?? urlRequest, accompaniedWith: networkingSessionDataTask)
        }
        catch {
            executeResponseSerializers(on: networkingSessionDataTask, becauseOf: error)
        }
    }

    private func execute(_ urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask) {

        let dataTask = session.dataTask(with: urlRequest) { (responseData, response, error) in
            networkingSessionDataTask.executeResponseSerializers(with: DataTaskResponseContainer(response: response as? HTTPURLResponse,
                                                                                                 data: responseData,
                                                                                                 error: error))
        }

        networkingSessionDataTask.dataTask = dataTask
        dataTask.resume()
    }

    private func executeResponseSerializers(on networkingSessionDataTask: NetworkingSessionDataTask, becauseOf error: Error?) {
        networkingSessionDataTask.executeResponseSerializers(with: DataTaskResponseContainer(response: nil,
                                                                                             data: nil,
                                                                                             error: error))
    }
}

extension NetworkingSession: NetworkingSessionDataTaskDelegate {
    internal func restart(urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask) {
        start(urlRequest, accompaniedWith: networkingSessionDataTask)
    }

    internal func networkingSessionDataTaskIsReadyToExecute(networkingSessionDataTask: NetworkingSessionDataTask) {
        if let urlRequest = networkingSessionDataTask.request {
            start(urlRequest, accompaniedWith: networkingSessionDataTask)
        }
        else {
            executeResponseSerializers(on: networkingSessionDataTask, becauseOf: networkingSessionDataTask.urlRequestConvertibleError)
        }
    }
}
