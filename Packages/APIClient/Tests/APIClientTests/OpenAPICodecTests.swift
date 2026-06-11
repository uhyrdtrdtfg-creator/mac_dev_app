import Testing
import Foundation
@testable import APIClient

private let petstoreDoc = #"""
{
  "openapi": "3.0.3",
  "info": { "title": "Petstore", "version": "1.0.0" },
  "servers": [{ "url": "https://api.example.com/v1" }],
  "paths": {
    "/pets": {
      "get": {
        "operationId": "listPets",
        "tags": ["pets"],
        "parameters": [
          { "name": "limit", "in": "query", "schema": { "type": "integer", "default": 20 } },
          { "name": "status", "in": "query", "example": "available", "schema": { "type": "string" } },
          { "name": "X-Request-Id", "in": "header", "schema": { "type": "string" } }
        ]
      },
      "post": {
        "operationId": "createPet",
        "tags": ["pets"],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/Pet" }
            }
          }
        }
      }
    },
    "/pets/{petId}": {
      "delete": {
        "summary": "Delete a pet"
      }
    }
  },
  "components": {
    "schemas": {
      "Pet": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "age": { "type": "integer" },
          "vaccinated": { "type": "boolean" },
          "nicknames": { "type": "array", "items": { "type": "string" } },
          "owner": { "$ref": "#/components/schemas/Owner" }
        }
      },
      "Owner": {
        "type": "object",
        "properties": {
          "email": { "type": "string", "example": "jane@example.com" },
          "friend": { "$ref": "#/components/schemas/Owner" }
        }
      }
    }
  }
}
"""#

@Test func openAPIImportRequestCountAndMethods() {
    let requests = OpenAPICodec.importDocument(petstoreDoc)
    #expect(requests.count == 3)
    #expect(requests.map(\.method).sorted() == ["DELETE", "GET", "POST"])
}

@Test func openAPIImportNamesAndURLs() {
    let requests = OpenAPICodec.importDocument(petstoreDoc)

    let list = requests.first { $0.name == "listPets" }
    #expect(list != nil)
    #expect(list?.method == "GET")
    #expect(list?.url == "https://api.example.com/v1/pets?limit=20&status=available")
    #expect(list?.headers.contains { $0.key == "X-Request-Id" && $0.value.isEmpty } == true)
    #expect(list?.tagList == ["Petstore/pets"])

    let delete = requests.first { $0.method == "DELETE" }
    #expect(delete?.name == "Delete a pet")
    #expect(delete?.url == "https://api.example.com/v1/pets/{{petId}}")
    #expect(delete?.tagList == ["Petstore"])
}

@Test func openAPIImportBodySkeletonFromRefSchema() throws {
    let requests = OpenAPICodec.importDocument(petstoreDoc)
    let create = try #require(requests.first { $0.name == "createPet" })
    #expect(create.bodyType == "json")

    guard case .json(let raw) = try #require(create.body) else {
        Issue.record("expected json body")
        return
    }
    let obj = try #require(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    #expect(obj["name"] as? String == "")
    #expect(obj["age"] as? Int == 0)
    #expect(obj["vaccinated"] as? Bool == false)
    #expect(obj["nicknames"] as? [String] == [""])
    let owner = try #require(obj["owner"] as? [String: Any])
    #expect(owner["email"] as? String == "jane@example.com")
    // Circular Owner.friend ref must terminate at the depth limit, not crash.
    #expect(owner["friend"] != nil)
}

@Test func openAPIOperationWithoutBodyHasNoBody() {
    let requests = OpenAPICodec.importDocument(petstoreDoc)
    let list = requests.first { $0.name == "listPets" }
    #expect(list?.body == nil)
    #expect(list?.bodyType == nil)
}

@Test func openAPIDetection() {
    #expect(OpenAPICodec.isOpenAPIDocument(petstoreDoc))
    #expect(OpenAPICodec.isOpenAPIDocument(#"{"swagger": "2.0", "paths": {}}"#))

    let postmanDoc = #"""
    {
      "info": { "name": "My Collection", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
      "item": [{ "name": "Get", "request": { "method": "GET", "url": "https://example.com" } }]
    }
    """#
    #expect(!OpenAPICodec.isOpenAPIDocument(postmanDoc))
    #expect(OpenAPICodec.importDocument(postmanDoc).isEmpty)
    #expect(!OpenAPICodec.isOpenAPIDocument("not json"))
}

@Test func openAPISwagger2BaseURLAndBodyParam() throws {
    let doc = #"""
    {
      "swagger": "2.0",
      "info": { "title": "Legacy", "version": "1.0" },
      "host": "legacy.example.com",
      "basePath": "/api",
      "schemes": ["http"],
      "paths": {
        "/users": {
          "post": {
            "operationId": "createUser",
            "parameters": [
              { "name": "body", "in": "body", "schema": { "type": "object", "properties": { "id": { "type": "integer" } } } }
            ]
          }
        }
      }
    }
    """#
    let requests = OpenAPICodec.importDocument(doc)
    let create = try #require(requests.first)
    #expect(create.url == "http://legacy.example.com/api/users")
    guard case .json(let raw) = try #require(create.body) else {
        Issue.record("expected json body")
        return
    }
    let obj = try #require(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    #expect(obj["id"] as? Int == 0)
}
