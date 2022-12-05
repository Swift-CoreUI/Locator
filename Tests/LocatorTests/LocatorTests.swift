import XCTest
@testable import Locator

protocol AProtocol: AnyObject {}
protocol XProtocol: AnyObject {}

final class LocatorTests: XCTestCase {
    // swiftlint:disable:next type_name
    class A: AProtocol {}
    // swiftlint:disable:next type_name
    class B {}
    // swiftlint:disable:next type_name
    class C {
        static var countInits = 0
        var uuid: UUID
        init() {
            Self.countInits += 1
            uuid = UUID()
        }
    }

    func testRegister() {

        let locator = ServiceLocator()
        locator.register { A() }

        XCTAssertNoThrow(try locator.resolve() as A)
        XCTAssertThrowsError(try locator.resolve() as B)
    }

    func testRegisterProtocol() {

        let locator1 = ServiceLocator()
        locator1.register { A() }

        XCTAssertNoThrow(try locator1.resolve() as AProtocol)
        XCTAssertNoThrow(try locator1.resolve() as A)
        XCTAssertThrowsError(try locator1.resolve() as XProtocol)

        let locator2 = ServiceLocator()
        locator2.register { B() as B? } // not very useful way to register: all optional types will resolve oo nil
        XCTAssertThrowsError(try locator2.resolve() as B)
        XCTAssertNoThrow(try locator2.resolve() as B?)
        XCTAssertNil(try! locator2.resolve() as B?) // swiftlint:disable:this force_try

        let locator3 = ServiceLocator()
        locator3.register { B() as B }
        XCTAssertNoThrow(try locator3.resolve() as B?)
        XCTAssertNoThrow(try locator3.resolve() as B)

        let locator4 = ServiceLocator()
        locator4.register { A() as AProtocol }
        XCTAssertNoThrow(try locator4.resolve() as AProtocol?)
        XCTAssertNoThrow(try locator4.resolve() as AProtocol)
    }

    func testSharedScope() {
        // swiftlint:disable:next type_name
        class C {
            static var countInits = 0
            var uuid: UUID
            init() {
                Self.countInits += 1
                uuid = UUID()
            }
        }

        let locator = ServiceLocator()
        locator.register(.shared) { C() }

        // both instances should be the same
        let c1 = try! locator.resolve() as C // swiftlint:disable:this force_try
        let c2 = try! locator.resolve() as C // swiftlint:disable:this force_try

        XCTAssertEqual(c1.uuid, c2.uuid)
        XCTAssertEqual(C.countInits, 1)
        XCTAssert(c1 === c2)
    }

    func testUniqueScope() {

        let locator = ServiceLocator()
        locator.register(.unique) { C() }

        // different instance
        let c1 = try! locator.resolve() as C // swiftlint:disable:this force_try
        let c2 = try! locator.resolve() as C // swiftlint:disable:this force_try

        XCTAssertNotEqual(c1.uuid, c2.uuid)
        XCTAssertEqual(C.countInits, 2)
        XCTAssert(c1 !== c2)
    }

    func testUnload() {
        let locator = ServiceLocator()
        locator.register { A() }

        let svc1 = try? locator.resolve() as AProtocol
        XCTAssertNotNil(svc1)

        let svc2 = try? locator.resolve() as AProtocol
        XCTAssertTrue(svc1 === svc2)

        locator.unload(AProtocol.self)

        let svc3 = try? locator.resolve() as AProtocol

        XCTAssertNotNil(svc3)
        XCTAssert(svc1 !== svc3)
    }

    func testUnregister() {
        let locator = ServiceLocator()
        locator.register { A() }

        let svc1 = try? locator.resolve() as AProtocol
        XCTAssertNotNil(svc1)

        locator.unregister(AProtocol.self)

        let svc2 = try? locator.resolve() as AProtocol
        XCTAssertNil(svc2)
    }
}
