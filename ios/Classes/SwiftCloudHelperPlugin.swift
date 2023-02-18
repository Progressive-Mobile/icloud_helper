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
        case "insertRecords":
            insertRecords(call, result)
        case "editRecord":
            editRecord(call, result)
        case "deleteRecord":
            deleteRecord(call, result)
        case "getAllRecords":
            getAllRecords(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let containerId = args["containerId"] as? String,
              let databaseType = args["databaseType"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
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
              let data = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
            return
        }

        let recordId = CKRecord.ID(recordName: id)
        let newRecord = CKRecord(recordType: type, recordID: recordId)
        newRecord["data"] = data
        Task {
            do {
                let addedRecord = try await database!.save(newRecord)
                result(addedRecord["data"])
            } catch {
                result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }
        }
    }

    private func insertRecords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
//         guard database != nil else {
//             result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
//             return
//         }
//
//         guard let args = call.arguments as? Dictionary<String, Any>,
//               let type = args["type"] as? String,
//               let insertRecordsJson = args["records"] as? String
//         else {
//             result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
//             return
//         }
//         guard let data = insertRecordsJson.data(using: .utf8),
//            let jsonData = try? JSONSerialization.jsonObject(with: data, options: []) as? [Dictionary<String, Any>]
//         else {
//              result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
//              return
//          }
//          let newRecords : Array<CKRecord> = jsonData.map { (rData) -> String in
// //                let newRecord = CKRecord(recordType: type,
// //                     recordID: CKRecord.ID(recordName: (rData["id"] as? String)!)
// //                    )
//                 return rData["data"] as? String
// //                newRecord["data"] = rData["data"] as? String
// //                return newRecord;
//          };
//         result(newRecords[0])

//        Task {
//            do
//            {
//                for chunk in newRecords.chunk(into: 5)
//                {
//                   let (_, _) = try await database!.modifyRecords(saving: chunk, deleting: [])
//                   result(nil)
//                   return
//                }
//
//            }
//            catch
//            {
//                 result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
//                 return
//            }
//        }


    }

    private func editRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let data = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)

        database!.fetch(withRecordID: recordID) { record, error in

            if let newRecord = record, error == nil {

                newRecord["data"] = data

                Task {
                    do {
                        let editedRecord = try await self.database!.save(newRecord)
                        result(editedRecord["data"])
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
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
            return
        }
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: type, predicate: pred)
        self._keepLoadRecords(query: query,cursor: nil,result: result, data: [String]())

    }

    private func _keepLoadRecords(query: CKQuery? = nil, cursor: CKQueryOperation.Cursor? = nil,result: @escaping FlutterResult, data: [String]) {
        var mergedData = data
        var operation: CKQueryOperation
        if query != nil {
            operation = CKQueryOperation(query: query!)
        }else {
            operation = CKQueryOperation(cursor: cursor!)
        }

        operation.resultsLimit = 400;
        operation.recordFetchedBlock = { record in
            if let item: String = record["data"] {
                mergedData.append(item)
            }
        }
        operation.queryCompletionBlock = {(cursor : CKQueryOperation.Cursor?, error : Error?) in
            DispatchQueue.main.async {
                if error == nil {
                    if cursor != nil {
                        self._keepLoadRecords(query: nil, cursor: cursor,result: result,data: mergedData)
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
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
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
}
