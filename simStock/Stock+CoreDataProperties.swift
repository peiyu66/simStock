//
//  Stock+CoreDataProperties.swift
//  simStock
//
//  Created by peiyu on 2016/9/8.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Stock {

    @NSManaged var id: String
    @NSManaged var list: String
    @NSManaged var name: String

}
