import Testing
import Foundation
@testable import APIClient

// MARK: - Envelope building

@Test func graphqlEnvelopeWithVariables() throws {
    let data = try GraphQLEnvelope.build(query: "query { hero { name } }", variables: #"{"id": 42, "name": "R2"}"#)
    let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(obj["query"] as? String == "query { hero { name } }")
    let vars = try #require(obj["variables"] as? [String: Any])
    #expect(vars["id"] as? Int == 42)
    #expect(vars["name"] as? String == "R2")
}

@Test func graphqlEnvelopeOmitsEmptyVariables() throws {
    for empty in ["", "   ", "\n\t "] {
        let data = try GraphQLEnvelope.build(query: "{ ping }", variables: empty)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["variables"] == nil)
        #expect(obj["query"] as? String == "{ ping }")
    }
}

@Test func graphqlEnvelopeInvalidVariablesThrows() {
    #expect(throws: GraphQLEnvelopeError.self) {
        try GraphQLEnvelope.build(query: "{ a }", variables: "{not json")
    }
    // Valid JSON but not an object
    #expect(throws: GraphQLEnvelopeError.variablesNotAnObject) {
        try GraphQLEnvelope.build(query: "{ a }", variables: "[1, 2]")
    }
    #expect(throws: GraphQLEnvelopeError.variablesNotAnObject) {
        try GraphQLEnvelope.build(query: "{ a }", variables: "42")
    }
}

@Test func graphqlEnvelopeBytesDeterministic() throws {
    let variables = #"{"b": 1, "a": {"d": "x", "c": true}}"#
    let first = try GraphQLEnvelope.build(query: "query Q { f }", variables: variables)
    let second = try GraphQLEnvelope.build(query: "query Q { f }", variables: variables)
    #expect(first == second)
    #expect(String(decoding: first, as: UTF8.self) == #"{"query":"query Q { f }","variables":{"a":{"c":true,"d":"x"},"b":1}}"#)
}

