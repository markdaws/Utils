//
//  ConfigClient.swift
//

import Foundation

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

  public var onValueChanged = [(key: String, value: Any) -> Void]()
  public var onRefreshWithChanges = [() -> Void]()
  public var values = [String: Any]()

  private let remoteUrl: URL?
  private var task: URLSessionDataTask?

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

  /**
   Call connect() to try to connect to the API endpoint. If the endpoint
   does not exist the ConfigClient will not try to reconnect
  */
  public func connect() {
    pingForChanges()
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
            if key.starts(with: "Bool:") {
              didChange = (self.values[key] as! Bool) != (jsonSerialized[key] as! Bool)
            }
            self.values[key] = jsonSerialized[key]
          }

          if didChange {
            print("\(key): \(String(describing: jsonSerialized[key]))")
            self.onValueChanged.forEach { callback in
              callback(key, jsonSerialized[key]!)
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
