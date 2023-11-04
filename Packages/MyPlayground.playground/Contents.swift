import UIKit


// 2
DispatchQueue.main.async {
    print("1")

    DispatchQueue.main.sync {
        print("2")
    }

    print("3")
}

print("4")
