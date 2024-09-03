import Foundation

public class ConcurrentDictionary<V: Hashable, T>: Collection {
  private var inner: [V : T]
  private var lock: NSLock = .init()

  public var keys: Dictionary<V, T>.Keys {
    self.locked {
      inner.keys
    }
  }

  public var values: Dictionary<V, T>.Values {
      self.locked {
        self.inner.values
      }
  }

  public var startIndex: Dictionary<V, T>.Index {
      self.locked {
          self.inner.startIndex
      }
  }

  public var endIndex: Dictionary<V, T>.Index {
      self.locked {
          self.inner.endIndex
      }
  }

  public init(inner: [V:T]) {
    self.inner = inner
  }

  public convenience init() {
    self.init(inner: [:])
  }

  public func index(after i: Dictionary<V, T>.Index) -> Dictionary<V, T>.Index {
    self.locked {
      self.inner.index(after: i)
    }
  }

  public subscript(key: V) -> T? {
      set(newValue) {
          self.locked {
            self.inner[key] = newValue
          }
      }

      get {
        self.locked {
          self.inner[key]
        }
      }
  }

  public subscript(index: Dictionary<V, T>.Index) -> Dictionary<V, T>.Element {
      self.locked {
        self.inner[index]
      }
  }

  public func take() -> Dictionary<V, T> {
    self.locked {
      let current = self.inner
      self.inner = [:]
      return current
    }
  }

  fileprivate func locked<X>(_ perform: () -> X) -> X {
    self.lock.lock()
    defer {
      self.lock.unlock()
    }
    let value = perform()
    return value
  }
}
