extension SIMD3 where Scalar: FloatingPoint {
  @inline(__always) static var X: Self      { Self(1, 0, 0) }
  @inline(__always) static var Y: Self      { Self(0, 1, 0) }
  @inline(__always) static var Z: Self      { Self(0, 0, 1) }

  @inline(__always) static var up: Self      {  Y }
  @inline(__always) static var down: Self    { -Y }
  @inline(__always) static var left: Self    { -X }
  @inline(__always) static var right: Self   {  X }
  @inline(__always) static var forward: Self { -Z }
  @inline(__always) static var back: Self    {  Z }
}
