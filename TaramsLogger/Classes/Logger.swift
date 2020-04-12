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
import RealmSwift

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
        case .invalidAWSLogStream: /// re initialize AWS related data
            return -1
        case .invalidDeviceId, .invalidSessionId, .invalidUserId: /// re initialize default data
            return -2
        default:  /// store message to db and push to AWS when internet is available.
            return 0
        }
    }
}

public protocol LoggerDelegate : class {
    func loggingEventFailed(message: String?, timestamp: NSNumber?, error: UploadToAWSError)
    func loggingEventSuccess(message: String?, timestamp: NSNumber?, nextSequenceToken: String?)
    func nextSequenceToken(token: String?)
}

public extension LoggerDelegate {
    func loggingEventFailed(message: String?, timestamp: NSNumber?, error: UploadToAWSError) {}
    func loggingEventSuccess(message: String?, timestamp: NSNumber?, nextSequenceToken: String?){}
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
    private static var logDate = ""
    private static let loggerQueue = DispatchQueue(label: "SportsMe.Logger")
    private static var logsCount = 0
    public static var maximumLogsCount = 500
    public static weak var delegate: LoggerDelegate?
    private static let MIN_HOUR_PROD = 5400000;
    public static var uploadOldDataWhenInternetIsAvailable = true
    public static var shouldEncodeMessageWithUTF8 = true
    private static var reachability: LoggerReachability?
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Logger.reachability?.stopNotifier()
    }
    
    private static func setupReachability() {
        NotificationCenter.default.removeObserver(self)
        do {
            reachability =  try LoggerReachability(hostname: "google.com")
            if uploadOldDataWhenInternetIsAvailable {
                NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .reachabilityChanged, object: reachability)
                do {
                    try reachability?.startNotifier()
                }
                catch let error {
                    print("reachability Error  while starting notifier \(error)")
                }
            }
        }
        catch let error {
            print("Error while initializing Reachability = \(error)")
        }
    }
    
    @objc public static func reachabilityChanged(_ note: Notification) {
        let reachability = note.object as! LoggerReachability
        
        if reachability.connection != .unavailable {
            writeOldLogsToAWS()
        } else {
            print(" Internet connection is not available")
        }
    }
    
    public static func configure(with awsServiceConfig: AWSServiceConfiguration, awsLogKey: String, awsGroupName: String, awsStreamName: String, deviceId: String, userId: String, sessionId: String, buildType: BuildEnvironment) {
        DispatchQueue.registerDetection(of: loggerQueue)
        setupReachability()
        AWSLogs.register(with: awsServiceConfig, forKey: awsLogKey)
        defaultAWSLogs = AWSLogs(forKey: awsLogKey)
        awsLogGroupName = awsGroupName
        awsLogStreamName = awsStreamName
        
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
        
    }
    
    public static func setAWSLogs(awsLogs: AWSLogs, awsGroupName: String, awsStreamName: String) {
        defaultAWSLogs = awsLogs
        awsLogGroupName = awsGroupName
        awsLogStreamName = awsStreamName
    }
    
    private static func createLogStream(completion: @escaping (() -> Void)){
        guard let logger = Logger.defaultAWSLogs else {
            delegate?.loggingEventFailed(message: "AWSLogs() Initialization error", timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidAWSLogStream)
            return
        }
        
        let logStreamRequest = AWSLogsCreateLogStreamRequest()
        logStreamRequest?.logGroupName = awsLogGroupName
        logStreamRequest?.logStreamName = awsLogStreamName
        logStreamSession = logStreamRequest?.logStreamName ?? "nil"
        
        guard let streamRequest = logStreamRequest else {
            delegate?.loggingEventFailed(message: "AWSLogsCreateLogStreamRequest() instantiation error", timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidAWSLogStream)
            completion()
            return
        }
        
        logger.createLogStream(streamRequest) { (error) in
            if let error = error {
                delegate?.loggingEventFailed(message: error.localizedDescription, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidAWSLogStream)
            }
            completion()
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
        let date = Date()
        if event.allowToLogWrite(environment: Logger.buildType)  && vlaidateAWSParams(message: logMessage) && validateDefaultParams(message: logMessage) {
            loggerQueue.async {
                if reachability?.connection != LoggerReachability.Connection.unavailable {
                    if let logInputEvent = AWSLogsInputLogEvent() {
                        logInputEvent.message = getUTF8EncodedString(message: logMessage)
                        logInputEvent.timestamp = date.timestamp
                        if awsLogSequenceToken == "" {
                            updateNextSequenceToken {
                                putLogEventsToAws(inputLogEvents: [logInputEvent], isUploadingOldLogs: false)
                            }
                        }
                        else {
                            putLogEventsToAws(inputLogEvents: [logInputEvent], isUploadingOldLogs: false)
                        }
                    }
                    else {
                        writeLogToDB(message: message, timestamp: date.timestamp)
                    }
                }
                else {
                    writeLogToDB(message: message, timestamp: date.timestamp)
                }
            }
        }
    }
    
    private static func validateDefaultParams(message: String) -> Bool {
        
        guard !userId.isEmpty else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidUserId)
            return false
        }
        guard !deviceId.isEmpty, deviceId != "nil" else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidDeviceId)
            return false
        }
        guard !sessionId.isEmpty, sessionId != "nil" else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidSessionId)
            return false
        }
        return true
    }
    
    private static func vlaidateAWSParams(message: String) -> Bool {
        
        guard defaultAWSLogs != nil else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidAWSLogsInstance)
            return false
        }
        guard awsLogGroupName != nil else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidAWSLogGroupName)
            return false
        }
        guard awsLogStreamName != nil else {
            delegate?.loggingEventFailed(message: message, timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidawsLogStreamName)
            return false
        }
        return true
    }
    private static func getUTF8EncodedString(message: String) -> String {
        if shouldEncodeMessageWithUTF8 {
            return String(describing: message.utf8CString)
        }
        return message
    }
}

