//
//  ModelDef.swift
//  propertyWrapper
//
//  Created by 郭朝顺 on 2023/12/31.
//

import Foundation


class BaseModel: NSObject, Codable {

}


class House: NSObject, Codable {
    @Default.StringDefault var name: String
    @Default.IntDefault var height: Int = 180
    var houseMaster: Person = Person()
    var housePerson: [Person]?
}


class Person: NSObject, Codable // 可正常解析
//class Person: Codable // 可正常解析
//class Person: BaseModel // 继承BaseModel 后会解析失败, 这是为啥
{
    @Default.StringDefault var name: String = ""

    // 此处声明的默认值不生效
    @Default.IntDefault var age: Int = 0

    // 此处声明的默认值不生效
    @Default.BoolDefault var isMan: Bool = false

    @Default<Bool.False> var isVip: Bool = false
    @Default<Bool.True> var isNoble: Bool  = false
    @Default.oneIntDefault var height: Int = 188
}
