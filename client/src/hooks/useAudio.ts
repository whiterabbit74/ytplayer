import { useEffect, useRef, useState, useCallback } from "react";
import { getStreamUrl } from "@/lib/api";

interface UseAudioReturn {
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  load: (videoId: string, expectedDuration?: number) => void;
  play: (videoId: string, expectedDuration?: number) => void;
  pause: () => void;
  resume: () => void;
  seek: (time: number) => void;
  setVolume: (vol: number) => void;
  restorePosition: (time: number) => void;
}

// Single Audio element created once, outside React lifecycle
let globalAudio: HTMLAudioElement | null = null;
function getAudio(): HTMLAudioElement {
  if (!globalAudio) globalAudio = new Audio();
  return globalAudio;
}

function loadSavedVolume(): number {
  const saved = localStorage.getItem("musicplay-volume");
  return saved ? parseFloat(saved) : 1;
}

export function useAudio(onEnded?: () => void, repeatOne?: boolean): UseAudioReturn {
  const onEndedRef = useRef(onEnded);
  onEndedRef.current = onEnded;
  const repeatOneRef = useRef(repeatOne);
  repeatOneRef.current = repeatOne;

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolumeState] = useState(loadSavedVolume);
  const [seekingTime, setSeekingTime] = useState<number | null>(null);
  const lastSaveRef = useRef(0);
  const pendingRestoreRef = useRef<number | null>(null);
  const expectedDurationRef = useRef<number>(0);

  useEffect(() => {
    const audio = getAudio();
    audio.volume = volume;

    let lastUpdate = 0;
    const onTimeUpdate = () => {
      const now = Date.now();
      
      // Throttle UI update to ~500ms
      if (now - lastUpdate > 500) {
        setCurrentTime(audio.currentTime);
        lastUpdate = now;
      }

      // Keep persistence logic (2s threshold)
      if (now - lastSaveRef.current > 2000) {
        localStorage.setItem("musicplay-position", String(audio.currentTime));
        lastSaveRef.current = now;
      }
    };
    const onLoadedMetadata = () => {
      const playerDur = audio.duration;
      if (playerDur > 0 && isFinite(playerDur)) {
        const expected = expectedDurationRef.current;
        if (expected > 0 && Math.abs(playerDur - expected) > expected * 0.1) {
          console.warn(`Suspect player duration: ${playerDur}s. Sticking to API: ${expected}s.`);
          setDuration(expected);
        } else {
          setDuration(playerDur);
        }
      }

      if (pendingRestoreRef.current !== null) {
        audio.currentTime = pendingRestoreRef.current;
        setCurrentTime(pendingRestoreRef.current);
        pendingRestoreRef.current = null;
      }
    };
    const onEndedHandler = () => {
      if (repeatOneRef.current) {
        audio.currentTime = 0;
        audio.play().catch((err) => {
          if (err.name !== "AbortError") console.error("Repeat failed:", err);
        });
        return;
      }
      setIsPlaying(false);
      onEndedRef.current?.();
    };
    const onError = () => {
      console.error("Audio error:", audio.error?.message);
      setIsPlaying(false);
      
      // Не пропускаем автоматически. Пользователь просил пытаться до последнего.
      // Если надо, он пропустит сам.
      console.log("Попытка повторного воспроизведения через 3 секунды...");
      setTimeout(() => {
        const currentSrc = audio.src;
        if (currentSrc) {
          // Перезагружаем источник и пробуем играть снова
          audio.load();
          audio.play().catch((err) => {
            if (err.name !== "AbortError") console.error("Retry failed:", err);
          });
          setIsPlaying(true);
        }
      }, 3000);
    };
    const onSeeked = () => setSeekingTime(null);

    audio.addEventListener("timeupdate", onTimeUpdate);
    audio.addEventListener("loadedmetadata", onLoadedMetadata);
    audio.addEventListener("ended", onEndedHandler);
    audio.addEventListener("error", onError);
    audio.addEventListener("seeked", onSeeked);

    return () => {
      audio.removeEventListener("timeupdate", onTimeUpdate);
      audio.removeEventListener("loadedmetadata", onLoadedMetadata);
      audio.removeEventListener("ended", onEndedHandler);
      audio.removeEventListener("error", onError);
      audio.removeEventListener("seeked", onSeeked);
    };
  }, []);

  const load = useCallback((videoId: string, expectedDuration?: number) => {
    const audio = getAudio();
    expectedDurationRef.current = expectedDuration ?? 0;
    audio.src = getStreamUrl(videoId);
  }, []);
  
  const play = useCallback((videoId: string, expectedDuration?: number) => {
    const audio = getAudio();
    expectedDurationRef.current = expectedDuration ?? 0;
    audio.src = getStreamUrl(videoId);
    audio.play().catch((err) => {
      // Ignore AbortError from rapid play/pause
      if (err.name !== "AbortError") console.error("Play failed:", err);
    });
    setIsPlaying(true);
  }, []);

  const pause = useCallback(() => {
    getAudio().pause();
    setIsPlaying(false);
  }, []);

  const resume = useCallback(() => {
    getAudio().play().catch((err) => {
      if (err.name !== "AbortError") console.error("Resume failed:", err);
    });
    setIsPlaying(true);
  }, []);

  const seek = useCallback((time: number) => {
    setSeekingTime(time);
    getAudio().currentTime = time;
  }, []);

  const setVolume = useCallback((vol: number) => {
    getAudio().volume = vol;
    setVolumeState(vol);
    localStorage.setItem("musicplay-volume", String(vol));
  }, []);

  const restorePosition = useCallback((time: number) => {
    const audio = getAudio();
    if (audio.readyState >= 1) {
      audio.currentTime = time;
    } else {
      pendingRestoreRef.current = time;
    }
  }, []);

  return {
    isPlaying,
    currentTime: seekingTime ?? currentTime,
    duration,
    volume,
    load,
    play,
    pause,
    resume,
    seek,
    setVolume,
    restorePosition,
  };
}
