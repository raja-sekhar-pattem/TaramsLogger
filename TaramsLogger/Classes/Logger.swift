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

public enum UploadToAWSError: Error {
    case invalidAWSLogsInstance
    case invalidAWSLogGroupName
    case invalidawsLogStreamName
    case invalidAWSLogEventInstance
    case invalidAWSLogStream
    case invalidUserId
    case invalidDeviceId
    case invalidSessionId
    case noInternetconnection
    struct Constants {
        static let errorStr = "Please set it using function setDefaultAWSLogs(awsLogs: AWSLogs, awsGroupName: String, awsStreamName: String)"
        static let invalidAWSLogsInstanceMessage = "Invalid AWSLogs instance, \(errorStr)"
        static let invalidAWSLogGroupNameMessage = "Invalid AWSGroupName, \(errorStr)"
        static let invalidawsLogStreamNameMessage = "Invalid AWSLogStreamName, \(errorStr)"
        static let invalidAWSLogEventInstanceMessage = "Invalid AWS Log event instance, the instance of AWSLogsPutLogEventsRequest() is nil. Please check the AWSGroupName, AWSStreamName provided to Logger."
        static let invalidAWSLogStreamMessage = "Invalid AWSLogs instance, while creating the instance of AWSLogsCreateLogStreamRequest(). \(errorStr)"
        static let invalidUserIdMessage = "Invalid UserId. Please set the userId using Logger.userId "
        static let invalidDeviceIdMessage = "Invalid UserId. Please set the userId using Logger.deviceId "
        static let invalidSessionIdMessage = "Invalid UserId. Please set the userId using Logger.sessionId "
        static let noInternetconnectionMessage = "The Internet connection appears to be offline."
        
        static let invalidAWSLogsInstanceComment = "Invalid AWSLogs Instance"
        static let invalidAWSLogGroupNameComment = "Invalid AWSGroupName."
        static let invalidawsLogStreamNameComment = "Invalid AWSStreamName"
        static let invalidAWSLogEventInstanceComment = "Invalid AWS Log event instance"
        static let invalidAWSLogStreamComment = "Invalid AWSLogs instance"
        static let invalidUserIdComment = "Invalid UserId"
        static let invalidDeviceIdComment = "Invalid Device Id"
        static let invalidSessionIdComment = "Invalid SessionId"
        static let noInternetconnectionComment = "No Internet Connection"
    }
    public var errorDescription: String? {
        
        switch self {
        case .invalidAWSLogsInstance:
            return NSLocalizedString(Constants.invalidAWSLogsInstanceMessage, comment: Constants.invalidAWSLogsInstanceComment)
        case .invalidAWSLogGroupName:
            return NSLocalizedString(Constants.invalidAWSLogGroupNameMessage, comment: Constants.invalidAWSLogGroupNameComment)
        case .invalidawsLogStreamName:
            return NSLocalizedString(Constants.invalidawsLogStreamNameMessage, comment: Constants.invalidawsLogStreamNameComment)
        case .invalidAWSLogEventInstance:
            return NSLocalizedString(Constants.invalidAWSLogEventInstanceMessage, comment: Constants.invalidAWSLogEventInstanceComment)
        case .invalidAWSLogStream:
            return NSLocalizedString(Constants.invalidAWSLogStreamMessage, comment: Constants.invalidAWSLogStreamComment)
        case .invalidUserId:
            return NSLocalizedString(Constants.invalidUserIdMessage, comment: Constants.invalidUserIdComment)
        case .invalidDeviceId:
            return NSLocalizedString(Constants.invalidDeviceIdMessage, comment: Constants.invalidDeviceIdComment)
        case .invalidSessionId:
            return NSLocalizedString(Constants.invalidSessionIdMessage, comment: Constants.invalidSessionIdComment)
        case .noInternetconnection:
            return NSLocalizedString(Constants.noInternetconnectionMessage, comment: Constants.noInternetconnectionComment)
        }
    }
    public var errorCode: Int {
        switch self {
        case .invalidAWSLogStream:
            return -1
        default:
            return 0
        }
    }
}

public protocol LoggerDelegate : class {
    func loggingEventFailed(message: String, timestamp: NSNumber, error: UploadToAWSError)
    func nextSequenceToken(token: String?)
}

public extension LoggerDelegate {
    func nextSequenceToken(token: String?) { }
}

open class Logger {
    private static var defaultAWSLogs: AWSLogs!
    private static var awsLogGroupName: String!
    private static var awsLogStreamName: String!
    private static var logStreamSession:String = ""
    public static var awsLogSequenceToken = ""  /// this value is set every time we push a log to AWS Cloud watch
    public static var deviceId = ""
    public static var userId = ""
    public static var sessionId = ""
    public static var buildType = BuildEnvironment.development
    public static var dateFormat = "dd-MM-yyyy"
    public static var logFileName = "log.txt"
    static let loggerQueue = DispatchQueue(label: "SportsMe.Logger")
    private static var logsCount = 0
    public static var maximumLogsCount = 500
    public static weak var delegate: LoggerDelegate?
    private init() { }

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
    
    public static func configure(with awsServiceConfig: AWSServiceConfiguration, awsLogKey: String, awsGroupName: String, awsStreamName: String, deviceId: String, userId: String, sessionId: String, buildType: BuildEnvironment) {
        
        AWSLogs.register(with: awsServiceConfig, forKey: awsLogKey)
        defaultAWSLogs = AWSLogs(forKey: awsLogKey)
        awsLogGroupName = awsGroupName
        awsLogStreamName = awsStreamName
        createLogStream()
        
        Logger.deviceId = deviceId
        Logger.userId = userId
        Logger.sessionId = sessionId
        Logger.buildType = buildType
    }
    
