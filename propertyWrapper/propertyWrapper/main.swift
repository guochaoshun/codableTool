//
//  main.swift
//  propertyWrapper
//
//  Created by 郭朝顺 on 2023/12/17.
//

import Foundation


var hourseDic: [String: Any] = [:]
hourseDic["name"] = "102公寓"

var personDic: [String: Any] = [:]
personDic["name"] = "周杰伦"
personDic["age"] = "12"



//hourseDic["houseMaster"] = personDic

var array: [[String:Any]] = []
for i in 0..<10 {

    var personDic: [String: Any] = [:]
    personDic["name"] = "周杰K\(i)"
    personDic["age"] = "\(12*i)"
    array.append(personDic)
}
hourseDic["housePerson"] = array

let test = TestCase()
test.test1()

class TestCase {

    func test1() {

        var serverDic: [String: Any] = [:]
        serverDic["name"] = "周杰伦"
        serverDic["age"] = "12"
        serverDic["isMan"] = true
        serverDic["isVip"] = true
        serverDic["isNoble"] = false
//        serverDic["height"] = "170"

        let person = YCCodableTool.coverDictionToModel(dic: serverDic, type: Person.self)
        print(person)
        let modelDic = YCCodableTool.modelToJsonObject(person)
        



    }


    // 简单模型, 服务器确实某些字段, 能使用默认值

    func test2() {

        let jsonData = try! JSONSerialization.data(withJSONObject: hourseDic, options: [])
        // 将JSON数据解析为User对象
        let decocer = JSONDecoder()
        decocer.userInfo = [CodingUserInfoKey(rawValue: "classForCoder")!: House.classForCoder()]
        let house = try? decocer.decode(House.self, from: jsonData)
        print(house?.name)
        print(house?.houseMaster)

        print(house)

    }

}





// 问题: 
//  类型嵌套的时候, 某个属性不想用可选, 应该怎么做
//  类继承的时候, 属性还能解码成功吗?
//
