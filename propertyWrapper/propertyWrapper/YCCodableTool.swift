//
//  YCCodableTool.swift
//  propertyWrapper
//
//  Created by 郭朝顺 on 2023/12/31.
//

import Foundation

class YCCodableTool {
    // 字典 -> 模型
    static func coverDictionToModel<T: Decodable>(dic: [String: Any], type: T.Type) -> T?  {

        if let jsonData = try? JSONSerialization.data(withJSONObject: dic, options: []) {

            // 将JSON数据解析为User对象
            let decocer = JSONDecoder()
            decocer.userInfo = [CodingUserInfoKey(rawValue: "classForCoder")!: type]
            let model = try? decocer.decode(type, from: jsonData)
            return model
        } else {
            return nil
        }

    }

    // 模型到字典
    @discardableResult
    static func modelToJsonObject<T: Encodable>(_ model: T) -> [String: AnyObject]? {
        // 字符串
        do {
            let jsonData = try JSONEncoder().encode(model)
            let jsonString = String(decoding: jsonData, as: UTF8.self)
            print("转成字符串: \(jsonString)")

        } catch {
            print(error.localizedDescription)
        }

        var jsonObject: [String: AnyObject]? = nil
        // 字典
        do {
            let jsonData = try JSONEncoder().encode(model)
            jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String : AnyObject]
            print("转成字典: \(jsonObject)")
        } catch {
            print(error.localizedDescription)
        }
        return jsonObject

    }

    // key为类名,value为此类型的默认对象生成的字典
    static var cache: NSCache<NSString, NSDictionary> = {
        let cache = NSCache<NSString, NSDictionary>()
        cache.countLimit = 500
        return cache
    }()


    // class必须满足以下要求
    // 1.为NSObject子类,才能直接使用 init() 方法,
    // 2.实现Encodable协议, 才能把Model转成字典
    static func dictionaryFromClassName(_ className: AnyClass) -> NSDictionary {

        let key = NSStringFromClass(className) as NSString
        if let obj = self.cache.object(forKey: key) {
            return obj
        } else {
            // 使用动态类型转换确保 className 是一个类类型
            if let classType = className as? NSObject.Type {
                // 使用类类型初始化一个对象实例
                let obj = classType.init()
                if let model = obj as? Encodable {
                    let dic = YCCodableTool.modelToJsonObject(model)

                    if let dic {
                        let value = dic as NSDictionary
                        self.cache.setObject(value, forKey: key)
                        return value
                    } else {
                        fatalError("入参类型无法转成NSDictionary")
                    }
                } else {
                    fatalError("入参对象不遵守Encodable协议")
                }
            } else {
                fatalError("入参类型必须为NSObject子类")
            }
        }
    }

    // 服务器没有返回对应的key, 从对象中获取预设的默认值
    static func localModelValue<T>(decoder: Decoder?, type: Default<T>.Type, forKey key: CodingKey) -> Default<T> {

        // 服务器中的也没有值, 尝试从类的默认值中获取
        if let defaultClass = decoder?.userInfo[CodingUserInfoKey(rawValue: "classForCoder")!] as? AnyClass {

            // 整一个协议方法, 根据类型 -> 关联一个字典, 从字典中取对应的key作为默认值
            // 属性的名字
            let propertyKey = key.stringValue
            let moldeDic = YCCodableTool.dictionaryFromClassName(defaultClass)

            if let propertyValue = moldeDic[propertyKey] {
                print("gcs -- 读取属性默认值 \(propertyKey) \(propertyValue)")
                if let result = propertyValue as? Default<T>.Value {
                    let defaultValue = Default<T>.init(wrappedValue: result)
                    print("解析成功,使用本地默认值 \(propertyKey) \(defaultValue)")
                    return defaultValue
                }
            }
        }
        return Default<T>(wrappedValue: T.defaultValue)

    }

}

// 声明协议, 任何实现协议的类提供 defaultValue的get方法即可
protocol DefaultSource {
    associatedtype Value: Decodable
    static var defaultValue: Value { get }
}

// MARK: - 对枚举的扩展
// 声明属性包装器, 实现DecodableDefaultSource可以使用此属性包装器
@propertyWrapper
struct Default<Source: DefaultSource> {
    typealias Value = Source.Value
    var wrappedValue = Source.defaultValue
}

// 对外暴漏的属性包装器类型
extension Default {
    typealias BoolDefault = Default<Bool>
    typealias FalseDefault = Default<Bool.False>
    typealias TrueDefault = Default<Bool.True>

    typealias IntDefault = Default<Int>
    typealias StringDefault = Default<String>
    typealias DoubleDefault = Default<Double>
    typealias FloatDefault = Default<Float>
    typealias CGFloatDefault = Default<CGFloat>
}


