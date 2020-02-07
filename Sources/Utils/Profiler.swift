import Foundation

/**
 A simpler helper class to profile parts of your code and print values out to the console.

 To use you first start the profiling e.g. Profiler.start("myId"), then when you want to print out the duration
 you can use the print function i.e.

 Profiler.print(from: "myId", msg: "Doing something")

 The from: parameter tells the function where the start point was. This will print out:

 [2.30s] Doing something
 */
public final class Profiler {

  static var identifiers = [String: TimeInterval]()

  public static func start(_ identifier: String) {
    identifiers[identifier] = Date.timeIntervalSinceReferenceDate
  }

  public static func print(from identifier: String, msg: String) {
    guard let fromTime = identifiers[identifier] else {
      return
    }

    let delta = Date.timeIntervalSinceReferenceDate - fromTime
    Swift.print("[\(String(format: "%.2f", delta))s] \(msg)")
  }
}
