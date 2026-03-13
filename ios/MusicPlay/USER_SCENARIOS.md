# User Behavior Scenarios: MusicPlay iOS

This document outlines the various paths and interactions a user can take within the MusicPlay iOS application. It serves as a base for testing and UX refinement.

## 1. Discovery & Initial Playback
*   **Search and Play**: User opens the app -> Goes to Search -> Types a query -> Taps a result -> Track starts playing and mini-player appears.
*   **Search and Add to Queue**: User searches for a track -> Long presses/opens menu -> Selects "Add to Queue" -> Continues searching without interrupting current playback.
*   **Direct Play from Search**: User taps the "Play" icon on a search result -> Queue is replaced with this single track (or search results) -> Full player opens.

## 2. Full Player Interactions
*   **Opening Full Player**: User taps the mini-player -> Player slides up.
*   **Scrubbing**: User drags the progress slider -> Playback jumps to the new position.
*   **Volume Adjustment**: User adjusts the volume slider within the app -> System volume changes.
*   **Toggling Favorites**: User taps the Heart icon -> Track is added to Favorites store (heart turns red, haptic feedback).
*   **Menu Actions**: User taps "..." -> Selects "Play Next" -> Track is inserted after current track in queue.
*   **Changing Repeat Mode**: User cycles through: Off -> One (track loops) -> All (entire queue loops).
*   **Shuffle Toggle**: User turns on Shuffle -> Current track stays, remaining queue is randomized.
*   **AirPlay Selection**: User taps AirPlay icon -> System route picker opens -> User selects Bluetooth speaker -> Audio output switches.
*   **Queue Panel**: User taps Queue icon -> Bottom sheet with current queue opens -> User drags a track to reorder -> User swipes to remove a track.

## 3. Playlist & History Management
*   **Creating Playlist**: User goes to Playlists tab -> Taps "New Playlist" -> Enters name -> Playlist appears in list.
*   **Adding to Playlist**: User is in Full Player -> Opens Menu -> "Add to Playlist" -> Selects "Late Night Vibes" -> Confirmation message.
*   **Reviewing History**: User goes to Playlists -> Taps "Recently Played" -> Sees tracks played in the last session -> Taps a track to replay it.
*   **Clearing History**: User goes to History view -> Taps "Clear" button -> List is emptied.

## 4. Audio Engine & Transitions (Crossfade)
*   **Natural Transition (Auto-Next)**: Track A is ending -> 6 seconds remaining -> Track B starts loading silently -> Both play together (fade A out, fade B in) -> Track B becomes primary.
*   **Manual Skip (Forward)**: User taps Next -> Ongoing crossfade (if any) is canceled -> Track C starts immediately with its own fade-in or standard start.
*   **Repeat-One Conflict**: User enables Repeat One -> Track ends -> App ignores crossfade logic and simply seeks back to 0:00.
*   **Rapid Skipping**: User taps "Next" 5 times quickly -> App cancels each transition -> Final track starts playing robustly without audio glitches or "ghost" players.

## 5. Visual Customization
*   **Vinyl Mode**: User goes to Settings -> Changes Cover Style to "Vinyl" -> Opens Player -> Sees the record animation rotating during playback.
*   **Square Covers**: User enables "Force Square Covers" -> Search results and mini-player show cropped square images instead of wide thumbnails.
*   **Dynamic Background**: User plays a track -> Background of the player subtly shifts colors based on the track's thumbnail.

## 6. System & Connectivity
*   **Lock Screen Control**: User locks phone -> Sees Track/Artist/Cover -> Taps Pause -> Playback stops.
*   **Cable Disconnect**: User is listening on headphones -> Unplugs them -> App receives route change notification -> Playback pauses automatically.
*   **Incoming Call**: User is listening -> Phone rings -> App receives interruption notification -> Playback pauses -> Call ends -> User resume playback.
*   **Network Error / Server Down**: App loses connection to local server -> User taps play -> App shows "Connection Error" in settings or toast.
*   **Server Check**: User in Settings -> Taps "Check Server Connection" -> Sees green "Connected" status and latency info.

## 7. Performance & State Persistence
*   **App Backgrounding**: User minimizes app -> Audio continues playing (background mode).
*   **Cold Start Recovery**: User closes app completely -> Reopens later -> App restores the last played track and position.
*   **Cache Management**: User listens to many songs -> App automatically manages the 500MB cache, evicting oldest tracks to make room for new ones.
