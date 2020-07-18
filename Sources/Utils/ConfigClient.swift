//
//  ConfigClient.swift
//

import Foundation
import Swifter

/**
 A common scenario when developing an app is changing config values, such
 as styling or parameters in a shader for graphical apps. Compiling and
 restarting the app is time consuming.

 ConfigClient connects to a HTTP endpoint that returns a JSON blob, the client
 pings the endpoint every second and whenever changes to the JSON blob are
 detected will raise a onValueChanged event with the updated value.

 In your app you can hook up to this event and update the UI accordingly
 in real-time without having to recompile and run the app. This is very helpful
 when testing shader parameter changes.

 There is a naming convention you ust use for the JSON keys, they need to start
 with the data type e.g.

 { "Int:brightness": 90, "Double:width": 15.5, "Bool:enabled": false }
*/
public final class ConfigClient {

  enum Errors: Error {
    case noIPAddr
  }

  public var onRefreshWithChanges = [() -> Void]()
  public var values = [String: Any]()
  public typealias Listener = (String, Any) -> Void

  public class Subscription {
    let listener: Listener

    init(listener: @escaping Listener) {
      self.listener = listener
    }
  }

  private var onValueChanged = [Subscription]()
  private let remoteUrl: URL?
  private var task: URLSessionDataTask?
  private let server = HttpServer()

  /**
   - parameters:
     - localUrl: A URL to the config file in a local directory
     - remoteUrl: The full URL to the endpoint that returns the config data
  */
  public init(localUrl: URL, remoteUrl: URL?) throws {
    self.remoteUrl = remoteUrl
    let data = try Data(contentsOf: localUrl)
    processData(data: data)
  }

  public func addListener(_ listener: @escaping Listener) -> Subscription {
    let sub = Subscription(listener: listener)
    onValueChanged.append(sub)
    return sub
  }

  public func removeListener(_ subscription: Subscription?) {
    guard let subscription = subscription else {
      return
    }

    guard let index = onValueChanged.firstIndex(where: { sub -> Bool in
      return sub === subscription
    }) else {
      return
    }

    _ = onValueChanged.remove(at: index)
  }

  /**
   Call connect() to try to connect to the API endpoint. If the endpoint
   does not exist the ConfigClient will not try to reconnect
  */
  public func connect() {
    pingForChanges()
  }

  /**
   Starts  a HTTP server, callers can then respond to requests and perform
   specific actions in their app.
   */
  public func startServer(port: UInt16, onRequest: @escaping (HttpRequest) -> Void) -> Error? {
    guard let ipAddr = ConfigClient.getIPAddress() else {
      print("Unable to determine IP address")
      return Errors.noIPAddr
    }

    let isIpv6 = ipAddr.contains(":")
    if isIpv6 {
      server.listenAddressIPv6 = ipAddr
    } else {
      server.listenAddressIPv4 = ipAddr
    }

    server["/command"] = { request in
      onRequest(request)
      return .ok(.htmlBody("OK"))
    }

    do {
      try server.start(port, forceIPv4: !isIpv6, priority: DispatchQoS.QoSClass.background)
      print("Started local config server on: \(String(describing: ipAddr)):\(port)")
      return nil
    } catch {
      return error
    }
  }

  public func stopServer() {
    server.stop()
  }

  public class func getIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&ifaddr) == 0 {
      var ptr = ifaddr
      while ptr != nil {
        defer { ptr = ptr?.pointee.ifa_next }
        let interface = ptr?.pointee
        let addrFamily = interface?.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6),
          let cString = interface?.ifa_name,
          String(cString: cString) == "en0",
          let saLen = (interface?.ifa_addr.pointee.sa_len) {
          var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          let ifaAddr = interface?.ifa_addr
          getnameinfo(ifaAddr,
                      socklen_t(saLen),
                      &hostname,
                      socklen_t(hostname.count),
                      nil,
                      socklen_t(0),
                      NI_NUMERICHOST)
          address = String(cString: hostname)
        }
      }
      freeifaddrs(ifaddr)
    }
    return address
  }

  private func processData(data: Data) {
    do {
      if let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        var hadChanges = false

        jsonSerialized.keys.forEach({ key in
          var didChange = false
          if self.values.index(forKey: key) == nil {
            self.values[key] = jsonSerialized[key]
            didChange = true
          } else {
            if key.starts(with: "Int:") {
              didChange = (self.values[key] as! Int) != (jsonSerialized[key] as! Int)
            }
            if key.starts(with: "Double:") {
              didChange = (self.values[key] as! Double) != (jsonSerialized[key] as! Double)
            }
            if key.starts(with: "[Double]:") {
              didChange = (self.values[key] as! [Double]) != (jsonSerialized[key] as! [Double])
            }
            if key.starts(with: "Bool:") {
              didChange = (self.values[key] as! Bool) != (jsonSerialized[key] as! Bool)
            }
            if key.starts(with: "String:") {
              didChange = (self.values[key] as! String) != (jsonSerialized[key] as! String)
            }
            self.values[key] = jsonSerialized[key]
          }

          if didChange {
            print("\(key): \(String(describing: jsonSerialized[key]))")
            self.onValueChanged.forEach { subscription in
              subscription.listener(key, jsonSerialized[key]!)
            }
            hadChanges = true
          }
        })

        if hadChanges {
          self.onRefreshWithChanges.forEach { (callback) in
            callback()
          }
        }

      } else {
        print("no json")
      }
    } catch let error as NSError {
      print(error.localizedDescription)
      return
    }
  }

  private func pingForChanges() {

    guard let remoteUrl = remoteUrl else {
      print("Remote URL not available")
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
      let request = URLRequest(
        url: remoteUrl,
        cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData,
        timeoutInterval: 10.0
      )
      self.task = URLSession.shared.dataTask(with: request) { (data, _, error) in
        if let error = error {
          print(error)
          return
        }

        guard let data = data else {
          print("No ConfigClient data")
          return
        }

        self.processData(data: data)
        self.pingForChanges()
      }

      self.task!.resume()
    })
  }
}
