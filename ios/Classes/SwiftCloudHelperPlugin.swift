import Flutter
import UIKit
import CloudKit

extension Array {
    func chunk(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
@available(iOS 13.0, *)
public class SwiftCloudHelperPlugin: NSObject, FlutterPlugin {
    private var container: CKContainer?

    private var database:  CKDatabase?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cloud_helper", binaryMessenger: registrar.messenger())
        let instance = SwiftCloudHelperPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call, result)
        case "addRecord":
            addRecord(call, result)
        case "addRecordFile":
            addRecordFile(call, result)   
        case "getOneRecord":
            getOneRecord(call, result)
        case "getOneRecordFile":
            getOneRecordFile(call, result)
        case "checkOneRecordAvailable":
            checkOneRecordAvailable(call, result)
        case "editRecord":
            editRecord(call, result)
        case "deleteRecord":
            deleteRecord(call, result)

        case "deleteManyRecords":
            deleteManyRecords(call, result)
        case "getAllRecords":
            getAllRecords(call, result)
        case "getRecordFileInfo":
            getRecordFileInfo(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let containerId = args["containerId"] as? String,
              let databaseType = args["databaseType"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "initialize Required arguments are not provided", details: nil))
            return
        }
        container = CKContainer(identifier: containerId)
        if(databaseType == "B") {
            database = container!.privateCloudDatabase
        }else if(databaseType == "A") {
            database = container!.publicCloudDatabase
        }
        result(nil)
    }

    private func addRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let dataString = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
            return
        }
        let recordId = CKRecord.ID(recordName: id)
        let newRecord = CKRecord(recordType: type, recordID: recordId)
        if let jsonData = dataString.data(using: .utf8) {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    newRecord.setValuesForKeys(jsonDict)
                }
            } catch {
                result(FlutterError.init(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
                return
            }
        }

        Task {
            do {
                let addedRecord = try await database!.save(newRecord)
                let re = try self.parseRecord(addedRecord)
                result(re)
            } catch {
                result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }
        }
    }

    private func addRecordFile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let fileUrl = args["fileUrl"] as? String,
              let fieldName = args["fieldName"] as? String,
              let metadata = args["metadata"] as? String,
              let bkType = args["bkType"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
            return
        }
        let recordId = CKRecord.ID(recordName: id)
        let newRecord = CKRecord(recordType: type, recordID: recordId)

        let fileURL = URL(fileURLWithPath: fileUrl)
        let asset = CKAsset(fileURL: fileURL)

        newRecord[fieldName] = asset;
        newRecord.setValue(metadata, forKey:"metadata");
        newRecord.setValue(bkType, forKey:"bk_type") 
        Task {
            do {
                let addedRecord = try await database!.save(newRecord)
                result(fileUrl)
            } catch {
                result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }
        }
    }

    private func parseRecord(_ record: CKRecord) throws -> String {
        var dic: [String: Any] = [:]
        record.allKeys().forEach { key in
            dic[key] = record[key]
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
           throw error
        }
    }
    private func getOneRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getOneRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)
        database!.fetch(withRecordID: recordID) { record, error in
            if let newRecord = record, error == nil {
                do {
                    let re = try self.parseRecord(newRecord)
                    result(re)
                }catch {
                    result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
                }
            } else if let error = error {
                result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(FlutterError.init(code: "EDIT_ERROR", message: "Record not found", details: nil))
            }
        }
    }

    private func getOneRecordFile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        
        guard let args = call.arguments as? Dictionary<String, Any>,
            let id = args["id"] as? String

        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getOneRecord Required arguments are not provided", details: nil))
            return
        }
        
        let recordID = CKRecord.ID(recordName: id)
        database!.fetch(withRecordID: recordID) { record, error in
            if let fetchedRecord = record, error == nil {
                if let asset = fetchedRecord["sqlite_file"] as? CKAsset,
                    let assetURL = asset.fileURL {
                    result(assetURL.absoluteString)
                } else {
                    result(FlutterError.init(code: "ASSET_ERROR", message: "Asset not found or invalid", details: nil))
                }
            } else if let error = error {
                result(FlutterError.init(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(FlutterError.init(code: "FETCH_ERROR", message: "Record not found", details: nil))
            }
        }
    }

    private func checkOneRecordAvailable(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        
        guard let args = call.arguments as? Dictionary<String, Any>,
            let id = args["id"] as? String

        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getOneRecord Required arguments are not provided", details: nil))
            return
        }
        
        let recordID = CKRecord.ID(recordName: id)
        database!.fetch(withRecordID: recordID) { record, error in
            if let fetchedRecord = record, error == nil {
                result(id)
            } else if let error = error {
                if error.localizedDescription.contains("Record not found") {
                    result(nil)
                } else {
                    result(FlutterError.init(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
                }
            } else {
                result(nil)
            }
        }
    }

    private func editRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let dataString = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "editRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)

        database!.fetch(withRecordID: recordID) { record, error in
            if let newRecord = record, error == nil {
                if let jsonData = dataString.data(using: .utf8) {
                    do {
                        if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            newRecord.setValuesForKeys(jsonDict)
                        }
                    } catch {
                        result(FlutterError.init(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
                        return
                    }
                }
                // newRecord["data"] = data
                Task {
                    do {
                        let editedRecord = try await self.database!.save(newRecord)
                        let re = try self.parseRecord(editedRecord)
                        result(re)
                    } catch {
                        result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
                        return
                    }
                }
            } else if let error = error {
                result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(FlutterError.init(code: "EDIT_ERROR", message: "Record not found", details: nil))
            }
        }
    }

    private func getAllRecords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        do {
            guard database != nil else {
                result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
                return
            }
            guard let args = call.arguments as? Dictionary<String, Any>,
                let type = args["type"] as? String,
                let queryString = args["query"] as? String,
                let fields = args["fields"] as? [String]
            else {
                result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getAllRecords Required arguments are not provided", details: nil))
                return
            }
            var predicateQuery = NSPredicate(value: true)
            if !queryString.isEmpty {
                predicateQuery = NSPredicate(format: queryString)
            }
            let query = CKQuery(recordType: type, predicate: predicateQuery)
            self._keepLoadRecords(query: query,cursor: nil,result: result, data: [], fields: fields)
        } catch {
            print("err")
            return
            // result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
            // return
        }
    }

    private func getRecordFileInfo(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        do {
            guard let args = call.arguments as? Dictionary<String, Any>,
                let id = args["id"] as? String,
                let fields = args["fields"] as? [String]
            else {
                result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getOneRecord Required arguments are not provided", details: nil))
                return
            }
            
            let recordID = CKRecord.ID(recordName: id)
            database!.fetch(withRecordID: recordID) { record, error in
                if let fetchedRecord = record, error == nil {
                    if let fileName = fetchedRecord.recordID.recordName as? String {
                        var dictionary: [String: String] = ["id": fileName]
                        if let creationDate = fetchedRecord.creationDate {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            let dateString = dateFormatter.string(from: creationDate)
                            dictionary["creationDate"] = dateString
                        }

                        fields.map { field in
                            if let value = fetchedRecord[field] as? String {
                                dictionary[field] = value                            
                            }
                        }
                        result(dictionary)
                    }
                } else if let error = error {
                    result(FlutterError.init(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(FlutterError.init(code: "FETCH_ERROR", message: "Record not found", details: nil))
                }
            }
        } catch {
            print("err")
            return
        }
    }

    private func _keepLoadRecords(query: CKQuery? = nil, cursor: CKQueryOperation.Cursor? = nil,result: @escaping FlutterResult, data: [Any], fields: [String]) {
        var mergedData: [Any] = data
        var operation: CKQueryOperation
        if query != nil {
            operation = CKQueryOperation(query: query!)
        }else {
            operation = CKQueryOperation(cursor: cursor!)
        }

        operation.resultsLimit = 400;
        operation.recordFetchedBlock = { record in
            do {
                if let fileName = record.recordID.recordName as? String {
                    var dictionary: [String: String] = ["id": fileName]
                    if let creationDate = record.creationDate {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let dateString = dateFormatter.string(from: creationDate)
                        dictionary["creationDate"] = dateString
                    }

                    fields.map { field in
                        if let value = record[field] as? String {
                            dictionary[field] = value                            
                        }
                    }
                    mergedData.append(dictionary)
                }
            } catch {
                // result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                // return
            }
        }
        operation.queryCompletionBlock = {(cursor : CKQueryOperation.Cursor?, error : Error?) in
            DispatchQueue.main.async {
                if error == nil {
                    if cursor != nil {
                        self._keepLoadRecords(query: nil, cursor: cursor,result: result,data: mergedData, fields: fields)
                    }else {
                        result(mergedData)
                    }

                } else {
                    result(FlutterError.init(code: "GET_DATA_ERROR", message: error?.localizedDescription, details: nil))
                }
            }
        }
        database?.add(operation)

    }
    private func deleteRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "deleteRecord Required arguments are not provided", details: nil))
            return
        }
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        
        let recordID = CKRecord.ID(recordName: id)
        
        Task {
            do {
                try await database!.deleteRecord(withID: recordID)
                result(nil)
            } catch {
                result(FlutterError.init(code: "DELETE_ERROR", message: "Failed to delete data", details: nil))
            }
        }
    }

    private func deleteManyRecords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let ids = args["ids"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "deleteRecord Required arguments are not provided", details: nil))
            return
        }
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
    
        let stringRecordIDs: [String] = ids.split(separator: ",").map{String($0)};
        var recordIDsToDelete: [CKRecord.ID] = []

        for stringID in stringRecordIDs {
            let recordID = CKRecord.ID(recordName: stringID)
            recordIDsToDelete.append(recordID)
        }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
            operation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
                if let error = error {
                    print("Error deleting records: \(error)")
                } else {
                    print("Records deleted successfully: \(deletedRecordIDs)")
                }
        }
                
        operation.qualityOfService = .userInitiated

        Task {
            do {
                // try await database!.deleteRecord(withID: recordID)
                try await database!.add(operation)

                result(nil)
            } catch {
                result(FlutterError.init(code: "DELETE_ERROR", message: "Failed to delete data", details: nil))
            }
        }
    }
}
