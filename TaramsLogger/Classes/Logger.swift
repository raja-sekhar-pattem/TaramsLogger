//
//  Logger.swift
//  Logger
//
//  Created by RAJASEKHAR on 09/04/20.
//  Copyright © 2020 RAJASEKHAR. All rights reserved.
//

import Foundation
import UIKit
import AWSLogs

open class Logger {
    static let defaultAWSLogs = AWSLogs(forKey: "DefaultAWSService.Constants.awsLogKey")
    static var logStreamSession = "LogSession"
    static var sequenceToken = "AWS Sequence Token"
    static var deviceId = "Current device ID"
    static var userId = "Logged in user Id"
    static var sessionId = "Current session Id"
    static var logsCount = 0
    static var buildType = BuildType.development
    static let versionString = "\(Bundle.main.versionNumber) : \(getOSInfo()) | \(deviceId)"
    static let loggerQueue = DispatchQueue(label: "SportsMe.Logger")
    static var dateFormat = "dd-MM-yyyy"
    static var logFileName = "log.txt"
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }
    
    enum BuildType {

        /// Debug build
        case development

        /// App store Release build, no flags
        case production

        /// Staging Environment
        case staging
        
        case qa
        /// Whether or not this build type is the active build type.
    }

    
    enum LogType: String {
        case info = "[INFO]"
        case debug = "[DEBUG]"
        case warning = "[WARNING]"
        case error = "[ERROR]"
        case exception = "[EXCEPTION]"
        
        var allowToPrint: Bool {
            var allowed = false
            switch buildType {
            case .development, .qa:
                allowed = true
            case .production, .staging:
                switch self {
                case .info:
                    allowed = true  // return false when application is stable
                case .debug:
                    allowed = true // return false when application is stable
                case .warning:
                    allowed = true
                case .error:
                    allowed = true
                case .exception:
                    allowed = true
                }
            }
            return allowed
        }
        
        var allowToLogWrite: Bool {
            var allowed = false
            switch buildType {
            case .development, .qa:
                allowed = true
            case .production, .staging:
                switch self {
                case .info:
                    allowed = true // return false when application is stable
                case .debug:
                    allowed = true // return false when application is stable
                case .warning:
                    allowed = true
                case .error:
                    allowed = true
                case .exception:
                    allowed = true
                }
            }
            return allowed
        }
    }

    static func getOSInfo() -> String {
        let os = ProcessInfo().operatingSystemVersion
        return "iOS-" + String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }
    
    private class func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
    
    ///        let uuid = UUID().uuidString
    ///        let key = "\(uuid)"
    /// timeStamp + " | " + appVersion + " : " + osVersion + " | " + deviceUUID + “ | “ + SessionId + “ | ” +  UserId + " | “ +  [logLevelName]  + ” | “  + FileName + " | " + FunctionName + " | " + LineNumber + " : " + Message
    
    private class func getDefaultString() -> String {
        return "\(Date().toString())| \(versionString) | \(sessionId) | \(userId)"
    }
    
    class func log(message: String, event: LogType, fileName: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) -> String {
        if event.allowToPrint {
            return "\(getDefaultString()) | \(event.rawValue) | [\(sourceFileName(filePath: fileName))]:\(line) \(column)\(funcName) -> \(message)"
        }
        return ""
    }
    
    private class func getLogFile() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        print("Logfile name: \(paths[0].absoluteString)")
        return paths[0].appendingPathComponent(logFileName)
    }
    
    class func writeLogsToAWSCloudWatch(message: String = "", groupName: String, event: LogType, file: String = #file, function: String = #function, line: Int = #line) {

        if event.allowToLogWrite {
            loggerQueue.async {
                let logMessage = "\(getDefaultString()) | \(event.rawValue) | \(file.components(separatedBy: "/").last ?? file) | \(function) | \(line) : \(message)"
                let logInputEvent = AWSLogsInputLogEvent()
                logInputEvent?.message = logMessage
                logInputEvent?.timestamp = (Date().timeIntervalSince1970 * 1000.0) as NSNumber
                print("logMessage", logMessage)

                let logEvent = AWSLogsPutLogEventsRequest()
                logEvent?.logEvents = [logInputEvent] as? [AWSLogsInputLogEvent]
                logEvent?.logGroupName = groupName
                logEvent?.logStreamName = logStreamSession //BuildType.active.apiEnv.awsLogStreamName
                print("sequenceToken before\(self.sequenceToken)")
                print("logStream@@@@\(String(describing: logEvent?.logStreamName))")

                if self.sequenceToken != "" {
                    logEvent?.sequenceToken = self.sequenceToken
                    print("sequenceToken After\(logEvent?.sequenceToken! ?? "")")
                }

                guard let tempLogEvent = logEvent else {
                    print("templogEvent", logEvent!)
                    return
                }

                defaultAWSLogs.putLogEvents(tempLogEvent) { (response, error) in
                    if response?.nextSequenceToken != nil {
                        self.sequenceToken = response?.nextSequenceToken ?? ""
                    }
                    print("Log Error 1 \(String(describing: error))")
                    print("Log Response \(String(describing: response))")
                }

            }
        }
    }
    
    class func writeToFile(message: String = "", event: LogType, file: String = #file, function: String = #function, line: Int = #line) {
//        writeLogsToAWSCloudWatch(message: message, event: event, file: file, function: function, line: line )
                checkFilesCountAndUpload {
                    if event.allowToLogWrite {
                        loggerQueue.async {
                            let logMessage = "\(getDefaultString()) | \(event.rawValue) | \(file.components(separatedBy: "/").last ?? file) | \(function) | \(line) : \(message)\n".data(using: .utf8)
                            let log = Logger.getLogFile()
                            if let handle = try? FileHandle(forWritingTo: log) {
                                handle.seekToEndOfFile()
                                handle.write(logMessage!)
                                handle.closeFile()
                            }
                            else {
                                try? logMessage?.write(to: log)
                            }
                        }
                    }
                }
    }
    
    class func deleteLocalLogs() {
        let text = ""
        do {
            try text.write(to: Logger.getLogFile(), atomically: false, encoding: .utf8)
        }
        catch {
            print(error)
        }
    }
    
    class func checkFilesCountAndUpload(completion: (() -> Void)) {
        if logsCount >= 500 {
            uploadLogsToAWSS3Bucket { (success) in
                if success {
                    deleteLocalLogs()
                    logsCount = 1
                    completion()
                }
                else {
                    logsCount += 1
                    completion()
                }
            }
        }
        else {
            logsCount += 1
            completion()
        }
    }
    
    class func uploadLogsToAWSS3Bucket(completion: ((Bool) -> Void)) {
        completion(true)
    }
}

extension Date {
    func toString() -> String {
        return Logger.dateFormatter.string(from: self as Date)
    }
}

extension Bundle {
    
    var appName: String {
        guard let appName = infoDictionary?["CFBundleName"] as? String else {return ""}
        return appName
    }
    
    var bundleId: String {
        return bundleIdentifier ?? ""
    }
    
    var versionNumber: String {
        guard let versionNumber = infoDictionary?["CFBundleShortVersionString"] as? String else { return ""}
        return versionNumber
    }
    
    var buildNumber: String {
        guard let buildNumber = infoDictionary?["CFBundleVersion"] as? String else { return ""}
        return buildNumber
    }
}


