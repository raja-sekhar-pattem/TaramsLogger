//
//  ViewController.swift
//  TaramsLogger
//
//  Created by rajasekhar.pattem@tarams.com on 04/09/2020.
//  Copyright (c) 2020 rajasekhar.pattem@tarams.com. All rights reserved.
//

import UIKit
import TaramsLogger
import AWSLogs

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func buttonClickAction(_ sender: UIButton) {
        print("\(sender.titleLabel!.text!) is selected")
        ///if you are using AWSLogs, calling setAWSLogs function is mandatory
        let awsLogs = AWSLogs(forKey: "YOUR AWS LOGS KEY")
        Logger.setAWSLogs(awsLogs:awsLogs , awsGroupName: "AWSGroupName", awsStreamName: "AWSStreamname")
        /// you can set default infor using the setDefaultInfo function or you can directly set it by variable name
        // set info using function
        Logger.setDefaultInfo(deviceId: "DEVICEID", userId: "USERID", sessionId: "SESSIONID", buildType: .development)
        //set info using varaible name
        Logger.deviceId = "new deviceId"
        Logger.logFileName = "loggerLogs.txt"
        ///writing logs to text fille
        Logger.writeToFile(message: Logger.LogMessages.CreatePostBattle.createPost.rawValue, event: .warning,file:#file, function: #function, line: #line)
        /// writing logs to AWS cloud watch
        Logger.writeLogsToAWSCloudWatch(message: "\(sender.titleLabel!.text!) is selected", event: .debug)
    }
    
    

}

extension Logger {
    enum LogMessages {
        enum HomeScreen: String {
            case homeButtonClicked = "clicked Home Screen Home button"
            case searchButtonClicked = "clicked HomeScreen Search button"
            case leaderboardButtonClicked = "clicked HomeScreen Leaderboard button"
            case inboxButtonClicked = "clicked HomeScreen Inbox button"
            case shareButtonClicked = "clicked HomeScreen Share icon"
            case newBattleButtonClicked = "clicked HomeScreen NewBattle button"
            case commentButtonClicked = "clicked HomeScreen Comment button"
            case profileButtonClicked = "clicked HomeScreen profile button"
            case editProfile = "clicked EditProfile button"
            case changeProfile = "changed profile picture"
            case followers = "clicked profile screen Followers"
        }
        enum SearchScreen: String {
            case leaguesSegmentClicked = "clicked Home Screen Home button"
        }
        
        enum CreatePostBattle: String {
            case createPost = "clicked post battle button"
            case postCompleted = "clicked post battle initiated"
        }
        
        enum Signup: String {
            case signup = "clicked on signup button"
        }
        
    }
}

//MARK:- IBInspectable
extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var borderColor: UIColor? {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }

    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.masksToBounds = false
            layer.shadowRadius = newValue
        }
    }

    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.masksToBounds = false
            layer.shadowOpacity = newValue
        }
    }

    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.masksToBounds = false
            layer.shadowOffset = newValue
        }
    }

    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }
}
