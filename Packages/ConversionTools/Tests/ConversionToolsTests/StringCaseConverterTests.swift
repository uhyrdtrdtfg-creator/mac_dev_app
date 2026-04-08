import Testing
@testable import ConversionTools

@Test func toCamelCase() { #expect(StringCaseConverter.convert("hello_world", to: .camelCase) == "helloWorld") }
@Test func toPascalCase() { #expect(StringCaseConverter.convert("hello_world", to: .pascalCase) == "HelloWorld") }
@Test func toSnakeCase() { #expect(StringCaseConverter.convert("helloWorld", to: .snakeCase) == "hello_world") }
@Test func toKebabCase() { #expect(StringCaseConverter.convert("helloWorld", to: .kebabCase) == "hello-world") }
@Test func toUpperCase() { #expect(StringCaseConverter.convert("hello_world", to: .upperCase) == "HELLO WORLD") }
@Test func fromPascalCase() { #expect(StringCaseConverter.convert("HelloWorld", to: .snakeCase) == "hello_world") }
@Test func fromKebabCase() { #expect(StringCaseConverter.convert("hello-world", to: .pascalCase) == "HelloWorld") }
