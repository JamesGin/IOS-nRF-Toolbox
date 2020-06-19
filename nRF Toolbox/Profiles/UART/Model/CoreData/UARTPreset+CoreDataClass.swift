//
//  UARTPreset+CoreDataClass.swift
//  
//
//  Created by Nick Kibish on 03.06.2020.
//
//

import Foundation
import CoreData

@objc(UARTPreset)
class UARTPreset: NSManagedObject {
    
    var isEmpty: Bool {
        self.commands.reduce(true) { $0 && ($1 is EmptyModel) }
    }
    
    var commands: [UARTCommandModel] {
        get {
            commandSet.compactMap { $0 as? UARTCommandModel }
        }
        set {
            commandSet = newValue.compactMap { $0 as? NSObject }
        }
    }
    
    subscript(index: Int) -> UARTCommandModel {
        get {
            commandSet[index] as! UARTCommandModel
        }
        set(newValue) {
            commandSet[index] = newValue as! NSObject
        }
    }
    
    init(commands: [UARTCommandModel], name: String, context: NSManagedObjectContext? = CoreDataStack.uart.viewContext) {
        if let entity = context.flatMap({ Self.getEntity(context: $0) }) {
            super.init(entity: entity, insertInto: context)
        } else {
            super.init()
        }
        self.commands = commands
        self.name = name
    }
    
    private func updateCommands(commands: [UARTCommandModel]) {
        self.commandSet.removeAll()
        self.commandSet += commands.compactMap { $0 as? NSObject }
    }
    
    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
    }
    
    public override func willSave() {
        super.willSave()
    }
    
    func updateCommand(_ command: UARTCommandModel, at index: Int) {
        commandSet[index] = command as! NSObject
    }
}

extension UARTPreset {
    static var empty: UARTPreset {
        UARTPreset(commands: Array(repeating: EmptyModel(), count: 9), name: "")
    }
}