@Test func graphqlEnvelopeUnicode() throws {
    let data = try GraphQLEnvelope.build(query: "query { 用户 { 名字 } }", variables: #"{"emoji": "✓中文"}"#)
    let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(obj["query"] as? String == "query { 用户 { 名字 } }")
    #expect((obj["variables"] as? [String: Any])?["emoji"] as? String == "✓中文")
}

@Test func graphqlEnvelopeDecompose() throws {
    let data = try GraphQLEnvelope.build(query: "query { a }", variables: #"{"x": 1}"#)
    let (query, variables) = try #require(GraphQLEnvelope.decompose(data))
    #expect(query == "query { a }")
    #expect(variables == #"{"x":1}"#)

    let bare = try GraphQLEnvelope.build(query: "{ b }", variables: "")
    let (q2, v2) = try #require(GraphQLEnvelope.decompose(bare))
    #expect(q2 == "{ b }")
    #expect(v2.isEmpty)
}

@Test func graphqlVariablesValidationHint() {
    #expect(GraphQLEnvelope.variablesValidationError("") == nil)
    #expect(GraphQLEnvelope.variablesValidationError("  \n") == nil)
    #expect(GraphQLEnvelope.variablesValidationError(#"{"a": 1}"#) == nil)
    #expect(GraphQLEnvelope.variablesValidationError("{oops") != nil)
    #expect(GraphQLEnvelope.variablesValidationError("[1]") != nil)
}

// MARK: - buildURLRequest

@Test func buildURLRequestGraphQL() throws {
    let body = RequestBody.graphql(query: "query { hero }", variables: #"{"id": "中✓"}"#)
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://x.dev/graphql", headers: [], queryParams: [], body: body, auth: nil)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let expected = try GraphQLEnvelope.build(query: "query { hero }", variables: #"{"id": "中✓"}"#)
    #expect(request.httpBody == expected)
}

@Test func buildURLRequestGraphQLUserContentTypeWins() throws {
    let body = RequestBody.graphql(query: "{ a }", variables: "")
    let headers = [KeyValuePair(key: "Content-Type", value: "application/graphql-response+json")]
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://x.dev/graphql", headers: headers, queryParams: [], body: body, auth: nil)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/graphql-response+json")
}

@Test func buildURLRequestGraphQLInvalidVariablesThrows() {
    let body = RequestBody.graphql(query: "{ a }", variables: "{broken")
    #expect(throws: HTTPClientError.self) {
        try HTTPClientService.buildURLRequest(method: .post, url: "https://x.dev/graphql", headers: [], queryParams: [], body: body, auth: nil)
    }
}

// MARK: - Codable

@Test func requestBodyGraphQLCodableRoundtrip() throws {
    let body = RequestBody.graphql(query: "query { a }", variables: #"{"x": 1}"#)
    let data = try JSONEncoder().encode(body)
    let decoded = try JSONDecoder().decode(RequestBody.self, from: data)
    if case .graphql(let query, let variables) = decoded {
        #expect(query == "query { a }")
        #expect(variables == #"{"x": 1}"#)
    } else { Issue.record("Expected .graphql case") }
}

@Test func requestBodyOldPersistedJSONCaseStillDecodes() throws {
    // Raw JSON exactly as the synthesized Codable encoded the .json case before .graphql existed.
    let raw = #"{"json":{"_0":"{\"key\": \"value\"}"}}"#
    let decoded = try JSONDecoder().decode(RequestBody.self, from: Data(raw.utf8))
    if case .json(let str) = decoded { #expect(str == #"{"key": "value"}"#) }
    else { Issue.record("Expected .json case") }
}

// MARK: - Code generation

@Test func codeGenGraphQLAllLanguages() {
    let request = CodeGenRequest(
        method: .post, url: "https://x.dev/graphql",
        body: .graphql(query: "query { hero { name } }", variables: #"{"id": 7}"#)
    )
    for lang in CodeGenLanguage.allCases {
        let code = RequestCodeGenerator.generate(lang, request: request)
        #expect(code.contains("hero { name }"), "\(lang.rawValue) must embed the query")
        #expect(code.contains("variables"), "\(lang.rawValue) must embed the variables")
        #expect(code.contains("application/json"), "\(lang.rawValue) must set Content-Type")
    }
}

@Test func codeGenGraphQLInvalidVariablesFallsBackToComment() {
    let request = CodeGenRequest(
        method: .post, url: "https://x.dev/graphql",
        body: .graphql(query: "query { a }", variables: "{broken")
    )
    for lang in CodeGenLanguage.allCases {
        let code = RequestCodeGenerator.generate(lang, request: request)
        #expect(code.contains("GraphQL body omitted"), "\(lang.rawValue) must emit a placeholder comment")
    }
}

@Test func codeGenGraphQLUserContentTypeNotDuplicated() {
    let request = CodeGenRequest(
        method: .post, url: "https://x.dev/graphql",
        headers: [KeyValuePair(key: "content-type", value: "application/graphql-response+json")],
        body: .graphql(query: "{ a }", variables: "")
    )
    let code = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(code.contains("application/graphql-response+json"))
    #expect(!code.contains("\"application/json\""))
}

// MARK: - Postman import/export

@Test func postmanExportGraphQLBody() throws {
    let saved = SavedRequestModel(name: "GQL", method: "POST", url: "https://x.dev/graphql")
    saved.body = .graphql(query: "query { a }", variables: #"{"x": 1}"#)
    saved.bodyType = "GraphQL"
    let json = ImportExportService.exportAsPostmanCollection([saved])
    let obj = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    let item = try #require((obj["item"] as? [[String: Any]])?.first)
    let request = try #require(item["request"] as? [String: Any])
    let body = try #require(request["body"] as? [String: Any])
    #expect(body["mode"] as? String == "graphql")
    let gql = try #require(body["graphql"] as? [String: Any])
    #expect(gql["query"] as? String == "query { a }")
    #expect(gql["variables"] as? String == #"{"x": 1}"#)
}

@Test func postmanImportGraphQLBody() throws {
    let json = """
    {
      "info": {"name": "C", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"},
      "item": [{
        "name": "GQL",
        "request": {
          "method": "POST",
          "url": {"raw": "https://x.dev/graphql"},
          "body": {"mode": "graphql", "graphql": {"query": "query { hero }", "variables": "{\\"ep\\": 5}"}}
        }
      }]
    }
    """
    let imported = ImportExportService.importPostmanCollection(json)
    let saved = try #require(imported.first)
    #expect(saved.bodyType == "GraphQL")
    if case .graphql(let query, let variables) = saved.body {
        #expect(query == "query { hero }")
        #expect(variables == #"{"ep": 5}"#)
    } else { Issue.record("Expected .graphql body") }
}

// MARK: - Introspection parsing

private let cannedSchemaJSON = """
{"data": {"__schema": {"types": [
  {"kind": "OBJECT", "name": "Query", "fields": [
    {"name": "user",
     "args": [{"name": "id", "type": {"kind": "NON_NULL", "name": null, "ofType": {"kind": "SCALAR", "name": "ID"}}}],
     "type": {"kind": "OBJECT", "name": "User"}},
    {"name": "users", "args": [],
     "type": {"kind": "NON_NULL", "name": null, "ofType": {"kind": "LIST", "name": null, "ofType": {"kind": "NON_NULL", "name": null, "ofType": {"kind": "OBJECT", "name": "User"}}}}}
  ]},
  {"kind": "OBJECT", "name": "User", "fields": [
    {"name": "id", "args": [], "type": {"kind": "SCALAR", "name": "ID"}}
  ]},
  {"kind": "SCALAR", "name": "String", "fields": null},
  {"kind": "OBJECT", "name": "__Type", "fields": []}
]}}}
"""

@Test func introspectionSummaryParsing() throws {
    let summary = try GraphQLIntrospection.summarizeSchema(Data(cannedSchemaJSON.utf8))
    #expect(summary.contains("Query OBJECT"))
    #expect(summary.contains("  user(id: ID!): User"))
    #expect(summary.contains("  users: [User!]!"))
    #expect(summary.contains("User OBJECT"))
    #expect(summary.contains("String SCALAR"))
    #expect(!summary.contains("__Type"))
}

@Test func introspectionSummaryGraphQLErrors() {
    let json = #"{"errors": [{"message": "introspection disabled"}]}"#
    #expect(throws: GraphQLIntrospectionError.self) {
        try GraphQLIntrospection.summarizeSchema(Data(json.utf8))
    }
}

@Test func introspectionSummaryMalformed() {
    #expect(throws: GraphQLIntrospectionError.self) {
        try GraphQLIntrospection.summarizeSchema(Data("not json".utf8))
    }
    #expect(throws: GraphQLIntrospectionError.self) {
        try GraphQLIntrospection.summarizeSchema(Data(#"{"data": {}}"#.utf8))
    }
}
