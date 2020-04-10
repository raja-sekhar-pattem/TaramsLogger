//
//  AppDelegate.swift
//  TaramsLogger
//
//  Created by rajasekhar.pattem@tarams.com on 04/09/2020.
//  Copyright (c) 2020 rajasekhar.pattem@tarams.com. All rights reserved.
//

import UIKit
import TaramsLogger
import AWSLogs

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        ///if you are using AWSLogs, calling setAWSLogs function is mandatory
        AWSLogsService.shared.configure()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

class AWSLogsService : LoggerDelegate {
    static let shared = AWSLogsService()
    private init() {
        Logger.delegate = self
    }
    func configure() {
        let awsLogs = AWSLogs(forKey: "YOUR AWS LOGS KEY")
        Logger.setAWSLogs(awsLogs:awsLogs , awsGroupName: "AWSGroupName", awsStreamName: "AWSStreamname")
        /// you can set default infor using the setDefaultInfo function or you can directly set it by variable name
        // set info using function
        Logger.setDefaultInfo(deviceId: "DEVICEID", userId: "USERID", sessionId: "SESSIONID", buildType: .development)
        //set info using varaible name
        Logger.deviceId = "new deviceId"
        Logger.logFileName = "loggerLogs.txt"
//        Logger.messageSendingFailedBlock = { (message, error) in
//            print("Log Event Failed !!!! error: \(error.errorDescription ?? "") errorCode: \(error.errorCode)")
//            print("MESSAGE: \(message)")
//        }
    }
    
    func loggingEventFailed(message: String, timestamp: NSNumber, error: UploadToAWSError) {
        print("Log Event Failed !!!! error: \(error.errorDescription ?? "") errorCode: \(error.errorCode)")
        
        print("MESSAGE: \(message)")
    }
    
    func loggingEventSuccess(message: String, timestamp: NSNumber, nextSequenceToken: String) {
        print("MESSAGE: \(message)")
    }
}
