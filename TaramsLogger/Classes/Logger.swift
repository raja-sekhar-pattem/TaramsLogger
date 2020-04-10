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
    private static var defaultAWSLogs: AWSLogs!
    private static var awsLogGroupName: String!
    private static var awsLogStreamName: String!
    private static var logStreamSession:String = ""
    public static var awsLogSequenceToken = ""
    public static var deviceId = "Current device ID"
    public static var userId = "Logged in user Id"
    public static var sessionId = "Current session Id"
    public static var buildType = BuildEnvironment.development
    public static var dateFormat = "dd-MM-yyyy"
    public static var logFileName = "log.txt"
    static let loggerQueue = DispatchQueue(label: "SportsMe.Logger")
    private static var logsCount = 0
    public static var maximumLogsCount = 500
    private init() { }
    static var versionString: String {
        return "\(Bundle.main.versionNumber) : \(getOSInfo()) | \(deviceId)"
    }
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }
    public enum BuildEnvironment {
        
        /// Debug build
        case development
        
        /// App store Release build, no flags
        case production
        
        /// Staging Environment
        case staging
        
        case qa
        /// Whether or not this build type is the active build type.
    }
    
    
    public enum LogType: String {
        case info = "[INFO]"
        case debug = "[DEBUG]"
        case warning = "[WARNING]"
        case error = "[ERROR]"
        case exception = "[EXCEPTION]"
        
        func allowToPrint(environment: BuildEnvironment) -> Bool {
            var allowed = false
            switch environment {
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
        
        func allowToLogWrite(environment: BuildEnvironment) -> Bool {
            var allowed = false
            switch environment {
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
    public static func setAWSLogs(awsLogs: AWSLogs, awsGroupName: String, awsStreamName: String) {
        defaultAWSLogs = awsLogs
        awsLogGroupName = awsGroupName
        awsLogStreamName = awsStreamName
        createLogStream()
    }
    
    private static func createLogStream(){
        let logStreamRequest = AWSLogsCreateLogStreamRequest()
        logStreamRequest?.logGroupName = awsLogGroupName
        logStreamRequest?.logStreamName = awsLogStreamName
        logStreamSession = logStreamRequest?.logStreamName ?? "nil"
        
        if let tempLogStreamRequest = logStreamRequest {
            Logger.defaultAWSLogs.createLogStream(tempLogStreamRequest) { (error) in
                print("Log stream Error \(String(describing: error))")
            }
        }
    }
    
    public static func setDefaultInfo(deviceId: String, userId: String, sessionId: String, buildType: BuildEnvironment) {
        Logger.deviceId = deviceId
        Logger.userId = userId
        Logger.sessionId = sessionId
        Logger.buildType = buildType
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
    
    open class func getDefaultString() -> String {
        return "\(Date().toString())| \(versionString) | \(sessionId) | \(userId)"
    }
    
    class func log(message: String, event: LogType, fileName: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) -> String {
        if event.allowToPrint(environment: Logger.buildType) {
            return "\(getDefaultString()) | \(event.rawValue) | [\(sourceFileName(filePath: fileName))]:\(line) \(column)\(funcName) -> \(message)"
        }
        return ""
    }
    
    static func getLogFile() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        print("Logfile name: \(paths[0].absoluteString)")
        return paths[0].appendingPathComponent(logFileName)
    }
    
    open class func writeLogsToAWSCloudWatch(message: String = "", event: LogType, file: String = #file, function: String = #function, line: Int = #line) {
        
        if event.allowToLogWrite(environment: Logger.buildType)  && vlaidateAWSParams() {
            loggerQueue.async {
                let logMessage = "\(getDefaultString()) | \(event.rawValue) | \(file.components(separatedBy: "/").last ?? file) | \(function) | \(line) : \(message)"
                let logInputEvent = AWSLogsInputLogEvent()
                logInputEvent?.message = logMessage
                logInputEvent?.timestamp = (Date().timeIntervalSince1970 * 1000.0) as NSNumber
                print("logMessage", logMessage)
                
                let logEvent = AWSLogsPutLogEventsRequest()
                logEvent?.logEvents = [logInputEvent] as? [AWSLogsInputLogEvent]
                logEvent?.logGroupName = awsLogGroupName
                logEvent?.logStreamName = logStreamSession
                print("sequenceToken before\(self.awsLogSequenceToken)")
                print("logStream@@@@\(String(describing: logEvent?.logStreamName))")
                
                if self.awsLogSequenceToken != "" {
                    logEvent?.sequenceToken = self.awsLogSequenceToken
                    print("sequenceToken After\(logEvent?.sequenceToken! ?? "")")
                }
                
                guard let tempLogEvent = logEvent else {
                    print("templogEvent", logEvent!)
                    return
                }
                
                defaultAWSLogs.putLogEvents(tempLogEvent) { (response, error) in
                    if response?.nextSequenceToken != nil {
                        self.awsLogSequenceToken = response?.nextSequenceToken ?? ""
                    }
                    print("Log Error 1 \(String(describing: error))")
                    print("Log Response \(String(describing: response))")
                }
                
            }
        }
    }
    
    private static func vlaidateAWSParams() -> Bool {
        let errorStr = "Please set it using function setDefaultAWSLogs(awsLogs: AWSLogs, awsGroupName: String, awsStreamName: String, awsSequenceToken: String)"
        
        guard defaultAWSLogs != nil else {
            assertionFailure("Invalid AWSLogs instance, " + errorStr)
            return false
        }
        guard awsLogGroupName != nil else {
            assertionFailure("Invalid awsLogGroupName. " + errorStr)
            return false
        }
        guard awsLogStreamName != nil else {
            assertionFailure("Invalid awsLogStreamName. " + errorStr)
            return false
        }
        return true
    }
    
    open class func writeToFile(message: String = "", event: LogType, file: String = #file, function: String = #function, line: Int = #line) {
        //        writeLogsToAWSCloudWatch(message: message, event: event, file: file, function: function, line: line )
        checkFilesCountAndUpload {
            if event.allowToLogWrite(environment: Logger.buildType) {
                loggerQueue.async {
                    let logMessage = "\(getDefaultString()) | \(event.rawValue) | \(file.components(separatedBy: "/").last ?? file) | \(function) | \(line) : \(message)\n".data(using: .utf8)
                    let log = Logger.getLogFile()
                    if let handle = try? FileHandle(forWritingTo: log) {
                        handle.seekToEndOfFile()
                        handle.write(logMessage!)
                        handle.closeFile()
                    }
                    else {
                        ((try? logMessage?.write(to: log)) as ()??)
                    }
                }
            }
        }
    }
    
    open class func deleteLocalLogs() {
        let text = ""
        do {
            try text.write(to: Logger.getLogFile(), atomically: false, encoding: .utf8)
        }
        catch {
            print(error)
        }
    }
    
    class func checkFilesCountAndUpload(completion: (() -> Void)) {
        if logsCount >= maximumLogsCount {
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

public extension Date {
    func toString() -> String {
        return Logger.dateFormatter.string(from: self as Date)
    }
}

public extension Bundle {
    
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