// 实现属性包装器的 json -> Model的协议方法
extension Default: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let propertyKey = (container.codingPath.first?.stringValue)!
        print("准备解析 \(propertyKey)")

        // 定义类型和服务器类一致, 直接使用
        if let originValue = try? container.decode(Value.self) {
            self.wrappedValue = originValue
            print("解析成功,类型正确,使用服务器值 \(propertyKey) \(originValue)")
            return
        }

        // 类型不匹配, 尝试从服务器类型中转换
        var defaultValue: Source.Value?
        if Source.Value.self == String.self  {
            if let value  = try? container.decode(Int.self){
                defaultValue = self.coverToSourceValue(String(value))
            } else if let value = try? container.decode(Bool.self){
                defaultValue = self.coverToSourceValue((value == true ? "0" : "1"))
            }else if let value = try? container.decode(Double.self){
                defaultValue = self.coverToSourceValue(String(value))
            }else if let value = try? container.decode(Float.self){
                defaultValue = self.coverToSourceValue(String(value))
            }
        } else if Source.Value.self == Int.self {
            if let value = try? container.decode(Bool.self){
                defaultValue = self.coverToSourceValue((value == true ? 1 : 0))
            }else if let value = try? container.decode(Double.self){
                defaultValue = self.coverToSourceValue(Int(value))
            }else if let value = try? container.decode(Float.self){
                defaultValue = self.coverToSourceValue(Int(value))
            }else if let value = try? container.decode(String.self){
                defaultValue = self.coverToSourceValue(Int(value))
            }
        }
        else if Source.Value.self == Float.self {
            if let value  = try? container.decode(Int.self){
                defaultValue = self.coverToSourceValue(Float(value))
            }else if let value = try? container.decode(Double.self){
                defaultValue = self.coverToSourceValue(Float(value))
            }
            else if let value = try? container.decode(String.self){
                defaultValue = self.coverToSourceValue(Float(value))
            }
        }
        else if Source.Value.self == CGFloat.self {
            if let value  = try? container.decode(Int.self){
                defaultValue = self.coverToSourceValue(CGFloat(value))
            }else if let value = try? container.decode(Double.self){
                defaultValue = self.coverToSourceValue(CGFloat(value))
            }else if let value = try? container.decode(Float.self){
                defaultValue = self.coverToSourceValue(CGFloat(value))
            }
            else if let value = try? container.decode(String.self){

                if let double = Double(value) {
                    defaultValue = self.coverToSourceValue(double)
                }
            }
        }
        else if Source.Value.self == Bool.self {
            if let value  = try? container.decode(Int.self){
                defaultValue = self.coverToSourceValue((value == 0 ? false : true))
            }
            else if let value = try? container.decode(String.self){
                defaultValue = self.coverToSourceValue((value == "0" ? false : true))
            }
        }
        // 从服务器类型中获取到值, 使用服务器的值
        if let defaultValue {
            self.wrappedValue = defaultValue
            print("解析成功,类型错误,对服务器值进行类型转换 \(propertyKey) \(defaultValue)")
            return
        }
        print("所有取值方式都失败, 使用属性包装器的默认值")
        print("解析成功,使用属性包装器默认值兜底 \(propertyKey) \(defaultValue)")
        self.wrappedValue = Source.defaultValue
    }

    private func coverToSourceValue(_ value: Any?) -> Source.Value {
        if let result = value as? Source.Value {
            return result
        } else {
            fatalError("不能进到这里")
        }
    }

}

// 实现Model -> json的协议方法
extension Default: Encodable where Value: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.wrappedValue)
    }
}
// 直接让类型扩展协议,会导致同一种类型只能有一种默认值,
// 比如String的默认值只能是"",不能再扩展其他值,锁死了同类型的扩展方向, 可以在对应类型下在家新的字类型
extension Bool: DefaultSource {

    enum False: DefaultSource {
        static var defaultValue: Bool = false
    }
    enum True: DefaultSource {
        static var defaultValue: Bool = true
    }

    static var defaultValue: Bool = false
}
extension String: DefaultSource {
    static var defaultValue: String = ""
}
extension Int: DefaultSource {
    static var defaultValue = 0
}
extension Float: DefaultSource {
    static var defaultValue:Float = 0.0
}
extension Double: DefaultSource {
    static var defaultValue:Double = 0.0
}
extension CGFloat: DefaultSource {
    static var defaultValue:CGFloat = 0.0
}
typealias DefaultCodable = DefaultSource & Codable

// 支持从josn中值 -> 属性包装器本身
extension KeyedDecodingContainer {
    func decode<T>(_ type: Default<T>.Type,
                   forKey key: Key) throws -> Default<T> {
        print("准备解析",key.stringValue)
        if let result = try self.decodeIfPresent(type, forKey: key) {
            return result
        } else {

            let decoder = try? self.superDecoder()
            let result = YCCodableTool.localModelValue(decoder: decoder, type: type, forKey: key)
            return result
        }
    }
}


// MARK: - 对枚举的扩展 -- end


// 其他组件,继续扩展值
extension Int {

    enum oneInt: DefaultSource {
        static var defaultValue: Int = 1
    }
}

extension Default {
    typealias oneIntDefault = Default<Int.oneInt>
}

