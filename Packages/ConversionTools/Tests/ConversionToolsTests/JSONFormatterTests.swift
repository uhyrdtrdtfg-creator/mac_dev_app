import Testing
import Foundation
@testable import ConversionTools

@Test func jsonFormat2Spaces() {
    let input = #"{"name":"Alice","age":30}"#
    let result = JSONFormatter.format(input, indent: .spaces2)
    let expected = """
    {
      "age" : 30,
      "name" : "Alice"
    }
    """
    #expect(result.output == expected)
    #expect(result.error == nil)
}

@Test func jsonFormat4Spaces() {
    let input = #"{"a":1}"#
    let result = JSONFormatter.format(input, indent: .spaces4)
    let expected = """
    {
        "a" : 1
    }
    """
    #expect(result.output == expected)
    #expect(result.error == nil)
}

@Test func jsonMinify() {
    let input = """
    {
      "name" : "Alice",
      "age" : 30
    }
    """
    let result = JSONFormatter.minify(input)
    #expect(result.output != nil)
    #expect(result.error == nil)
}

@Test func jsonValidateValid() {
    let result = JSONFormatter.validate(#"{"valid": true}"#)
    #expect(result.isValid == true)
    #expect(result.error == nil)
}

@Test func jsonValidateInvalid() {
    let result = JSONFormatter.validate(#"{"invalid": }"#)
    #expect(result.isValid == false)
    #expect(result.error != nil)
}

@Test func jsonFormatInvalid() {
    let result = JSONFormatter.format("not json at all", indent: .spaces2)
    #expect(result.output == nil)
    #expect(result.error != nil)
}