public extension Logger {
    
    private static  func updateNextSequenceToken(completion: @escaping (() -> Void)) {
        guard let logger = Logger.defaultAWSLogs else {
            delegate?.loggingEventFailed(message: "AWSLogs() Initialization error", timestamp: Date.currentTimestamp, error: UploadToAWSError.invalidAWSLogStream)
            return
        }
        if let describeRequest = AWSLogsDescribeLogStreamsRequest() {
            describeRequest.logGroupName = awsLogGroupName
            describeRequest.logStreamNamePrefix = Date().toString()
            logger.describeLogStreams(describeRequest) { (response, error) in
                if let error = error as NSError? {
                    print(error)
                    completion()
                }
                else {
                    if let logStreams = response?.logStreams, logStreams.count == 1 , let firstStream = logStreams.first {
                        awsLogSequenceToken = firstStream.uploadSequenceToken ?? ""
                        completion()
                    }
                    else {
                        createLogStream {
                            completion()
                        }
                    }
                }
            }
        }
        else {
            createLogStream {
                completion()
            }
            
        }
    }
    
    static func writeOldLogsToAWS() {
        if DispatchQueue.current == loggerQueue {
            writeOldLogsToAwsOnLoggerQueue()
        }
        else {
            loggerQueue.async {
                writeOldLogsToAwsOnLoggerQueue()
            }
        }
    }
    
    private static func writeOldLogsToAwsOnLoggerQueue() {
        guard let localList = LogsModel.getAllLogs(), localList.count != 0 else {
            print("There are no pending Logs in DB to send to AWSCloud Watch")
            return
        }
        let inputLogEvents = getInputLogEvents(logModels: localList)
        if awsLogSequenceToken == "" {
            updateNextSequenceToken {
                putLogEventsToAws(inputLogEvents: inputLogEvents, isUploadingOldLogs: true)
            }
        }
        else {
            putLogEventsToAws(inputLogEvents: inputLogEvents, isUploadingOldLogs: true)
        }
    }
    
    private static func putLogEventsToAws(inputLogEvents: [AWSLogsInputLogEvent], isUploadingOldLogs: Bool){
        let logEvent = AWSLogsPutLogEventsRequest()
        logEvent?.logEvents = inputLogEvents
        logEvent?.logGroupName = awsLogGroupName
        logEvent?.logStreamName = logStreamSession
        
        if self.awsLogSequenceToken != "" {
            logEvent?.sequenceToken = self.awsLogSequenceToken
        }
        
        guard let tempLogEvent = logEvent else {
            delegate?.loggingEventFailed(message: inputLogEvents.first?.message, timestamp: inputLogEvents.first?.timestamp, error: UploadToAWSError.invalidAWSLogEventInstance)
            return
        }
        
        defaultAWSLogs.putLogEvents(tempLogEvent) { (response, error) in
            if let error = error as NSError? {
                print("stream name error = \(error), sequence token = \(awsLogSequenceToken)")
                if !isUploadingOldLogs , let message = inputLogEvents.first?.message, let timestamp = inputLogEvents.first?.timestamp {
                    writeLogToDB(message: message, timestamp: timestamp)
                    if let userInfo = error.userInfo as? [String: Any], let sequenceToken = userInfo["expectedSequenceToken"] as? String {
                        self.awsLogSequenceToken = sequenceToken
                    }
                    if error.code < 0 { // -1009 (no internet), -1001(time out), -1003 (server with hostname not found)
                        delegate?.loggingEventFailed(message: message, timestamp: timestamp, error: UploadToAWSError.noInternetconnection)
                    }
                    else { // 9 aws instances not initialized properly
                        delegate?.loggingEventFailed(message: message, timestamp: timestamp, error: UploadToAWSError.invalidAWSLogStream)
                    }
                }
            }
            else if response?.nextSequenceToken != nil {
                delegate?.nextSequenceToken(token: response?.nextSequenceToken)
                self.awsLogSequenceToken = response?.nextSequenceToken ?? ""
                if isUploadingOldLogs {
                    LogsModel.deleteAllLogsFromDB()
                }
                else {
                    delegate?.loggingEventSuccess(message: inputLogEvents.first?.message, timestamp: inputLogEvents.first?.timestamp, nextSequenceToken: response?.nextSequenceToken)
                    writeOldLogsToAWS()
                }
            }
        }
    }
    
    private static func getInputLogEvents(logModels: Results<LogsModel>) -> [AWSLogsInputLogEvent] {
        var inputLogEvents = [AWSLogsInputLogEvent]()
        for item in logModels {
            if let inputLogEvent = AWSLogsInputLogEvent() {
                inputLogEvent.message = getUTF8EncodedString(message: item.message)
                inputLogEvent.timestamp = NSNumber(value: item.timestamp)
                if item.timestamp < (Date.currentTimestamp.intValue - MIN_HOUR_PROD) {
                    inputLogEvent.timestamp = Date.currentTimestamp
                }
                inputLogEvents.append(inputLogEvent)
            }
        }
        return inputLogEvents
    }
    
    private static func writeLogToDB(message: String, timestamp: NSNumber) {
        let logObject = LogsModel(message: message, timestamp: timestamp)
        logObject.addLogToDB()
    }
}

public extension Logger {  // store logs in a textfile with name log.txt
    
    class func writeToFile(message: String = "", event: LogType, file: String = #file, function: String = #function, line: Int = #line) {
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
    
    class func deleteLocalLogsFromTextFile() {
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
                    deleteLocalLogsFromTextFile()
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
