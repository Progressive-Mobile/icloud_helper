import Cocoa
import FlutterMacOS
import CloudKit

@available(macOS 10.15, *)
public class CloudHelperPlugin: NSObject, FlutterPlugin {
  private var container: CKContainer?
  
  private var database:  CKDatabase?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cloud_helper", binaryMessenger: registrar.messenger)
    let instance = CloudHelperPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call, result)
        case "addRecord":
            addRecord(call, result)
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
              let containerId = args["containerId"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "Required arguments are not provided", details: nil))
            return
        }
        container = CKContainer(identifier: containerId)
        database = container!.privateCloudDatabase
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
        
        let operation = CKQueryOperation(query: query)
        
        var data = [String]()
        
        operation.recordFetchedBlock = { record in
            if let item: String = record["data"] {
                data.append(item)
            }
        }
        operation.queryCompletionBlock = {(cursor, error) in
            DispatchQueue.main.async {
                if error == nil {
                    result(data)
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
