# JayJai Pet Desktop

A native macOS desktop pet prototype inspired by JayJai: a black-and-white French bulldog with upright ears, a gray muzzle, and happy/sleepy expressions.

## Run

```sh
swift run JayJaiPetDesktop
```

Run the command from the repo root so the app can find `Assets/Pet/*.png`. The prototype opens a transparent floating pet overlay near the bottom-right of the screen.

## V1 Behavior

- Transparent borderless desktop overlay
- Small rectangular click/drag area around the pet
- Smaller `180x180` pet window
- Random walking bursts every 5-10 seconds
- Pet only moves while the walking frames are active
- Click to trigger the happy tongue-out reaction
- Drag to move the pet
- Slower idle animation
- Slower sleepy state after roughly 30 seconds without interaction
- Menu bar item with Reset Position and Quit
- Right-click pet menu with Reset Position and Quit

## Asset Prep

The first implementation draws a placeholder sticker-style Frenchie in AppKit. When replacing it with final art, prepare transparent PNG frames with the same canvas size:

```text
Assets/Pet/idle_00.png ... idle_07.png
Assets/Pet/happy_00.png ... happy_07.png
Assets/Pet/sleepy_00.png ... sleepy_07.png
Assets/Pet/walk_00.png ... walk_07.png
```

Recommended canvas: `320x320`.
