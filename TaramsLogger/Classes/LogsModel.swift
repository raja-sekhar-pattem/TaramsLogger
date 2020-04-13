//
//  LogsModel.swift
//  SportsMe
//
//  Created by RAJASEKHAR on 11/04/20.
//  Copyright © 2020 SportsMe. All rights reserved.
//

import Foundation
import RealmSwift

class LogsModel: Object {
    @objc dynamic var message = ""
    @objc dynamic var timestamp: Int = 0
    
    required init() {
        super.init()
    }
    
    convenience init(message: String, timestamp: NSNumber) {
        self.init()
        self.message = message
        self.timestamp = timestamp.intValue
    }
    
    override static func primaryKey() -> String? {
        return "timestamp"
    }
}

extension LogsModel {
    class func getAllLogs() -> Results<LogsModel>? {
        do {
            let realm = try Realm()
            return realm.objects(LogsModel.self).sorted(byKeyPath: "timestamp", ascending: true)
        }
        catch let error {
            print(error)
            return nil
        }
    }
    
    func addLogToDB(realm: Realm = try! Realm()) {
        do {
            try realm.write {
                realm.add(self, update: .modified)
            }
        }
        catch {
            print(error)
        }
    }
    
    class func deleteLogFromDB(realm: Realm = try! Realm(), timestamp: NSNumber) {
        do {
            try realm.write {
                let logsList = realm.objects(LogsModel.self).filter("timestamp = %@", timestamp.intValue)
                if let log = logsList.first {
                    realm.delete(log)
                }
            }
        }
        catch {
            print(error)
        }
    }
    
    class func deleteAllLogsFromDB(realm: Realm = try! Realm()) {
        do {
            try realm.write {
                realm.delete(realm.objects(LogsModel.self))
            }
        }
        catch {
            print("Could not write to database: ", error)
        }
    }
}
