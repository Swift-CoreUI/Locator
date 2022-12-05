import Foundation

@inline(__always) public func register<Service>(_ scope: ServiceLocator.Scope = .shared, _ factory: @escaping () -> Service) {
    ServiceLocator.main.register(scope, factory)
}

@inline(__always) public func resolve<Service>() throws -> Service {
    return try ServiceLocator.main.resolve()
}

@inline(__always) public func resolveOrDie<Service>() -> Service {
    do {
        return try ServiceLocator.main.resolve()
    } catch {
        fatalError("ServiceLocator could not locate \(Service.self)")
    }
}

///
/// Thread-safe service locator.
/// Uses DispatchQueue to syncronize unsafe operations.
///
public class ServiceLocator {
    static let main = ServiceLocator()

    private let queue = DispatchQueue(label: "ServiceLocator.queue", qos: .utility)
    private var sharedServices: [Any] = []
    private var sharedFactories: [(type: Any.Type, factory: () -> Any)] = []
    private var uniqFactories: [(type: Any.Type, factory: () -> Any)] = []

    public enum ResolverError: Error {
        case serviceWasNotFound(Any.Type)
    }

    public enum Scope {
        case shared
        case unique
        case sharedNonLazy
    }

    public init() {}

    // mutating
    public func register<Service>(_ scope: Scope = .shared, _ factory: @escaping () -> Service) {
        queue.sync {
            // TODO: in future we can replace existing (re-register service), it could be useful for tests
            // But what if old service was already injected somewhere and we will replace it with new one?

            switch scope {
            case .sharedNonLazy:
                guard sharedServices.first(where: { $0 is Service }) == nil else { return }
                let service = factory()
                sharedServices.append(service)
            case .shared:
                guard sharedFactories.first(where: {
                    $0.type is Service.Type || // case when Service is an instance
                    $0.type is Service // case when Service is a protocol (AnyObject)
                }) == nil else { return }
                sharedFactories.append((type: Service.self, factory))
            case .unique:
                guard uniqFactories.first(where: {
                    $0.type is Service.Type || // case when Service is an instance
                    $0.type is Service // case when Service is a protocol (AnyObject)
                }) == nil else { return }
                uniqFactories.append((type: Service.self, factory))
            }
        }
    }

    // has some internal mutations (mutates dicts)
    public func resolve<Service>() throws -> Service {

        // .shared services
        if let service = sharedServices.first(where: { $0 is Service }) as? Service {
            return service
        }

        var factory: (() -> Any)?
        queue.sync {
            if let index = sharedFactories.firstIndex(where: { $0.type is Service.Type || $0.type is Service }) {
                //(_, factory) = sharedFactories.remove(at: index)
                // do not cleaning up factory callback after service is created: service could be `unload`ed and then resolved again as new instance
                (_, factory) = sharedFactories[index]
            }
        }
        if let service = factory?() as? Service {
            queue.sync {
                sharedServices.append(service)
            }
            return service
        }

        // .unique services
        if let service = uniqFactories.first(where: { $0.type is Service.Type || $0.type is Service })?.factory() as? Service {
            return service
        }

        throw ResolverError.serviceWasNotFound(Service.self)
    }

    // mutating
    public func unregister<Service>(_ type: Service.Type) {
        queue.sync {
            sharedServices = sharedServices.filter { !($0 is Service) }
            sharedFactories = sharedFactories.filter { !($0.type is Service.Type || $0.type is Service) }
            uniqFactories = uniqFactories.filter { !($0.type is Service.Type || $0.type is Service) }
        }
    }

    public func unload<Service>(_ type: Service.Type) {
        queue.sync {
            sharedServices = sharedServices.filter { !($0 is Service) }
        }
    }

    public static func register<Service>(_ scope: Scope = .shared, _ factory: @escaping () -> Service) {
        main.register(scope, factory)
    }

    public static func resolve<Service>() throws -> Service {
        try main.resolve()
    }

    public static func unregister<Service>(_ type: Service.Type) {
        main.unregister(type)
    }

    public static func unload<Service>(_ type: Service.Type) {
        main.unload(type)
    }
}

//public typealias Inject = InjectDirect

@propertyWrapper
public struct Inject<Service> {
    private let service: Service

    public init(locator: ServiceLocator? = nil) {
        do {
            service = try (locator ?? .main).resolve() as Service
        } catch {
            fatalError("@Inject: ServiceLocator could not locate \(Service.self)")
        }
    }

    public var wrappedValue: Service { service }

    public var projectedValue: Inject<Service> {
        get { return self }
        set { self = newValue }
    }
}

@propertyWrapper
public struct InjectLazy<Service> {
    private let locator: ServiceLocator
    private lazy var service: Service = {
        do {
            return try locator.resolve() as Service
        } catch {
            fatalError("@InjectLazy: ServiceLocator could not locate \(Service.self)")
        }
    }()

    public init(locator: ServiceLocator? = nil) {
        self.locator = locator ?? .main
    }

    public var wrappedValue: Service {
        mutating get { service }
    }

    public var projectedValue: InjectLazy<Service> {
        get { return self }
        set { self = newValue }
    }
}

@propertyWrapper
public struct InjectWeak<Service: AnyObject> {
    private weak var service: Service?

    public init(locator: ServiceLocator? = nil) {
        do {
            service = try (locator ?? .main).resolve() as Service
        } catch {
            fatalError("@InjectWeak: ServiceLocator could not locate \(Service.self)")
        }
    }

    public var wrappedValue: Service? {
        get { service }
        set { service = newValue }
    }

    public var projectedValue: InjectWeak<Service> {
        get { return self }
        set { self = newValue }
    }
}

@propertyWrapper
public struct InjectUnowned<Service: AnyObject> {
    private unowned let service: Service

    public init(locator: ServiceLocator? = nil) {
        do {
            service = try (locator ?? .main).resolve() as Service
        } catch {
            fatalError("@InjectUnowned: ServiceLocator could not locate \(Service.self)")
        }
    }

    public var wrappedValue: Service { service }

    public var projectedValue: InjectUnowned<Service> {
        get { return self }
        set { self = newValue }
    }
}
