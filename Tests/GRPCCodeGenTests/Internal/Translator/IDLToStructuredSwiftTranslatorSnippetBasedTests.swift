/*
 * Copyright 2024, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if os(macOS) || os(Linux)  // swift-format doesn't like canImport(Foundation.Process)

import XCTest

@testable import GRPCCodeGen

final class IDLToStructuredSwiftTranslatorSnippetBasedTests: XCTestCase {
  typealias MethodDescriptor = GRPCCodeGen.CodeGenerationRequest.ServiceDescriptor.MethodDescriptor
  typealias ServiceDescriptor = GRPCCodeGen.CodeGenerationRequest.ServiceDescriptor
  typealias Name = GRPCCodeGen.CodeGenerationRequest.Name

  func testImports() throws {
    var dependencies = [CodeGenerationRequest.Dependency]()
    dependencies.append(CodeGenerationRequest.Dependency(module: "Foo"))
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .typealias, name: "Bar"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .struct, name: "Baz"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .class, name: "Bac"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .enum, name: "Bap"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .protocol, name: "Bat"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .let, name: "Baq"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .var, name: "Bag"), module: "Foo")
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(item: .init(kind: .func, name: "Bak"), module: "Foo")
    )

    let expectedSwift =
      """
      /// Some really exciting license header 2023.
      import GRPCCore
      import Foo
      import typealias Foo.Bar
      import struct Foo.Baz
      import class Foo.Bac
      import enum Foo.Bap
      import protocol Foo.Bat
      import let Foo.Baq
      import var Foo.Bag
      import func Foo.Bak
      """
    try self.assertIDLToStructuredSwiftTranslation(
      codeGenerationRequest: makeCodeGenerationRequest(dependencies: dependencies),
      expectedSwift: expectedSwift,
      accessLevel: .public
    )
  }

  func testPreconcurrencyImports() throws {
    var dependencies = [CodeGenerationRequest.Dependency]()
    dependencies.append(CodeGenerationRequest.Dependency(module: "Foo", preconcurrency: .required))
    dependencies.append(
      CodeGenerationRequest.Dependency(
        item: .init(kind: .enum, name: "Bar"),
        module: "Foo",
        preconcurrency: .required
      )
    )
    dependencies.append(
      CodeGenerationRequest.Dependency(
        module: "Baz",
        preconcurrency: .requiredOnOS(["Deq", "Der"])
      )
    )
    let expectedSwift =
      """
      /// Some really exciting license header 2023.
      import GRPCCore
      @preconcurrency import Foo
      @preconcurrency import enum Foo.Bar
      #if os(Deq) || os(Der)
      @preconcurrency import Baz
      #else
      import Baz
      #endif
      """
    try self.assertIDLToStructuredSwiftTranslation(
      codeGenerationRequest: makeCodeGenerationRequest(dependencies: dependencies),
      expectedSwift: expectedSwift,
      accessLevel: .public
    )
  }

  func testSPIImports() throws {
    var dependencies = [CodeGenerationRequest.Dependency]()
    dependencies.append(CodeGenerationRequest.Dependency(module: "Foo", spi: "Secret"))
    dependencies.append(
      CodeGenerationRequest.Dependency(
        item: .init(kind: .enum, name: "Bar"),
        module: "Foo",
        spi: "Secret"
      )
    )

    let expectedSwift =
      """
      /// Some really exciting license header 2023.
      import GRPCCore
      @_spi(Secret) import Foo
      @_spi(Secret) import enum Foo.Bar
      """
    try self.assertIDLToStructuredSwiftTranslation(
      codeGenerationRequest: makeCodeGenerationRequest(dependencies: dependencies),
      expectedSwift: expectedSwift,
      accessLevel: .public
    )
  }

  private func assertIDLToStructuredSwiftTranslation(
    codeGenerationRequest: CodeGenerationRequest,
    expectedSwift: String,
    accessLevel: SourceGenerator.Configuration.AccessLevel
  ) throws {
    let translator = IDLToStructuredSwiftTranslator()
    let structuredSwift = try translator.translate(
      codeGenerationRequest: codeGenerationRequest,
      accessLevel: accessLevel,
      client: false,
      server: false
    )
    let renderer = TextBasedRenderer.default
    let sourceFile = try renderer.render(structured: structuredSwift)
    let contents = sourceFile.contents
    try XCTAssertEqualWithDiff(contents, expectedSwift)
  }

  func testSameNameServicesNoNamespaceError() throws {
    let serviceA = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(base: "", generatedUpperCase: "", generatedLowerCase: ""),
      methods: []
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [serviceA, serviceA])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueServiceName,
          message: """
            Services must have unique descriptors. \
            AService is the descriptor of at least two different services.
            """
        )
      )
    }
  }

  func testSameDescriptorsServicesNoNamespaceError() throws {
    let serviceA = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(base: "", generatedUpperCase: "", generatedLowerCase: ""),
      methods: []
    )

    let serviceB = ServiceDescriptor(
      documentation: "Documentation for BService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(base: "", generatedUpperCase: "", generatedLowerCase: ""),
      methods: []
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [serviceA, serviceB])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueServiceName,
          message: """
            Services must have unique descriptors. AService is the descriptor of at least two different services.
            """
        )
      )
    }
  }
  func testSameDescriptorsSameNamespaceError() throws {
    let serviceA = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(
        base: "namespacea",
        generatedUpperCase: "NamespaceA",
        generatedLowerCase: "namespacea"
      ),
      methods: []
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [serviceA, serviceA])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueServiceName,
          message: """
            Services must have unique descriptors. \
            namespacea.AService is the descriptor of at least two different services.
            """
        )
      )
    }
  }

  func testSameGeneratedNameServicesSameNamespaceError() throws {
    let serviceA = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(
        base: "namespacea",
        generatedUpperCase: "NamespaceA",
        generatedLowerCase: "namespacea"
      ),
      methods: []
    )
    let serviceB = ServiceDescriptor(
      documentation: "Documentation for BService",
      name: Name(base: "BService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(
        base: "namespacea",
        generatedUpperCase: "NamespaceA",
        generatedLowerCase: "namespacea"
      ),
      methods: []
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [serviceA, serviceB])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .internal,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueServiceName,
          message: """
            Services within the same namespace must have unique generated upper case names. \
            AService is used as a generated upper case name for multiple services in the namespacea namespace.
            """
        )
      )
    }
  }

  func testSameBaseNameMethodsSameServiceError() throws {
    let methodA = MethodDescriptor(
      documentation: "Documentation for MethodA",
      name: Name(base: "MethodA", generatedUpperCase: "MethodA", generatedLowerCase: "methodA"),
      isInputStreaming: false,
      isOutputStreaming: false,
      inputType: "NamespaceA_ServiceARequest",
      outputType: "NamespaceA_ServiceAResponse"
    )
    let service = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(
        base: "namespacea",
        generatedUpperCase: "NamespaceA",
        generatedLowerCase: "namespacea"
      ),
      methods: [methodA, methodA]
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [service])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueMethodName,
          message: """
            Methods of a service must have unique base names. \
            MethodA is used as a base name for multiple methods of the AService service.
            """
        )
      )
    }
  }

  func testSameGeneratedUpperCaseNameMethodsSameServiceError() throws {
    let methodA = MethodDescriptor(
      documentation: "Documentation for MethodA",
      name: Name(base: "MethodA", generatedUpperCase: "MethodA", generatedLowerCase: "methodA"),
      isInputStreaming: false,
      isOutputStreaming: false,
      inputType: "NamespaceA_ServiceARequest",
      outputType: "NamespaceA_ServiceAResponse"
    )
    let methodB = MethodDescriptor(
      documentation: "Documentation for MethodA",
      name: Name(base: "MethodB", generatedUpperCase: "MethodA", generatedLowerCase: "methodA"),
      isInputStreaming: false,
      isOutputStreaming: false,
      inputType: "NamespaceA_ServiceARequest",
      outputType: "NamespaceA_ServiceAResponse"
    )
    let service = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(
        base: "namespacea",
        generatedUpperCase: "NamespaceA",
        generatedLowerCase: "namespacea"
      ),
      methods: [methodA, methodB]
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [service])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueMethodName,
          message: """
            Methods of a service must have unique generated upper case names. \
            MethodA is used as a generated upper case name for multiple methods of the AService service.
            """
        )
      )
    }
  }

  func testSameLowerCaseNameMethodsSameServiceError() throws {
    let methodA = MethodDescriptor(
      documentation: "Documentation for MethodA",
      name: Name(base: "MethodA", generatedUpperCase: "MethodA", generatedLowerCase: "methodA"),
      isInputStreaming: false,
      isOutputStreaming: false,
      inputType: "NamespaceA_ServiceARequest",
      outputType: "NamespaceA_ServiceAResponse"
    )
    let methodB = MethodDescriptor(
      documentation: "Documentation for MethodA",
      name: Name(base: "MethodB", generatedUpperCase: "MethodB", generatedLowerCase: "methodA"),
      isInputStreaming: false,
      isOutputStreaming: false,
      inputType: "NamespaceA_ServiceARequest",
      outputType: "NamespaceA_ServiceAResponse"
    )
    let service = ServiceDescriptor(
      documentation: "Documentation for AService",
      name: Name(base: "AService", generatedUpperCase: "AService", generatedLowerCase: "aService"),
      namespace: Name(
        base: "namespacea",
        generatedUpperCase: "NamespaceA",
        generatedLowerCase: "namespacea"
      ),
      methods: [methodA, methodB]
    )

    let codeGenerationRequest = makeCodeGenerationRequest(services: [service])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueMethodName,
          message: """
            Methods of a service must have unique lower case names. \
            methodA is used as a signature name for multiple methods of the AService service.
            """
        )
      )
    }
  }

  func testSameGeneratedNameNoNamespaceServiceAndNamespaceError() throws {
    let serviceA = ServiceDescriptor(
      documentation: "Documentation for SameName service with no namespace",
      name: Name(base: "SameName", generatedUpperCase: "SameName", generatedLowerCase: "sameName"),
      namespace: Name(base: "", generatedUpperCase: "", generatedLowerCase: ""),
      methods: []
    )
    let serviceB = ServiceDescriptor(
      documentation: "Documentation for BService",
      name: Name(base: "BService", generatedUpperCase: "BService", generatedLowerCase: "bService"),
      namespace: Name(
        base: "sameName",
        generatedUpperCase: "SameName",
        generatedLowerCase: "sameName"
      ),
      methods: []
    )
    let codeGenerationRequest = makeCodeGenerationRequest(services: [serviceA, serviceB])
    let translator = IDLToStructuredSwiftTranslator()
    XCTAssertThrowsError(
      ofType: CodeGenError.self,
      try translator.translate(
        codeGenerationRequest: codeGenerationRequest,
        accessLevel: .public,
        client: true,
        server: true
      )
    ) {
      error in
      XCTAssertEqual(
        error as CodeGenError,
        CodeGenError(
          code: .nonUniqueServiceName,
          message: """
            Services with no namespace must not have the same generated upper case names as the namespaces. \
            SameName is used as a generated upper case name for a service with no namespace and a namespace.
            """
        )
      )
    }
  }
}

#endif  // os(macOS) || os(Linux)
