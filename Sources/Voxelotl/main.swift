import Foundation
import SDL3

guard SDL_Init(SDL_INIT_VIDEO) >= 0 else {
  print("SDL init failed.")
  exit(1)
}

defer {
  SDL_Quit()
}

print("SDL init success.")