    public static func registerAndSetAWSLogs(serviceConfig: AWSServiceConfiguration, awsLogKey: String, awsGroupName: String, awsStreamName: String) {
        AWSLogs.register(with: serviceConfig, forKey: awsLogKey)
        defaultAWSLogs = AWSLogs(forKey: awsLogKey)
        awsLogGroupName = awsGroupName
        awsLogStreamName = awsStreamName
        createLogStream()
        
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
        
        guard let logger = Logger.defaultAWSLogs else {
            delegate?.loggingEventFailed(message: "AWSLogs() Initialization error", timestamp: Date.timestamp, error: UploadToAWSError.invalidAWSLogStream)
            return
        }
        guard let streamRequest = logStreamRequest else {
            delegate?.loggingEventFailed(message: "AWSLogsCreateLogStreamRequest() instantiation error", timestamp: Date.timestamp, error: UploadToAWSError.invalidAWSLogStream)
            return
        }
        
        logger.createLogStream(streamRequest) { (error) in
            if let error = error {
                delegate?.loggingEventFailed(message: error.localizedDescription, timestamp: Date.timestamp, error: UploadToAWSError.invalidAWSLogStream)
            }
        }
    }
    
    public static func setDefaultInfo(deviceId: String, userId: String, sessionId: String, buildType: BuildEnvironment) {
        Logger.deviceId = deviceId
        Logger.userId = userId
        Logger.sessionId = sessionId
        Logger.buildType = buildType
    }
    
    private class func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
    
    ///        let uuid = UUID().uuidString
    ///        let key = "\(uuid)"
    /// timeStamp + " | " + appVersion + " : " + osVersion + " | " + deviceUUID + “ | “ + SessionId + “ | ” +  UserId + " | “ +  [logLevelName]  + ” | “  + FileName + " | " + FunctionName + " | " + LineNumber + " : " + Message
    
    open class func getOSInfo() -> String {
        let os = ProcessInfo().operatingSystemVersion
        return "iOS-" + String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }
    
    open class func getVersionString() -> String {
        return "\(Bundle.main.versionNumber) : \(getOSInfo())"
    }
    
    open class func getDefaultString() -> String {
        return "\(Date().toString())| \(getVersionString())| \(deviceId) | \(sessionId) | \(userId)"
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
    
    open class func getFormattedLog(message: String, event: LogType, file: String, function: String, line: Int) -> String {
        return "\(getDefaultString()) | \(event.rawValue) | \(file.components(separatedBy: "/").last ?? file) | \(function) | \(line) : \(message)"
    }
    
    open class func writeLogsToAWSCloudWatch(message: String = "", event: LogType, file: String = #file, function: String = #function, line: Int = #line) {
         let logMessage = getFormattedLog(message: message, event: event, file: file, function: function, line: line)
        
        if event.allowToLogWrite(environment: Logger.buildType)  && vlaidateAWSParams(message: logMessage) {
            loggerQueue.async {
                let logInputEvent = AWSLogsInputLogEvent()
                logInputEvent?.message = logMessage
                logInputEvent?.timestamp = Date.timestamp
                
                let logEvent = AWSLogsPutLogEventsRequest()
                logEvent?.logEvents = [logInputEvent] as? [AWSLogsInputLogEvent]
                logEvent?.logGroupName = awsLogGroupName
                logEvent?.logStreamName = logStreamSession
                
                if self.awsLogSequenceToken != "" {
                    logEvent?.sequenceToken = self.awsLogSequenceToken
                }
                
                guard let tempLogEvent = logEvent else {
                    delegate?.loggingEventFailed(message: logMessage, timestamp: Date.timestamp, error: UploadToAWSError.invalidAWSLogEventInstance)
                    return
                }
                
                defaultAWSLogs.putLogEvents(tempLogEvent) { (response, error) in
                    if let error = error {
                        delegate?.loggingEventFailed(message: error.localizedDescription, timestamp: logInputEvent?.timestamp ?? Date.timestamp, error: UploadToAWSError.noInternetconnection)
                    }
                    else if response?.nextSequenceToken != nil {
                        self.awsLogSequenceToken = response?.nextSequenceToken ?? ""
                    }
                    delegate?.nextSequenceToken(token: response?.nextSequenceToken)
                }
                
            }
        }
    }
    
    private static func validateDefaultParams(message: String) -> Bool {
        
        guard !userId.isEmpty else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.timestamp, error: UploadToAWSError.invalidUserId)
            return false
        }
        guard !deviceId.isEmpty else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.timestamp, error: UploadToAWSError.invalidDeviceId)
            return false
        }
        guard !sessionId.isEmpty else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.timestamp, error: UploadToAWSError.invalidSessionId)
            return false
        }
        return true
    }
    
    private static func vlaidateAWSParams(message: String) -> Bool {
        
        guard defaultAWSLogs != nil else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.timestamp, error: UploadToAWSError.invalidAWSLogsInstance)
            return false
        }
        guard awsLogGroupName != nil else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.timestamp, error: UploadToAWSError.invalidAWSLogGroupName)
            return false
        }
        guard awsLogStreamName != nil else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.timestamp, error: UploadToAWSError.invalidawsLogStreamName)
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
    static var timestamp: NSNumber {
        return (Date().timeIntervalSince1970 * 1000.0) as NSNumber
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


