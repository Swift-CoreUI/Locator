# Locator

Simple and minimalistic Dependency Injection library for swift projects.

## Example

```swift

// MyAPI.swift

protocol MyAPI: AnyObject {
    func run(task: MyTask) -> Result<Bool, Never>
}

class MyAPIImpl: MyAPI {
    func run(task: MyTask) -> Result<Bool, Never> {
        // ... run task and gather result (probably async)
        return result
    }
}

// MyService.swift

import Locator

protocol MyService: AnyObject {
    func runTask1() -> Bool 
}

class MyServiceImpl: MyService {
    @Inject private var myAPI: MyAPI
    
    func runTask1() -> Bool {
        let result = myAPI.run(MyTask(id: 1))
        
        switch result {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}


// AppDelegate.swift

import Locator

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // ...

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? ) -> Bool {
    
        // ...
        
        ServiceLocator.registerServices()
    
        return true
    }
}

fileprivate extension ServiceLocator {
    func registerServices()
        register { MyAPIImpl() }
        register { MyServiceImpl() }
    }
}

// MyViewModel.swift

import Combine
import Locator

struct MyViewModel {
    @Inject private var myService: MyService
    
    enum ViewState {
        case .loading
        case .success
        case .error
    }
    
    let viewState = CurrentValueSubject<ViewState, Never>(.loading)
    
    func runTask1AndGetAResultAfterUsersAction() {
        let isOK = myService.runTask1()
        
        viewState.value = isOK ? .success : .error
    }
    
}

// MyServiceMock.swift

class MyServiceMock: MyService {
    func runTask1() -> Bool {
        true
    }
}

// MyViewModelTest.swift

import XCTest
import Locator

final class MyViewModelTests: XCTestCase {
    override func setUp() {
        register { MyServiceMock() }
    }
    
    func testViewModel1() {
        let viewModel = MyViewModel()
        
        XCTAssertEqual(viewModel.viewState.value, .loading)
        
        viewModel.runTask1AndGetAResultAfterUsersAction()
        
        XCTAssertEqual(viewModel.viewState.value, .success)
    }
}


```
